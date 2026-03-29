module Calc
  class Executer
    # Module responsible for formatting error messages and string representation of AST nodes.
    # It adds context information (file name, line number, column, and the expression being evaluated)
    # to runtime errors to aid in debugging.
    module Formatter
      private

      # Contextualizes an error by adding location and expression context.
      #
      # @param error [StandardError] The original error object.
      # @param node [Calc::Node] The AST node where the error occurred.
      # @return [StandardError] The error object with added context information.
      def contextualize_error(error, node)
        return error if error.message.include?("while evaluating")

        location = format_location(node)
        context = format_node(node)
        message = [location, error.class, error.message, "while evaluating #{context}"].compact.join(": ")
        error.class.new(message).tap do |wrapped|
          wrapped.set_backtrace(error.backtrace)
        end
      end

      # Formats location information (file, line, column) from an AST node.
      #
      # @param node [Calc::Node] The AST node.
      # @return [String, nil] Formatted location string, or nil if no location info.
      def format_location(node)
        return nil unless node.respond_to?(:line) && node.line

        path = @current_file || "<input>"
        "#{path}:#{node.line}:#{node.column || 1}"
      end

      # Formats an AST node into a human-readable string representation.
      #
      # @param node [Calc::Node] The AST node.
      # @return [String] The formatted string representation of the node.
      def format_node(node)
        case node
        when NumberNode
          Calc.format_value(node.value)
        when StringNode
          node.value.inspect
        when KeywordNode
          ":#{node.name}"
        when SymbolNode
          node.name
        when LambdaNode
          "(lambda (#{node.params.join(' ')}) #{format_node(node.body)})"
        when ListNode
          "(#{node.children.map { |child| format_node(child) }.join(' ')})"
        else
          Calc::ASTPrinter.pretty([node]).strip
        end
      end
    end
  end
end
