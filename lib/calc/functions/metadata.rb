require_relative "types"

module Calc
  module Functions
    # Module responsible for storing and retrieving metadata about built-in functions.
    # This metadata includes descriptions, example usage, and type information,
    # which can be used for documentation, help systems, or static analysis.
    module Metadata
      # A hash containing metadata definitions for various built-in functions.
      # Each key is a function name (String), and its value is a hash
      # containing `:description` and `:example` keys. Type information is
      # merged dynamically from the `Types` module.
      DEFINITIONS = {
        "+" => { description: "Add numbers", example: "(+ 1 2 3)" },
        "-" => { description: "Subtract numbers", example: "(- 5 2)" },
        "*" => { description: "Multiply numbers", example: "(* 2 3 4)" },
        "/" => { description: "Divide numbers", example: "(/ 8 2)" },
        "<" => { description: "Less than", example: "(< 1 2)" },
        "<=" => { description: "Less than or equal", example: "(<= 1 2)" },
        ">" => { description: "Greater than", example: "(> 2 1)" },
        ">=" => { description: "Greater than or equal", example: "(>= 2 1)" },
        "==" => { description: "Equal", example: "(== 1 1)" },
        "!=" => { description: "Not equal", example: "(!= 1 2)" },
        "not" => { description: "Logical negation", example: "(not true)" },
        "concat" => { description: "Concatenate strings", example: "(concat \"a\" \"b\")" },
        "length" => { description: "String length", example: "(length \"calc\")" },
        "print" => { description: "Print values", example: "(print \"hello\" 1)" },
        "list" => { description: "Create a list", example: "(list 1 2 3)" },
        "hash" => { description: "Create a hash", example: "(hash :name \"taro\" :age 20)" },
        "get" => { description: "Read a value from a list or hash", example: "(get user :name)" },
        "set" => { description: "Return a new list or hash with an updated value", example: "(set user :name \"taro\")" },
        "entries" => { description: "Return hash entries as [key, value] pairs", example: "(entries user)" },
        "keys" => { description: "Return hash keys", example: "(keys user)" },
        "values" => { description: "Return hash values", example: "(values user)" },
        "has?" => { description: "Check whether a hash key or list index exists", example: "(has? user :name)" },
        "dig" => { description: "Traverse nested hash/list values", example: "(dig payload :items 0 :name)" },
        "hash-from-pairs" => {
          description: "Build hash from [key, value] pairs",
          example: "(hash-from-pairs (list (list :name \"taro\")))"
        },
        "parse-json" => {
          description: "Parse JSON into Calc values",
          example: "(parse-json \"{\\\"name\\\":\\\"taro\\\"}\")"
        },
        "stringify-json" => {
          description: "Convert Calc values to JSON",
          example: "(stringify-json (hash :name \"taro\"))"
        },
        "cons" => { description: "Prepend an item to a list", example: "(cons 1 (list 2 3))" },
        "append" => { description: "Append an item to a list", example: "(append (list 1 2) 3)" },
        "concat-list" => { description: "Concatenate two lists", example: "(concat-list (list 1) (list 2 3))" },
        "nth" => { description: "Return list item at index", example: "(nth 0 (list 1 2 3))" },
        "first" => { description: "Return first item from list", example: "(first (list 1 2 3))" },
        "rest" => { description: "Return list without first item", example: "(rest (list 1 2 3))" },
        "map" => {
          description: "Map a function over a list",
          example: "(map (lambda (x) (+ x 1)) (list 1 2 3))"
        },
        "reduce" => {
          description: "Reduce a list with a function",
          example: "(reduce (lambda (memo x) (+ memo x)) 0 (list 1 2 3))"
        },
        "fold" => {
          description: "Fold a list with a function and seed",
          example: "(fold (lambda (memo x) (+ memo x)) 0 (list 1 2 3))"
        },
        "select" => {
          description: "Select items with a predicate",
          example: "(select (lambda (x) (> x 1)) (list 1 2 3))"
        },
        "pow" => { description: "Raise a number to a power", example: "(pow 2 3)" },
        "abs" => { description: "Absolute value", example: "(abs -3.5)" },
        "mod" => { description: "Modulo remainder", example: "(mod 10 3)" },
        "floor" => { description: "Round down to integer", example: "(floor 3.9)" },
        "ceil" => { description: "Round up to integer", example: "(ceil 3.1)" },
        "round" => { description: "Round to nearest integer", example: "(round 3.6)" },
        "sqrt" => { description: "Square root", example: "(sqrt 9)" },
        "current-time" => { description: "Return current time as epoch microseconds", example: "(current-time)" },
        "parse-time" => {
          description: "Parse a time string into epoch microseconds",
          example: "(parse-time \"2026-03-27T12:34:56Z\")"
        },
        "format-time" => {
          description: "Format epoch microseconds as a time string",
          example: "(format-time (current-time) \"%Y-%m-%d\")"
        },
        "next-month" => { description: "Shift epoch microseconds by one month forward", example: "(next-month (current-time))" },
        "prev-month" => { description: "Shift epoch microseconds by one month backward", example: "(prev-month (current-time))" },
        "beggining-of-month" => {
          description: "Return start of month for epoch microseconds",
          example: "(beggining-of-month (current-time))"
        },
        "end-of-month" => { description: "Return end of month for epoch microseconds", example: "(end-of-month (current-time))" }
      }.freeze

      # Retrieves the complete metadata for a given function name.
      # This includes description, example, and dynamically merged type information.
      #
      # @param name [String] The name of the function.
      # @return [Hash] A hash containing all available metadata for the function.
      # @raise [KeyError] If no definition exists for the given function name.
      def self.fetch(name)
        definition = DEFINITIONS.fetch(name)
        type = Types.fetch(name)

        definition.merge(type: type)
      end
    end
  end
end
