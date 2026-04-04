module Calc
  module Cli
    class DebugCompletion
      COMMANDS = %w[break continue step next finish bt locals print list run help quit].freeze

      def candidates(fragment, line_buffer, cursor)
        return [] if fragment.to_s.empty?
        return [] unless command_context?(line_buffer.to_s, cursor.to_i)

        COMMANDS.grep(/^#{Regexp.escape(fragment)}/)
      end

      private

      def command_context?(line_buffer, cursor)
        return false if line_buffer.empty?

        fragment_start = token_start(line_buffer, cursor)
        command_start = line_buffer.index(/\S/)
        command_start == fragment_start
      end

      def token_start(line_buffer, cursor)
        index = cursor
        index -= 1 while index.positive? && line_buffer[index - 1] && !line_buffer[index - 1].match?(/[\s(){}\[\]]/)
        index
      end
    end
  end
end
