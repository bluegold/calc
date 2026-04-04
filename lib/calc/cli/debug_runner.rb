require "reline"

module Calc
  module Cli
    # Entry point for the first VM debugger CLI flow.
    # This version establishes the debug command wiring and a minimal prompt loop.
    class DebugRunner
      PROMPT = "(calcdb) ".freeze
      Context = Struct.new(:parser, :compiler, :executer, :script_path, :io, :history)

      def self.run(context)
        new(context).run
      end

      def initialize(context)
        @session = Calc::Cli::DebugSession.new(context)
        @out = context.io.fetch(:out)
        @err = context.io.fetch(:err)
        @in = context.io.fetch(:in, $stdin)
        @history = context.history || Reline::HISTORY
        @dispatcher = Calc::Cli::DebugCommandDispatcher.new(@session, @out, @err)
      end

      def run
        @session.load!

        @out.puts "debugger scaffold loaded for #{@session.script_path}"
        @out.puts @session.code.disassemble
        run_prompt_loop
        @session.terminate! unless @session.terminated?
        0
      rescue StandardError => e
        @session.terminate! unless @session.terminated?
        @err.puts e.message
        1
      end

      private

      def run_prompt_loop
        loop do
          line = read_command
          break if line.nil?

          command = line.strip
          next if command.empty?

          command_name, payload = command.split(/\s+/, 2)

          if command_name == "quit"
            @session.terminate!
            return
          end

          @dispatcher.dispatch(command_name, payload)
          return if @session.terminated?
        end
      end

      def read_command
        if @in.tty?
          Reline.readline(PROMPT, true)
        else
          @out.print PROMPT
          @out.flush
          @in.gets&.chomp
        end
      end
    end
  end
end
