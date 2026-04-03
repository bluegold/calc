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

          command_name, payload = command.split(/\s+/, 2)

          case command_name
          when "quit"
            return
          when "run", "continue", "step", "next", "finish", "break", "bt", "locals", "print", "list"
            print_not_implemented(command_name, payload)
          when "help"
            print_help
          else
            @err.puts "unknown debugger command: #{command_name}"
          end
        end
      end

      def print_not_implemented(command, payload)
        command_text = payload ? "#{command} #{payload}" : command
        @out.puts "#{command_text} is not implemented yet"
      end

      def print_help
        @out.puts "Commands:"
        @out.puts "  run              Start program execution"
        @out.puts "  continue         Resume execution after a pause"
        @out.puts "  step             Step into the next stoppable instruction"
        @out.puts "  next             Step over the current frame"
        @out.puts "  finish           Run until the current frame returns"
        @out.puts "  break <target>   Set a breakpoint by function or line"
        @out.puts "  bt               Show the current backtrace"
        @out.puts "  locals           Show locals for the selected frame"
        @out.puts "  print <expr>     Evaluate an expression in the paused context"
        @out.puts "  list [n] [bytecode]  Show nearby source lines, optionally with bytecode"
        @out.puts "  help             Show this help"
        @out.puts "  quit             Exit the debugger"
      end
    end
  end
end
