require "bigdecimal"

module Calc
  module Functions
    module Core
      def self.register(builtins)
        builtins.register("+", min_arity: 0, description: "Add numbers", example: "(+ 1 2 3)") do |args|
          args.reduce(BigDecimal("0"), :+)
        end

        builtins.register("-", min_arity: 1, description: "Subtract numbers", example: "(- 5 2)") do |args|
          if args.length == 1
            -args.first
          else
            args.reduce { |memo, value| memo - value }
          end
        end

        builtins.register("*", min_arity: 0, description: "Multiply numbers", example: "(* 2 3 4)") do |args|
          args.reduce(BigDecimal("1"), :*)
        end

        builtins.register("/", min_arity: 1, description: "Divide numbers", example: "(/ 8 2)") do |args|
          args.reduce do |memo, value|
            raise DivisionByZeroError, "division by zero" if value.zero?

            memo / value
          end
        end

        builtins.register("<", min_arity: 2, max_arity: 2, description: "Less than", example: "(< 1 2)") do |args|
          args[0] < args[1]
        end
        builtins.register("<=", min_arity: 2, max_arity: 2, description: "Less than or equal", example: "(<= 1 2)") do |args|
          args[0] <= args[1]
        end
        builtins.register(">", min_arity: 2, max_arity: 2, description: "Greater than", example: "(> 2 1)") do |args|
          args[0] > args[1]
        end
        builtins.register(">=", min_arity: 2, max_arity: 2, description: "Greater than or equal", example: "(>= 2 1)") do |args|
          args[0] >= args[1]
        end
        builtins.register("==", min_arity: 2, max_arity: 2, description: "Equal", example: "(== 1 1)") do |args|
          args[0] == args[1]
        end
        builtins.register("!=", min_arity: 2, max_arity: 2, description: "Not equal", example: "(!= 1 2)") do |args|
          args[0] != args[1]
        end

        builtins.register("concat", min_arity: 0, description: "Concatenate strings", example: "(concat \"a\" \"b\")", &:join)
        builtins.register("length", min_arity: 1, max_arity: 1, description: "String length",
                                    example: "(length \"calc\")") do |args|
          args.first.to_s.length
        end

        builtins.register("print", min_arity: 0, description: "Print values", example: "(print \"hello\" 1)") do |args|
          args.each { |value| $stdout.puts Calc.format_value(value) }
          nil
        end

        builtins.register("list", min_arity: 0, description: "Create a list", example: "(list 1 2 3)") { |args| args }
      end
    end
  end
end
