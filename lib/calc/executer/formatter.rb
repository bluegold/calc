module Calc
  class Executer
    module Formatter
      private

      def contextualize_error(error, node)
        return error if error.message.include?("while evaluating")

        location = format_location(node)
        context = format_node(node)
        message = [location, error.class, error.message, "while evaluating #{context}"].compact.join(": ")
        error.class.new(message).tap do |wrapped|
          wrapped.set_backtrace(error.backtrace)
        end
      end

      def format_location(node)
        return nil unless node.respond_to?(:line) && node.line

        path = @current_file || "<input>"
        "#{path}:#{node.line}:#{node.column || 1}"
      end

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
