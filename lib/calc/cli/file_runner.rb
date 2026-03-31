module Calc
  module Cli
    module FileRunner
      module_function

      # Executes a Calc source file and optionally prints the final value.
      def run(executer, script_path, print_last_result, out: $stdout, err: $stderr)
        last_result = if bytecode_file?(script_path)
                        code = Calc::Bytecode.load(script_path)
                        executer.evaluate_bytecode(code)
                      else
                        source = File.read(script_path)
                        executer.evaluate_source(source, source_path: File.expand_path(script_path))
                      end

        out.puts Calc.format_value(last_result) if print_last_result && !last_result.nil?
        0
      rescue StandardError => e
        err.puts e.message
        1
      end

      def bytecode_file?(script_path)
        File.extname(script_path) == Calc::Bytecode::FILE_EXTENSION
      end
      private_class_method :bytecode_file?
    end
  end
end
