module Calc
  module Functions
    module Types
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
        "sqrt" => "math",
        "current-time" => "time",
        "parse-time" => "time",
        "format-time" => "time",
        "next-month" => "time",
        "prev-month" => "time",
        "beggining-of-month" => "time",
        "end-of-month" => "time"
      }.freeze

      def self.fetch(name)
        MAP.fetch(name)
      end
    end
  end
end
