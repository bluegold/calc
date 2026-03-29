require "bigdecimal"

module Calc
  module Functions
    # This module registers built-in mathematical functions for the Calc interpreter.
    # It includes functions for exponentiation and square roots.
    module Math
      # Registers all mathematical functions with the Builtins registry.
      #
      # @param builtins [Builtins] The Builtins instance to register functions with.
      def self.register(builtins)
        # Raises a base number to an exponent: `(pow 2 3)` calculates 2^3.
        Functions.register(builtins, "pow", min_arity: 2, max_arity: 2) do |args|
          base, exponent = args
          base**exponent
        end

        # Returns absolute value: `(abs -3)` returns 3.
        Functions.register(builtins, "abs", min_arity: 1, max_arity: 1) do |args|
          args.first.abs
        end

        # Returns modulo remainder: `(mod 10 3)` returns 1.
        Functions.register(builtins, "mod", min_arity: 2, max_arity: 2) do |args|
          dividend, divisor = args
          raise DivisionByZeroError, "division by zero" if divisor.zero?

          dividend % divisor
        end

        # Returns the largest integer not greater than the value.
        Functions.register(builtins, "floor", min_arity: 1, max_arity: 1) do |args|
          BigDecimal(args.first.floor.to_s)
        end

        # Returns the smallest integer not less than the value.
        Functions.register(builtins, "ceil", min_arity: 1, max_arity: 1) do |args|
          BigDecimal(args.first.ceil.to_s)
        end

        # Rounds to the nearest integer using Ruby BigDecimal rounding rules.
        Functions.register(builtins, "round", min_arity: 1, max_arity: 1) do |args|
          BigDecimal(args.first.round.to_s)
        end

        # Calculates the square root of a number: `(sqrt 9)` returns 3.
        # The precision of the result is determined based on the input value.
        Functions.register(builtins, "sqrt", min_arity: 1, max_arity: 1) do |args|
          value = args.first
          precision = [value.precision + 10, 16].max
          value.sqrt(precision)
        end
      end
    end
  end
end
