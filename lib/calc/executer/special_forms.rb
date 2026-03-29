module Calc
  class Executer
    module SpecialForms
      private

      def handle_define(children)
        function_definition?(children) ? define_function(children) : define_variable(children)
      end

      def define_variable(children)
        name_node = children[1]
        value_node = children[2]
        raise Calc::SyntaxError, "invalid define" unless name_node.is_a?(SymbolNode) && value_node
        raise Calc::NameError, "cannot redefine reserved literal: #{name_node.name}" if @builtins.reserved?(name_node.name)
        raise Calc::NameError, "cannot modify reserved namespace: builtin" if @current_namespace == "builtin"

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

        raise Calc::SyntaxError, "invalid function definition" unless name_node.is_a?(SymbolNode) && body_node
        raise Calc::NameError, "cannot redefine reserved literal: #{name_node.name}" if @builtins.reserved?(name_node.name)
        raise Calc::NameError, "cannot modify reserved namespace: builtin" if @current_namespace == "builtin"

        lambda_value = build_lambda_value(param_nodes, body_node)

        @namespaces.define_function(@current_namespace, name_node.name, lambda_value, local: name_node.name.start_with?("_"))
        function_label = [@current_namespace, name_node.name].compact.join(".")
        "defined function #{function_label}(#{lambda_value.params.join(', ')})"
      end

      def evaluate_lambda(children)
        params_node = children[1]
        body_node = children[2]
        raise Calc::SyntaxError, "invalid lambda" unless params_node.is_a?(ListNode) && body_node

        param_nodes = params_node.children
        build_lambda_value(param_nodes, body_node)
      end

      def evaluate_do(children)
        raise Calc::SyntaxError, "invalid do" if children.length < 2

        children.drop(1).reduce(nil) { |_memo, node| evaluate(node) }
      end

      def evaluate_namespace(children)
        namespace_node = children[1]
        body_nodes = children.drop(2)
        raise Calc::SyntaxError, "invalid namespace" unless namespace_node.is_a?(SymbolNode)

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
        raise Calc::SyntaxError, "invalid if" unless children.length == 4 && condition_node && then_node && else_node

        condition = evaluate(condition_node)
        truthy?(condition) ? evaluate(then_node) : evaluate(else_node)
      end

      def truthy?(value)
        value != false && !value.nil?
      end

      def namespace_path(name)
        return name if name.include?(".")

        parent = @namespace_stack.last
        parent.nil? ? name : [parent, name].join(".")
      end
    end
  end
end
