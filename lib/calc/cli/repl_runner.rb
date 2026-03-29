require "reline"

module Calc
  module Cli
    class ReplRunner
      def initialize(parser:, executer:, command_handler:, history: Reline::HISTORY, io: {})
        @parser = parser
        @executer = executer
        @command_handler = command_handler
        @history = history
        @out = io.fetch(:out, $stdout)
        @err = io.fetch(:err, $stderr)
      end

      def run
        buffer = ReplBuffer.new

        loop do
          line = Reline.readline(buffer.prompt, false)
          break unless line

          next if buffer.empty? && line.strip.empty?

          buffer.append(line)

          if buffer.unmatched_closing_paren?
            @err.puts "unexpected ')'"
            buffer.clear
            next
          end

          next unless buffer.balanced_parens?

          source = buffer.to_source
          buffer.clear

          next if source.empty?

          if source.start_with?(":")
            @history << source if @command_handler.handle(source)
            next
          end

          last_result = evaluate_source(source)
          @out.puts Calc.format_value(last_result) unless last_result.nil?
          @history << source
        rescue StandardError => e
          @err.puts "#{e.class}: #{e.message}"
          buffer.clear
        end
      end

      private

      def evaluate_source(source)
        last_result = nil
        @parser.parse(source).each do |node|
          last_result = @executer.evaluate(node)
        end
        last_result
      end
    end
  end
end
