require_relative "executer/formatter"
require_relative "executer/special_forms"
require_relative "executer/loader"
require_relative "executer/completion"

module Calc
  LambdaValue = Struct.new(:params, :body, :environment, :namespace) do
    def pretty_print(q)
      q.text(Calc::ASTPrinter.pretty([LambdaNode.new(params, body)]).strip)
    end
  end

  class Executer
    include Formatter
    include SpecialForms
    include Loader
    include Completion

    SPECIAL_FORMS = %w[define if namespace lambda do load].freeze

    def initialize(environment = Environment.new, builtins = Builtins.new, namespaces = NamespaceRegistry.new,
                   current_namespace: nil)
      @environment = environment
      @builtins = builtins
      @namespaces = namespaces
      @parser = Parser.new
      @current_namespace = current_namespace
      @namespace_stack = [current_namespace]
      @current_file = nil
      @loaded_files = {}
      @loading_stack = []
    end

    def evaluate(node)
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
        LambdaValue.new(node.params, node.body, @environment.snapshot, @current_namespace)
      else
        raise Calc::RuntimeError, "unknown node: #{node.class}"
      end
    end

    def evaluate_source(source, source_path: nil)
      nodes = @parser.parse(source)
      evaluate_nodes(nodes, source_path: source_path)
    end

    def evaluate_nodes(nodes, source_path: nil)
      with_source_path(source_path) do
        nodes.reduce(nil) do |_memo, node|
          evaluate(node)
        rescue StandardError => e
          raise contextualize_error(e, node) if source_path

          raise
        end
      end
    end

    private

    def resolve_symbol(node)
      return @environment.get_local(node.name) if @environment.bound_local?(node.name)

      found, builtin = @builtins.resolve(node.name)
      return builtin if found

      return @environment.get(node.name) if @environment.bound?(node.name)

      resolved_variable = @namespaces.resolve_variable(@current_namespace, node.name)
      return resolved_variable[:value] if resolved_variable

      resolved_function = @namespaces.resolve_function(@current_namespace, node.name)
      return resolved_function[:value] if resolved_function

      @environment.get(node.name)
    end

    def evaluate_list(node)
      head = node.children.first
      case head
      when SymbolNode
        case head.name
        when "define"
          handle_define(node.children)
        when "if"
          evaluate_if(node.children)
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

    def call_lambda(callable, values)
      params = callable.params
      raise Calc::RuntimeError, "wrong number of arguments" unless params.length == values.length

      previous_environment = @environment
      previous_namespace = @current_namespace
      @environment = Environment.new(callable.environment)
      params.zip(values).each { |param, value| @environment.set(param, value) }
      @current_namespace = callable.namespace
      @namespace_stack << @current_namespace

      evaluate(callable.body)
    ensure
      @namespace_stack.pop
      @environment = previous_environment
      @current_namespace = previous_namespace
    end

    def call_value_callable(callable, values)
      raise Calc::NameError, "expected a function" unless callable.is_a?(LambdaValue)

      call_lambda(callable, values)
    end

    def call_user_function(function_entry, values)
      call_lambda(function_entry, values)
    end

    def build_lambda_value(param_nodes, body_node)
      params = param_nodes.map do |param|
        raise Calc::SyntaxError, "invalid function parameter" unless param.is_a?(SymbolNode)

        param.name
      end

      LambdaValue.new(params, body_node, @environment.snapshot, @current_namespace)
    end
  end
end
