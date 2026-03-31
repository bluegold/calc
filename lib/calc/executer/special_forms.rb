module Calc
  class Executer
    # Module encapsulating the evaluation logic for Calc's special forms
    # (`define`, `if`, `namespace`, `lambda`, `do`, `load`).
    # Defines the post-parsing processing for each special form.
    module SpecialForms
      private

      # Handles the `define` special form. Distinguishes between variable and function definitions
      # and calls the appropriate handler.
      #
      # @param children [Array<Calc::Node>] An array of child nodes of the `define` expression.
      # @return [Object] The value of the defined variable or function.
      def handle_define(children)
        function_definition?(children) ? define_function(children) : define_variable(children)
      end

      # Processes variable definition (`define symbol value`).
      #
      # @param children [Array<Calc::Node>] An array of child nodes for the variable definition.
      # @return [Object] The value of the defined variable.
      # @raise [Calc::SyntaxError] If the syntax is invalid.
      # @raise [Calc::NameError] If attempting to redefine a reserved literal.
      def define_variable(children)
        name_node = children[1]
        value_node = children[2]
        raise Calc::SyntaxError, "invalid define: expected (define name value)" unless children.length == 3
        raise Calc::SyntaxError, "invalid define: expected (define name value)" unless name_node.is_a?(SymbolNode) && value_node
        raise Calc::NameError, "cannot redefine reserved literal: #{name_node.name}" if @builtins.reserved?(name_node.name)
        raise Calc::NameError, "cannot modify reserved namespace: builtin" if @current_namespace == "builtin"

        value = evaluate(value_node)
        @environment.set(name_node.name, value) if @current_namespace.nil?
        @namespaces.define_variable(@current_namespace, name_node.name, value, local: name_node.name.start_with?("_"))
        value
      end

      # Determines if an expression is in the form of a function definition
      # (`(define (func-name params...) body)`).
      #
      # @param children [Array<Calc::Node>] An array of child nodes of the `define` expression.
      # @return [Boolean] True if it's a function definition, false otherwise.
      def function_definition?(children)
        children[1].is_a?(ListNode)
      end

      # Processes function definition (`define (func-name params...) body`).
      #
      # @param children [Array<Calc::Node>] An array of child nodes for the function definition.
      # @return [String] A string indicating the defined function.
      # @raise [Calc::SyntaxError] If the syntax is invalid.
      # @raise [Calc::NameError] If attempting to redefine a reserved literal.
      def define_function(children)
        signature = children[1]
        name_node = signature.children.first
        param_nodes = signature.children.drop(1)
        body_node = normalized_body_node(children, 2)

        raise Calc::SyntaxError, "invalid function definition" unless name_node.is_a?(SymbolNode) && body_node
        raise Calc::NameError, "cannot redefine reserved literal: #{name_node.name}" if @builtins.reserved?(name_node.name)
        raise Calc::NameError, "cannot modify reserved namespace: builtin" if @current_namespace == "builtin"

        lambda_value = build_lambda_value(param_nodes, body_node)

        @namespaces.define_function(@current_namespace, name_node.name, lambda_value, local: name_node.name.start_with?("_"))
        function_label = [@current_namespace, name_node.name].compact.join(".")
        "defined function #{function_label}(#{lambda_value.params.join(', ')})"
      end

      # Evaluates a lambda expression (`lambda (params...) body`) and constructs a `LambdaValue` object.
      #
      # @param children [Array<Calc::Node>] An array of child nodes for the lambda expression.
      # @return [LambdaValue] The constructed lambda value.
      # @raise [Calc::SyntaxError] If the syntax is invalid.
      def evaluate_lambda(children)
        params_node = children[1]
        body_node = normalized_body_node(children, 2)
        raise Calc::SyntaxError, "invalid lambda" unless params_node.is_a?(ListNode) && body_node

        param_nodes = params_node.children
        build_lambda_value(param_nodes, body_node)
      end

      def normalized_body_node(children, start_index)
        body_nodes = children.drop(start_index)
        return nil if body_nodes.empty?
        return body_nodes.first if body_nodes.length == 1

        do_symbol = SymbolNode.new("do", body_nodes.first.line, body_nodes.first.column)
        ListNode.new([do_symbol, *body_nodes], body_nodes.first.line, body_nodes.first.column)
      end

      # Evaluates a `do` block. Sequentially evaluates multiple expressions and returns
      # the result of the last expression.
      #
      # @param children [Array<Calc::Node>] An array of child nodes for the `do` expression.
      # @return [Object] The result of the last expression evaluated in the block.
      # @raise [Calc::SyntaxError] If the syntax is invalid.
      def evaluate_do(children)
        raise Calc::SyntaxError, "invalid do" if children.length < 2

        children.drop(1).reduce(nil) { |_memo, node| evaluate(node) }
      end

      # Evaluates the `namespace` special form. Evaluates a block of expressions within
      # the specified namespace.
      #
      # @param children [Array<Calc::Node>] An array of child nodes for the `namespace` expression.
      # @return [Object] The result of the last expression evaluated in the block.
      # @raise [Calc::SyntaxError] If the syntax is invalid.
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

      # Evaluates the `if` special form. Evaluates the `then` or `else` block based on
      # the truthiness of the condition expression.
      #
      # @param children [Array<Calc::Node>] An array of child nodes for the `if` expression.
      # @return [Object] The final result of the evaluated branch.
      # @raise [Calc::SyntaxError] If the syntax is invalid.
      def evaluate_if(children)
        condition_node = children[1]
        then_node = children[2]
        else_node = children[3]
        unless children.length == 4 && condition_node && then_node && else_node
          raise Calc::SyntaxError, "invalid if: expected (if condition then-expr else-expr)"
        end

        condition = evaluate(condition_node)
        truthy?(condition) ? evaluate(then_node) : evaluate(else_node)
      end

      # Evaluates the `and` special form with short-circuit semantics.
      # Returns false on the first falsey value, otherwise returns the last value.
      # With no operands, returns true.
      #
      # @param children [Array<Calc::Node>] An array of child nodes for the `and` expression.
      # @return [Object] The first falsey value or the last truthy value.
      def evaluate_and(children)
        values = children.drop(1)
        return true if values.empty?

        result = true
        values.each do |value_node|
          result = evaluate(value_node)
          return result unless truthy?(result)
        end

        result
      end

      # Evaluates the `or` special form with short-circuit semantics.
      # Returns the first truthy value. With no operands, returns false.
      #
      # @param children [Array<Calc::Node>] An array of child nodes for the `or` expression.
      # @return [Object] The first truthy value or false when no operand is truthy.
      def evaluate_or(children)
        values = children.drop(1)
        return false if values.empty?

        values.each do |value_node|
          result = evaluate(value_node)
          return result if truthy?(result)
        end

        false
      end

      # Evaluates the `cond` special form.
      # Each clause must be `(test expr)` or `(else expr)`.
      # Clauses are checked in order and the first matching expression is evaluated.
      #
      # @param children [Array<Calc::Node>] An array of child nodes for the `cond` expression.
      # @return [Object, nil] The matched branch result, or nil when no clause matches.
      # @raise [Calc::SyntaxError] If a clause has invalid shape or `else` is not the final clause.
      def evaluate_cond(children)
        clauses = children.drop(1)
        raise Calc::SyntaxError, "invalid cond: expected at least one clause" if clauses.empty?

        clauses.each_with_index do |clause_node, index|
          unless clause_node.is_a?(ListNode) && clause_node.children.length == 2
            raise Calc::SyntaxError, "invalid cond: each clause must be (test expr)"
          end

          test_node, body_node = clause_node.children
          is_else_clause = test_node.is_a?(SymbolNode) && test_node.name == "else"

          if is_else_clause
            raise Calc::SyntaxError, "invalid cond: else must be the last clause" unless index == clauses.length - 1

            return evaluate(body_node)
          end

          return evaluate(body_node) if truthy?(evaluate(test_node))
        end

        nil
      end

      # Determines if a value is truthy (not false and not nil).
      #
      # @param value [Object] The value to check.
      # @return [Boolean] True if truthy, false otherwise.
      def truthy?(value)
        value != false && !value.nil?
      end

      # Resolves a relative namespace name to a full namespace path.
      #
      # @param name [String] The namespace name to resolve.
      # @return [String] The resolved full namespace path.
      def namespace_path(name)
        return name if name.include?(".")

        parent = @namespace_stack.last
        parent.nil? ? name : [parent, name].join(".")
      end
    end
  end
end
