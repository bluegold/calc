module Calc
  module Cli
    module TestRunner
      module_function

      def run(executer, paths, out: $stdout, err: $stderr)
        explicit_targets = !paths.empty?
        test_paths = explicit_targets ? paths.flat_map { |path| collect_test_files(path) }.uniq : default_test_paths

        if explicit_targets && test_paths.empty?
          err.puts "no .calc test files matched: #{paths.join(' ')}"
          return 1
        end

        if test_paths.empty?
          err.puts "no .calc test files found"
          return 1
        end

        out_colorize = tty?(out)
        err_colorize = tty?(err)
        total = test_paths.length
        passed = 0
        failures = []

        out.puts cyan("Running #{total} calc tests", out_colorize)

        test_paths.each do |path|
          source = File.read(path)
          begin
            result = executer.evaluate_source(source, source_path: File.expand_path(path))
            passed += 1
            out.puts green("PASS", out_colorize) + " #{path}"
            out.puts Calc.format_value(result) unless result.nil?
          rescue StandardError => e
            failures << path
            err.puts red("FAIL", err_colorize) + " #{path}: #{e.message}"
          end
        end

        failed = failures.length
        summary = "#{passed} passed, #{failed} failed"
        out.puts cyan(summary, out_colorize)

        failures.empty? ? 0 : 1
      end

      def default_test_paths
        %w[stdlib/test modules/test samples/test]
          .select { |path| Dir.exist?(path) }
          .flat_map { |path| collect_test_files(path) }
      end

      def collect_test_files(path)
        return [path] if File.file?(path) && path.end_with?(".calc")

        return [] unless Dir.exist?(path)

        Dir.glob(File.join(path, "**", "*.calc"))
      end

      def tty?(io)
        io.respond_to?(:tty?) && io.tty?
      end

      def color(text, code, enabled)
        enabled ? "\e[#{code}m#{text}\e[0m" : text
      end

      def green(text, enabled)
        color(text, 32, enabled)
      end

      def red(text, enabled)
        color(text, 31, enabled)
      end

      def cyan(text, enabled)
        color(text, 36, enabled)
      end
    end
  end
end
