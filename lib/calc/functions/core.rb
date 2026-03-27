require "bigdecimal"

module Calc
  module Functions
    module Core
      def self.register(builtins)
        Functions.register(builtins, "+", min_arity: 0) do |args|
          args.reduce(BigDecimal("0"), :+)
        end

        Functions.register(builtins, "-", min_arity: 1) do |args|
          if args.length == 1
            -args.first
          else
            args.reduce { |memo, value| memo - value }
          end
        end

        Functions.register(builtins, "*", min_arity: 0) do |args|
          args.reduce(BigDecimal("1"), :*)
        end

        Functions.register(builtins, "/", min_arity: 1) do |args|
          args.reduce do |memo, value|
            raise DivisionByZeroError, "division by zero" if value.zero?

            memo / value
          end
        end

        Functions.register(builtins, "<", min_arity: 2, max_arity: 2) do |args|
          args[0] < args[1]
        end
        Functions.register(builtins, "<=", min_arity: 2, max_arity: 2) do |args|
          args[0] <= args[1]
        end
        Functions.register(builtins, ">", min_arity: 2, max_arity: 2) do |args|
          args[0] > args[1]
        end
        Functions.register(builtins, ">=", min_arity: 2, max_arity: 2) do |args|
          args[0] >= args[1]
        end
        Functions.register(builtins, "==", min_arity: 2, max_arity: 2) do |args|
          args[0] == args[1]
        end
        Functions.register(builtins, "!=", min_arity: 2, max_arity: 2) do |args|
          args[0] != args[1]
        end

        Functions.register(builtins, "concat", min_arity: 0, &:join)
        Functions.register(builtins, "length", min_arity: 1, max_arity: 1) do |args|
          args.first.to_s.length
        end

        Functions.register(builtins, "print", min_arity: 0) do |args|
          args.each { |value| $stdout.puts Calc.format_value(value) }
          nil
        end

        Functions.register(builtins, "list", min_arity: 0) { |args| args }
      end
    end
  end
end
