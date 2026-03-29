require "reline"

module Calc
  module Cli
    class App
      def initialize(argv: ARGV, out: $stdout, err: $stderr, history_path: File.join(Dir.home, ".calc_history"))
        @argv = argv
        @out = out
        @err = err
        @history_path = history_path
      end

      def run
        parser = Calc::Parser.new
        executer = Calc::Executer.new
        builtins = executer.builtins

        configure_completion(executer, builtins)

        options = parse_options
        return 1 unless options

        return TestRunner.run(executer, options.remaining_args, out: @out, err: @err) if options.subcommand == "test"
        if options.script_path
          return FileRunner.run(
            executer,
            options.script_path,
            options.print_last_result,
            out: @out,
            err: @err
          )
        end

        run_repl(parser, executer, builtins)
      end

      private

      def configure_completion(executer, builtins)
        completion = Calc::ReplCompletion.new(
          builtins,
          symbol_candidates_provider: ->(namespace_path) { executer.completion_candidates(namespace_path: namespace_path) }
        )

        Reline.completion_proc = proc do |fragment|
          completion.candidates(fragment, Reline.line_buffer.to_s, Reline.point || 0)
        end
        Reline.autocompletion = true
      end

      def parse_options
        Options.parse(@argv)
      rescue Options::InvalidOptionError => e
        @err.puts e.message
        nil
      end

      def run_repl(parser, executer, builtins)
        History.load(@history_path, warning_io: @err)

        command_handler = ReplCommandHandler.new(parser: parser, builtins: builtins, out: @out, err: @err)
        runner = ReplRunner.new(
          parser: parser,
          executer: executer,
          command_handler: command_handler,
          io: { out: @out, err: @err }
        )
        runner.run

        History.save(@history_path, warning_io: @err)
        0
      end
    end
  end
end
