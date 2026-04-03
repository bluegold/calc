module Calc
  module Cli
    # Entry point for the first VM debugger CLI flow.
    # This version validates input and establishes the debug command wiring,
    # but the interactive debugger loop will be added in the next phase.
    class DebugRunner
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
      end

      def run
        source = File.read(@script_path)
        nodes = @parser.parse(source)
        code = @compiler.compile_program(nodes, name: @script_path)

        @out.puts "debugger scaffold loaded for #{@script_path}"
        @out.puts code.disassemble
        0
      rescue StandardError => e
        @err.puts e.message
        1
      end
    end
  end
end
