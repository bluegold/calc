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
