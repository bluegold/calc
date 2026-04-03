require "reline"

module Calc
  module Cli
    class App
      # Builds a CLI app runner with injectable I/O and argv for tests.
      def initialize(argv: ARGV, out: $stdout, err: $stderr, history_path: File.join(Dir.home, ".calc_history"))
        @argv = argv
        @out = out
        @err = err
        @history_path = history_path
      end

      # Dispatches to test mode, file mode, or interactive REPL mode.
      def run
        options = parse_options
        return 1 unless options

        parser = Calc::Parser.new

        if options.subcommand == "bytecode"
          compiler = Calc::Compiler.new(Calc::Builtins.new)
          return BytecodeRunner.run(parser, compiler, options.script_path, out: @out, err: @err)
        end

        if options.subcommand == "compile"
          compiler = Calc::Compiler.new(Calc::Builtins.new)
          return CompileRunner.run(
            parser,
            compiler,
            options.script_path,
            output_path: options.output_path,
            io: { out: @out, err: @err }
          )
        end

        if options.subcommand == "debug"
          unless options.script_path
            @err.puts "debug requires a script path"
            return 1
          end

          executer = build_executer(options)
          compiler = Calc::Compiler.new(executer.builtins)
          return DebugRunner.run(
            parser,
            compiler,
            executer,
            options.script_path,
            io: { out: @out, err: @err }
          )
        end

        executer = build_executer(options)
        builtins = executer.builtins

        configure_completion(executer, builtins)

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

      # Enables Reline completion backed by current builtin and symbol candidates.
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

      # Parses CLI options and reports invalid options to stderr.
      def parse_options
        Options.parse(@argv)
      rescue Options::InvalidOptionError, Options::MissingOptionValueError => e
        @err.puts e.message
        nil
      end

      def build_executer(options)
        Calc::Executer.new(vm_trace: options.trace_vm, vm_trace_io: @err)
      end

      # Runs the interactive loop with history lifecycle management.
      def run_repl(parser, executer, builtins)
        History.with_session(@history_path, warning_io: @err) do
          command_handler = ReplCommandHandler.new(
            parser: parser,
            builtins: builtins,
            executer: executer,
            io: { out: @out, err: @err }
          )
          runner = ReplRunner.new(
            parser: parser,
            executer: executer,
            command_handler: command_handler,
            io: { out: @out, err: @err }
          )
          runner.run
        end

        0
      end
    end
  end
end
