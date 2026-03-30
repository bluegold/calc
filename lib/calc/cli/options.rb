module Calc
  module Cli
    module Options
      Result = Struct.new(:subcommand, :print_last_result, :trace_vm, :script_path, :remaining_args)
      SUBCOMMANDS = %w[test bytecode].freeze

      class InvalidOptionError < StandardError
        attr_reader :option

        def initialize(option)
          @option = option
          super("unknown option: #{option}")
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

        args.each do |arg|
          case arg
          when "--print-last-result"
            print_last_result = true
          when "--trace-vm"
            trace_vm = true
          when /^-/
            raise InvalidOptionError, arg
          else
            if subcommand == "test"
              remaining_args << arg
            else
              script_path ||= arg
            end
          end
        end

        Result.new(
          subcommand: subcommand,
          print_last_result: print_last_result,
          trace_vm: trace_vm,
          script_path: script_path,
          remaining_args: remaining_args
        )
      end
    end
  end
end
