require "bigdecimal"

module Calc
  module Functions
    module Pow
      def self.register(builtins)
        builtins.register("pow", min_arity: 2, max_arity: 2, description: "Raise a number to a power",
                                 example: "(pow 2 3)") do |args|
          base, exponent = args
          base**exponent
        end
      end
    end
  end
end
