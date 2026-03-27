require "bigdecimal"

module Calc
  module Functions
    module Math
      def self.register(builtins)
        builtins.register("pow", min_arity: 2, max_arity: 2, description: "Raise a number to a power",
                                 example: "(pow 2 3)") do |args|
          base, exponent = args
          base**exponent
        end

        builtins.register("sqrt", min_arity: 1, max_arity: 1, description: "Square root", example: "(sqrt 9)") do |args|
          value = args.first
          precision = [value.precision + 10, 16].max
          value.sqrt(precision)
        end
      end
    end
  end
end
