module Calc
  module Functions
    # Module responsible for categorizing built-in functions by type.
    # This categorization can be used for documentation, filtering, or type checking.
    module Types
      # A hash mapping built-in function names to their functional categories (e.g., "arithmetic", "list", " "hash").
      # This map defines the high-level type or domain of each function.
      MAP = {
        "+" => "arithmetic",
        "-" => "arithmetic",
        "*" => "arithmetic",
        "/" => "arithmetic",
        "<" => "comparison",
        "<=" => "comparison",
        ">" => "comparison",
        ">=" => "comparison",
        "==" => "comparison",
        "!=" => "comparison",
        "concat" => "string",
        "length" => "string",
        "print" => "io",
        "list" => "list",
        "hash" => "hash",
        "get" => "hash",
        "set" => "hash",
        "entries" => "hash",
        "keys" => "hash",
        "values" => "hash",
        "has?" => "hash",
        "dig" => "hash",
        "hash-from-pairs" => "hash",
        "parse-json" => "json",
        "stringify-json" => "json",
        "cons" => "list",
        "append" => "list",
        "concat-list" => "list",
        "nth" => "list",
        "first" => "list",
        "rest" => "list",
        "map" => "higher-order",
        "reduce" => "higher-order",
        "fold" => "higher-order",
        "select" => "higher-order",
        "pow" => "math",
        "abs" => "math",
        "mod" => "math",
        "floor" => "math",
        "ceil" => "math",
        "round" => "math",
        "sqrt" => "math",
        "current-time" => "time",
        "parse-time" => "time",
        "format-time" => "time",
        "next-month" => "time",
        "prev-month" => "time",
        "beggining-of-month" => "time",
        "end-of-month" => "time"
      }.freeze

      # Retrieves the functional category for a given built-in function name.
      #
      # @param name [String] The name of the function.
      # @return [String] The functional category of the function.
      # @raise [KeyError] If no type is defined for the given function name.
      def self.fetch(name)
        MAP.fetch(name)
      end
    end
  end
end
