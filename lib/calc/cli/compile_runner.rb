module Calc
  module Cli
    module CompileRunner
      module_function

      # Compiles a Calc source file and saves bytecode to disk.
      def run(parser, compiler, script_path, output_path: nil, io: { out: $stdout, err: $stderr })
        out = io.fetch(:out)
        err = io.fetch(:err)

        raise Calc::RuntimeError, "compile requires a script path" unless script_path

        source = File.read(script_path)
        nodes = parser.parse(source)
        code = compiler.compile_program(nodes, name: File.expand_path(script_path))
        destination = output_path || default_output_path(script_path)

        Calc::Bytecode.save(code, destination)
        out.puts destination
        0
      rescue StandardError => e
        err.puts e.message
        1
      end

      def default_output_path(script_path)
        base = File.basename(script_path, File.extname(script_path))
        File.join(File.dirname(script_path), "#{base}#{Calc::Bytecode::FILE_EXTENSION}")
      end
      private_class_method :default_output_path
    end
  end
end
