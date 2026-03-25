require "bigdecimal"

module Calc
  module Functions
    module Sqrt
      def self.register(builtins)
        builtins.register("sqrt", min_arity: 1, max_arity: 1) do |args|
          args.first.sqrt(32)
        end
      end
    end
  end
end
