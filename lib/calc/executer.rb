require_relative "executer/formatter"
require_relative "executer/special_forms"
require_relative "executer/loader"
require_relative "executer/completion"

module Calc
  # A struct representing the result of a lambda expression evaluation.
  # @attr params [Array<String>] An array of symbol names for the parameters.
  # @attr body [Calc::Node] The AST node representing the body of the lambda.
  # @attr environment [Environment] The environment (closure) in which the lambda was defined.
  # @attr namespace [String] The namespace in which the lambda was defined.
  LambdaValue = Struct.new(:params, :body, :environment, :namespace, :code_body) do
    # Debug method to visually represent the object.
    def pretty_print(q)
      q.text(Calc::ASTPrinter.pretty([LambdaNode.new(params, body)]).strip)
    end
  end

  # The main engine for evaluating Calc language ASTs.
  # Manages the environment, built-in functions, and namespace registry,
  # and provides evaluation logic for various node types.
  # Delegates responsibilities to Formatter, SpecialForms, Loader, and Completion modules.
  class Executer
    include Formatter
    include SpecialForms
    include Loader
    include Completion

    attr_reader :builtins

    # A list of keywords for special forms.
    SPECIAL_FORMS = %w[define if and or cond namespace lambda do load].freeze

    # Initializes a new instance of Executer.
    #
    # @param environment [Environment] The evaluation environment.
    # @param builtins [Builtins] Built-in functions and literals.
    # @param namespaces [NamespaceRegistry] The namespace registry.
    # @param current_namespace [String, nil] The current namespace.
    # @param execution_mode [String] Evaluation mode (`tree` or `vm`).
    def initialize(environment = Environment.new, builtins = Builtins.new, namespaces = NamespaceRegistry.new,
                   current_namespace: nil, execution_mode: ENV.fetch("CALC_EXECUTER_MODE", "tree"))
      @environment = environment
      @builtins = builtins
      @namespaces = namespaces
      @parser = Parser.new
      @compiler = Compiler.new(@builtins)
      @vm = Vm.new(executer: self, builtins: @builtins)
      @current_namespace = current_namespace
      @namespace_stack = [current_namespace]
      @current_file = nil
      @loaded_files = {}
      @loading_stack = []
      @execution_mode = execution_mode
    end

    # Evaluates a single AST node.
    # Calls the appropriate evaluation logic based on the node type.
    #
    # @param node [Calc::Node] The AST node to evaluate.
    # @return [Object] The result of the evaluation.
    # @raise [Calc::RuntimeError] If an unknown node type is passed.
    def evaluate(node)
      if vm_enabled? && vm_eligible_node?(node)
        begin
          return @vm.run(@compiler.compile(node))
        rescue Calc::NameError => e
          raise e unless node.is_a?(ListNode)

          raise Calc::NameError, "#{e.message} while evaluating #{Calc::ASTPrinter.pretty([node]).strip}"
        end
      end

      evaluate_tree(node)
    end

    # Tree-walk fallback evaluator.
    def evaluate_tree(node)
      case node
      when NumberNode, StringNode
        node.value
      when KeywordNode
        ":#{node.name}"
      when SymbolNode
        resolve_symbol(node)
      when ListNode
        evaluate_list(node)
      when LambdaNode
        LambdaValue.new(node.params, node.body, @environment.snapshot, @current_namespace, nil)
      else
        raise Calc::RuntimeError, "unknown node: #{node.class}"
      end
    end

    # Parses a source code string and evaluates the generated list of AST nodes.
    #
    # @param source [String] The source code to evaluate.
    # @param source_path [String, nil] The file path of the source code (for error reporting).
    # @return [Object, nil] The result of the last expression evaluated.
    def evaluate_source(source, source_path: nil)
      nodes = @parser.parse(source)
      evaluate_nodes(nodes, source_path: source_path)
    end

    # Evaluates a list of AST nodes sequentially.
    # Attaches context information in case of an error.
    #
    # @param nodes [Array<Calc::Node>] The list of AST nodes to evaluate.
    # @param source_path [String, nil] The file path of the source code (for error reporting).
    # @return [Object, nil] The result of the last expression evaluated.
    def evaluate_nodes(nodes, source_path: nil)
      with_source_path(source_path) do
        if vm_enabled? && source_path.nil? && vm_eligible_nodes?(nodes)
          return @vm.run(@compiler.compile_program(nodes, name: source_path || "<input>"))
        end

        nodes.reduce(nil) do |_memo, node|
          evaluate(node)
        rescue StandardError => e
          raise contextualize_error(e, node) if source_path

          raise
        end
      end
    end

    private

    # Resolves a symbol node and retrieves its value.
    # Searches in local variables, built-ins, environment variables, and namespaced
    # variables/functions in order.
    #
    # @param node [SymbolNode] The symbol node to resolve.
    # @return [Object] The value corresponding to the symbol.
    def resolve_symbol(node)
      resolve_symbol_name(node.name)
    end

    # Resolves a symbol name and retrieves its value.
    # Searches in locals, built-in literals, environment, and namespace entries.
    #
    # @param name [String] The symbol name to resolve.
    # @return [Object] The resolved value.
    def resolve_symbol_name(name)
      return @environment.get_local(name) if @environment.bound_local?(name)

      found, builtin = @builtins.resolve(name)
      return builtin if found

      return @environment.get(name) if @environment.bound?(name)

      resolved_variable = @namespaces.resolve_variable(@current_namespace, name)
      return resolved_variable[:value] if resolved_variable

      resolved_function = @namespaces.resolve_function(@current_namespace, name)
      return resolved_function[:value] if resolved_function

      @environment.get(name)
    end

    # Evaluates a list node.
    # If the head is a special form, its handler is called; otherwise, it's treated as a function call.
    #
    # @param node [ListNode] The list node to evaluate.
    # @return [Object] The result of the evaluation.
    # @raise [Calc::SyntaxError] If the expression format is invalid.
    def evaluate_list(node)
      head = node.children.first
      case head
      when SymbolNode
        case head.name
        when "define"
          handle_define(node.children)
        when "if"
          evaluate_if(node.children)
        when "and"
          evaluate_and(node.children)
        when "or"
          evaluate_or(node.children)
        when "cond"
          evaluate_cond(node.children)
        when "namespace"
          evaluate_namespace(node.children)
        when "lambda"
          evaluate_lambda(node.children)
        when "do"
          evaluate_do(node.children)
        when "load"
          evaluate_load(node.children)
        else
          call_function(head.name, node.children.drop(1), node)
        end
      else
        callable = evaluate(head)
        args = node.children.drop(1).map { |child| evaluate(child) }

        return call_lambda(callable, args) if callable.is_a?(LambdaValue)

        raise Calc::SyntaxError, "invalid expression"
      end
    end

    # Calls a function. Resolves and executes built-in functions, lambdas bound
    # in the environment, and user-defined functions in namespaces.
    #
    # @param name [String] The name of the function to call.
    # @param args [Array<Calc::Node>] An array of AST nodes representing the function arguments.
    # @param node [Calc::Node, nil] The AST node of the function call (for error reporting).
    # @return [Object] The result of the function call.
    # @raise [Calc::NameError] If the function is not found.
    # @raise [Calc::SyntaxError] If the expression format is invalid.
    def call_function(name, args, node = nil)
      values = args.map { |arg| evaluate(arg) }
      callable_runner = proc { |callable, call_values| call_value_callable(callable, call_values) }

      return @builtins.call(name, values, &callable_runner) if @builtins.registered?(name)

      if @environment.bound?(name)
        value = @environment.get(name)

        return call_lambda(value, values) if value.is_a?(LambdaValue)

        raise Calc::SyntaxError, "invalid expression"
      end

      resolved_function = @namespaces.resolve_function(@current_namespace, name)
      return call_user_function(resolved_function[:value], values) if resolved_function

      @builtins.call(name, values, &callable_runner)
    rescue Calc::NameError => e
      raise e unless node

      raise Calc::NameError, "#{e.message} while evaluating #{Calc::ASTPrinter.pretty([node]).strip}"
    end

    # Calls a lambda (`LambdaValue`).
    # Constructs a new environment, binds arguments, and evaluates the lambda body.
    #
    # @param callable [LambdaValue] The lambda value to call.
    # @param values [Array<Object>] An array of argument values to pass to the lambda.
    # @return [Object] The result of evaluating the lambda body.
    # @raise [Calc::RuntimeError] If the number of arguments is incorrect.
    def call_lambda(callable, values)
      previous_environment = @environment
      previous_namespace = @current_namespace
      pushed_namespace = false

      params = callable.params
      raise Calc::RuntimeError, "wrong number of arguments" unless params.length == values.length

      @environment = Environment.new(callable.environment)
      params.zip(values).each { |param, value| @environment.set(param, value) }
      @current_namespace = callable.namespace
      @namespace_stack << @current_namespace
      pushed_namespace = true

      callable.code_body ? @vm.run(callable.code_body) : evaluate(callable.body)
    ensure
      @namespace_stack.pop if pushed_namespace
      @environment = previous_environment
      @current_namespace = previous_namespace
    end

    # Confirms that `callable` is a `LambdaValue` and calls `call_lambda`.
    #
    # @param callable [Object] The callable object.
    # @param values [Array<Object>] An array of argument values to pass to the callable.
    # @return [Object] The result of the call.
    # @raise [Calc::NameError] If `callable` is not a `LambdaValue`.
    def call_value_callable(callable, values)
      raise Calc::NameError, "expected a function" unless callable.is_a?(LambdaValue)

      call_lambda(callable, values)
    end

    # Calls a user-defined function (registered in a namespace).
    #
    # @param function_entry [Hash] The function entry from the namespace registry (`{value: LambdaValue}`).
    # @param values [Array<Object>] An array of argument values to pass to the function.
    # @return [Object] The result of the function call.
    def call_user_function(function_entry, values)
      call_lambda(function_entry, values)
    end

    # Constructs a `LambdaValue` object from parameter nodes and a body node.
    #
    # @param param_nodes [Array<SymbolNode>] An array of symbol nodes representing the parameters.
    # @param body_node [Calc::Node] The AST node representing the lambda body.
    # @return [LambdaValue] The constructed lambda value.
    # @raise [Calc::SyntaxError] If a parameter is not a symbol node.
    def build_lambda_value(param_nodes, body_node)
      params = param_nodes.map do |param|
        raise Calc::SyntaxError, "invalid function parameter" unless param.is_a?(SymbolNode)

        param.name
      end

      build_runtime_lambda(params, body_node: body_node)
    end

    def build_runtime_lambda(params, body_node:, code_body: nil)
      LambdaValue.new(params, body_node, @environment.snapshot, @current_namespace, code_body)
    end

    def define_runtime_variable(name, value)
      raise Calc::NameError, "cannot redefine reserved literal: #{name}" if @builtins.reserved?(name)
      raise Calc::NameError, "cannot modify reserved namespace: builtin" if @current_namespace == "builtin"

      @environment.set(name, value) if @current_namespace.nil?
      @namespaces.define_variable(@current_namespace, name, value, local: name.start_with?("_"))
      value
    end

    def define_runtime_function(name, lambda_value)
      raise Calc::NameError, "cannot redefine reserved literal: #{name}" if @builtins.reserved?(name)
      raise Calc::NameError, "cannot modify reserved namespace: builtin" if @current_namespace == "builtin"

      @namespaces.define_function(@current_namespace, name, lambda_value, local: name.start_with?("_"))
      function_label = [@current_namespace, name].compact.join(".")
      "defined function #{function_label}(#{lambda_value.params.join(', ')})"
    end

    def resolve_callable_name(name)
      return [:builtin, name] if @builtins.registered?(name)

      if @environment.bound?(name)
        value = @environment.get(name)
        raise Calc::SyntaxError, "invalid expression" unless value.is_a?(LambdaValue)

        return value
      end

      resolved_function = @namespaces.resolve_function(@current_namespace, name)
      return resolved_function[:value] if resolved_function

      raise Calc::NameError, "unknown function: #{name}"
    end

    def enter_runtime_namespace(name)
      next_namespace = namespace_path(name)
      previous_namespace = @current_namespace
      @current_namespace = next_namespace
      @namespace_stack << next_namespace
      @namespaces.ensure_namespace(@current_namespace)
      previous_namespace
    end

    def leave_runtime_namespace(previous_namespace)
      @namespace_stack.pop
      @current_namespace = previous_namespace
    end

    def load_runtime_file(path, namespace: nil)
      resolved_path = resolve_load_path(path)
      return nil if @loaded_files[resolved_path]

      raise Calc::RuntimeError, "cyclic load detected: #{resolved_path}" if @loading_stack.include?(resolved_path)

      source = File.read(resolved_path)
      @loading_stack << resolved_path

      result = if namespace
                 with_namespace(namespace_path(namespace)) { evaluate_source(source, source_path: resolved_path) }
               else
                 evaluate_source(source, source_path: resolved_path)
               end

      @loaded_files[resolved_path] = true
      result
    ensure
      @loading_stack.pop if defined?(resolved_path) && @loading_stack.last == resolved_path
    end

    def vm_enabled?
      @execution_mode == "vm"
    end

    def vm_eligible_nodes?(nodes)
      nodes.all? { |node| vm_eligible_node?(node) }
    end

    def vm_eligible_node?(node)
      case node
      when NumberNode, StringNode, KeywordNode, SymbolNode, LambdaNode, ListNode
        true
      else
        false
      end
    end
  end
end
