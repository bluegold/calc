module Calc
  module Cli
    class ReplBuffer
      # Starts with an empty multi-line buffer.
      def initialize
        @source = +""
      end

      # Returns prompt text based on whether input is continued.
      def prompt
        @source.empty? ? "> " : "... "
      end

      # Appends one input line to the buffer.
      def append(line)
        @source << line << "\n"
      end

      # True when no buffered input is present.
      def empty?
        @source.empty?
      end

      # Clears the accumulated source buffer.
      def clear
        @source.clear
      end

      # True when a closing parenthesis appears without matching open parenthesis.
      def unmatched_closing_paren?
        paren_depth.negative?
      end

      # True when all buffered parentheses are balanced.
      def balanced_parens?
        paren_depth.zero?
      end

      # Returns the buffered source trimmed for parsing.
      def to_source
        @source.strip
      end

      private

      # Computes net parenthesis depth while ignoring line comments.
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
