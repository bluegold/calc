module Calc
  module Cli
    class DebugBreakpointManager
      attr_reader :breakpoints

      def initialize
        @breakpoints = []
        @seq = 0
      end

      def create(payload, valid_lines: nil)
        kind, target = parse_target(payload, valid_lines: valid_lines)
        @seq += 1
        breakpoint = Calc::Breakpoint.new(id: @seq, kind: kind, target: target)
        @breakpoints << breakpoint
        breakpoint
      end

      def hit?(node)
        @breakpoints.any? do |breakpoint|
          if breakpoint.line?
            breakpoint.target == node.line
          else
            function_breakpoint_hit?(breakpoint, node)
          end
        end
      end

      def hit_message(node)
        line = node.line || 0
        "Breakpoint hit at L#{line}"
      end

      def line_breakpoint_targets
        @breakpoints.select(&:line?).map(&:target)
      end

      private

      def parse_target(payload, valid_lines: nil)
        raise ArgumentError, "usage: break <line>|<function>" if payload.to_s.strip.empty?

        text = payload.strip
        if text.match?(/\A\d+\z/)
          line = Integer(text, 10)
          raise ArgumentError, "unable to resolve breakpoint line: #{text}" if valid_lines && !valid_lines.include?(line)

          return [:line, line]
        end

        [:function, text]
      end

      def function_breakpoint_hit?(breakpoint, node)
        return false unless node.is_a?(Calc::ListNode) && node.children.first.is_a?(Calc::SymbolNode)

        head = node.children.first
        function_breakpoint_targets(head).include?(breakpoint.target) || define_function_breakpoint_hit?(breakpoint, node, head)
      end

      def define_function_breakpoint_hit?(breakpoint, node, head)
        return false unless head.name == "define" && node.children[1].is_a?(Calc::ListNode)

        signature = node.children[1]
        return false unless signature.children.first.is_a?(Calc::SymbolNode)

        function_breakpoint_targets(signature.children.first).include?(breakpoint.target)
      end

      def function_breakpoint_targets(symbol_node)
        targets = [symbol_node.name]
        namespace = symbol_node.respond_to?(:namespace) ? symbol_node.namespace : nil
        targets << "#{namespace}.#{symbol_node.name}" if namespace
        targets
      end
    end
  end
end
