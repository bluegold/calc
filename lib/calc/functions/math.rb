require "bigdecimal"

module Calc
  module Functions
    module Math
      def self.register(builtins)
        Functions.register(builtins, "pow", min_arity: 2, max_arity: 2) do |args|
          base, exponent = args
          base**exponent
        end

        Functions.register(builtins, "sqrt", min_arity: 1, max_arity: 1) do |args|
          value = args.first
          precision = [value.precision + 10, 16].max
          value.sqrt(precision)
        end
      end
    end
  end
end
