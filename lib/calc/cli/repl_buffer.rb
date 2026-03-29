module Calc
  module Cli
    class ReplBuffer
      def initialize
        @source = +""
      end

      def prompt
        @source.empty? ? "> " : "... "
      end

      def append(line)
        @source << line << "\n"
      end

      def empty?
        @source.empty?
      end

      def clear
        @source.clear
      end

      def unmatched_closing_paren?
        paren_depth.negative?
      end

      def balanced_parens?
        paren_depth.zero?
      end

      def to_source
        @source.strip
      end

      private

      def paren_depth
        depth = 0

        @source.each_line do |line|
          code = line.sub(/;.*$/, "")

          code.each_char do |char|
            case char
            when "("
              depth += 1
            when ")"
              depth -= 1
              return depth if depth.negative?
            end
          end
        end

        depth
      end
    end
  end
end
