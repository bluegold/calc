require "bigdecimal"

module Calc
  module Functions
    module Sqrt
      def self.register(builtins)
        builtins.register("sqrt", min_arity: 1, max_arity: 1) do |args|
          value = args.first
          precision = [value.precision + 10, 16].max
          value.sqrt(precision)
        end
      end
    end
  end
end
