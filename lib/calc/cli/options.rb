module Calc
  module Cli
    module Options
      Result = Struct.new(:subcommand, :print_last_result, :trace_vm, :script_path, :remaining_args, :output_path)
      SUBCOMMANDS = %w[test bytecode compile].freeze

      class InvalidOptionError < StandardError
        attr_reader :option

        def initialize(option)
          @option = option
          super("unknown option: #{option}")
        end
      end

      class MissingOptionValueError < StandardError
        def initialize(option)
          super("missing value for option: #{option}")
        end
      end

      module_function

      # Parses argv into a normalized option/result object.
      def parse(argv)
        args = argv.dup
        subcommand = args.shift if SUBCOMMANDS.include?(args.first)

        print_last_result = false
        trace_vm = false
        script_path = nil
        remaining_args = []
        output_path = nil

        index = 0
        while index < args.length
          arg = args[index]
          case arg
          when "--print-last-result"
            print_last_result = true
          when "--trace-vm"
            trace_vm = true
          when "--output"
            value = args[index + 1]
            raise MissingOptionValueError, "--output" if value.nil? || value.start_with?("-")

            output_path = value
            index += 1
          when /^-/
            raise InvalidOptionError, arg
          else
            if subcommand == "test"
              remaining_args << arg
            else
              script_path ||= arg
            end
          end
          index += 1
        end

        Result.new(
          subcommand: subcommand,
          print_last_result: print_last_result,
          trace_vm: trace_vm,
          script_path: script_path,
          remaining_args: remaining_args,
          output_path: output_path
        )
      end
    end
  end
end
