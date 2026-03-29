module Calc
  module Cli
    module FileRunner
      module_function

      def run(executer, script_path, print_last_result, out: $stdout, err: $stderr)
        source = File.read(script_path)
        last_result = executer.evaluate_source(source, source_path: File.expand_path(script_path))

        out.puts Calc.format_value(last_result) if print_last_result && !last_result.nil?
        0
      rescue StandardError => e
        err.puts e.message
        1
      end
    end
  end
end
