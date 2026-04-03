module Calc
  module Cli
    # Entry point for the first VM debugger CLI flow.
    # This version establishes the debug command wiring and a minimal prompt loop.
    class DebugRunner
      PROMPT = "(calcdb) ".freeze

      def self.run(parser, compiler, executer, script_path, io:)
        new(parser, compiler, executer, script_path, io: io).run
      end

      def initialize(parser, compiler, executer, script_path, io:)
        @parser = parser
        @compiler = compiler
        @executer = executer
        @script_path = script_path
        @out = io.fetch(:out)
        @err = io.fetch(:err)
        @in = io.fetch(:in, $stdin)
      end

      def run
        source = File.read(@script_path)
        nodes = @parser.parse(source)
        code = @compiler.compile_program(nodes, name: @script_path)

        @out.puts "debugger scaffold loaded for #{@script_path}"
        @out.puts code.disassemble
        run_prompt_loop
        0
      rescue StandardError => e
        @err.puts e.message
        1
      end

      private

      def run_prompt_loop
        loop do
          @out.print PROMPT
          @out.flush

          line = @in.gets
          break if line.nil?

          command = line.strip
          next if command.empty?

          case command
          when "quit"
            return
          else
            @err.puts "unknown debugger command: #{command}"
          end
        end
      end
    end
  end
end
