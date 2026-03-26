module Calc
  class Executer
    def initialize(environment = Environment.new, builtins = Builtins.new, namespaces = NamespaceRegistry.new,
                   current_namespace: nil)
      @environment = environment
      @builtins = builtins
      @namespaces = namespaces
      @current_namespace = current_namespace
      @namespace_stack = [current_namespace]
    end

    def evaluate(node)
      case node
      when NumberNode
        node.value
      when SymbolNode
        return @environment.get_local(node.name) if @environment.bound_local?(node.name)

        found, builtin = @builtins.resolve(node.name)
        return builtin if found

        resolved_variable = @namespaces.resolve_variable(@current_namespace, node.name)
        return resolved_variable[:value] if resolved_variable

        resolved_function = @namespaces.resolve_function(@current_namespace, node.name)
        return resolved_function[:value] if resolved_function

        @environment.get(node.name)
      when ListNode
        evaluate_list(node)
      else
        raise ArgumentError, "unknown node: #{node.class}"
      end
    end

    private

    def evaluate_list(node)
      head = node.children.first
      case head
      when SymbolNode
        case head.name
        when "define"
          function_definition?(node.children) ? define_function(node.children) : define_variable(node.children)
        when "if"
          evaluate_if(node.children)
        when "namespace"
          evaluate_namespace(node.children)
        else
          call_function(head.name, node.children.drop(1))
        end
      else
        raise ArgumentError, "invalid expression"
      end
    end

    def define_variable(children)
      name_node = children[1]
      value_node = children[2]
      raise ArgumentError, "invalid define" unless name_node.is_a?(SymbolNode) && value_node
      raise NameError, "cannot redefine reserved literal: #{name_node.name}" if @builtins.reserved?(name_node.name)

      value = evaluate(value_node)
      @environment.set(name_node.name, value) if @current_namespace.nil?
      @namespaces.define_variable(@current_namespace, name_node.name, value, local: name_node.name.start_with?("_"))
      value
    end

    def function_definition?(children)
      children[1].is_a?(ListNode)
    end

    def define_function(children)
      signature = children[1]
      name_node = signature.children.first
      param_nodes = signature.children.drop(1)
      body_node = children[2]

      raise ArgumentError, "invalid function definition" unless name_node.is_a?(SymbolNode) && body_node
      raise NameError, "cannot redefine reserved literal: #{name_node.name}" if @builtins.reserved?(name_node.name)

      params = param_nodes.map do |param|
        raise ArgumentError, "invalid function parameter" unless param.is_a?(SymbolNode)

        param.name
      end

      function_entry = {
        params: params,
        body: body_node,
        namespace: @current_namespace,
        local: name_node.name.start_with?("_")
      }

      @namespaces.define_function(@current_namespace, name_node.name, function_entry, local: function_entry[:local])
      function_label = [@current_namespace, name_node.name].compact.join(".")
      "defined function #{function_label}(#{params.join(', ')})"
    end

    def evaluate_namespace(children)
      namespace_node = children[1]
      body_nodes = children.drop(2)
      raise ArgumentError, "invalid namespace" unless namespace_node.is_a?(SymbolNode)

      previous_namespace = @current_namespace
      next_namespace = namespace_path(namespace_node.name)
      @current_namespace = next_namespace
      @namespace_stack << next_namespace
      @namespaces.ensure_namespace(@current_namespace)

      result = body_nodes.reduce(nil) { |_memo, body_node| evaluate(body_node) }
      result
    ensure
      @namespace_stack.pop
      @current_namespace = previous_namespace
    end

    def evaluate_if(children)
      condition_node = children[1]
      then_node = children[2]
      else_node = children[3]
      raise ArgumentError, "invalid if" unless children.length == 4 && condition_node && then_node && else_node

      condition = evaluate(condition_node)
      truthy?(condition) ? evaluate(then_node) : evaluate(else_node)
    end

    def truthy?(value)
      value != false && !value.nil?
    end

    def call_function(name, args)
      values = args.map { |arg| evaluate(arg) }

      return @builtins.call(name, values) if @builtins.registered?(name)

      resolved_function = @namespaces.resolve_function(@current_namespace, name)
      return call_user_function(resolved_function[:value], values) if resolved_function

      @builtins.call(name, values)
    end

    def call_user_function(function_entry, values)
      params = function_entry[:params]
      raise ArgumentError, "wrong number of arguments" unless params.length == values.length

      previous_environment = @environment
      previous_namespace = @current_namespace
      @environment = Environment.new(previous_environment)
      params.zip(values).each { |param, value| @environment.set(param, value) }
      @current_namespace = function_entry[:namespace]
      @namespace_stack << @current_namespace

      evaluate(function_entry[:body])
    ensure
      @namespace_stack.pop
      @environment = previous_environment
      @current_namespace = previous_namespace
    end

    def namespace_path(name)
      return name if name.include?(".")

      parent = @namespace_stack.last
      parent.nil? ? name : [parent, name].join(".")
    end
  end
end
