module Calc
  module Cli
    module BytecodeRunner
      module_function

      # Compiles a Calc source file and prints bytecode disassembly.
      def run(parser, compiler, script_path, out: $stdout, err: $stderr)
        raise Calc::RuntimeError, "bytecode requires a script path" unless script_path

        source = File.read(script_path)
        nodes = parser.parse(source)
        code = compiler.compile_program(nodes, name: File.expand_path(script_path))
        out.puts code.disassemble
        0
      rescue StandardError => e
        err.puts e.message
        1
      end
    end
  end
end
