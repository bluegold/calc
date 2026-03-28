module Calc
  module Functions
    module Testing
      def self.register(builtins)
        Functions.register(
          builtins,
          "fail",
          min_arity: 0,
          max_arity: 1,
          type: "testing",
          description: "Raise a test failure",
          example: "(fail \"expected 2, got 3\")"
        ) do |args|
          message = args.first || "test failed"
          raise Calc::RuntimeError, message.to_s
        end

        Functions.register(
          builtins,
          "assert-equal",
          min_arity: 2,
          max_arity: 3,
          type: "testing",
          description: "Assert that two values are equal",
          example: "(assert-equal 2 (+ 1 1))"
        ) do |args|
          expected, actual, message = args

          next true if expected == actual

          error_message = message ? message.to_s : "expected #{Calc.format_value(expected)}, got #{Calc.format_value(actual)}"
          raise Calc::RuntimeError, error_message
        end

        Functions.register(
          builtins,
          "assert-true",
          min_arity: 1,
          max_arity: 2,
          type: "testing",
          description: "Assert that a value is truthy",
          example: "(assert-true (> 2 1))"
        ) do |args|
          value, message = args

          next true if builtins.truthy?(value)

          error_message = message ? message.to_s : "expected truthy value, got #{Calc.format_value(value)}"
          raise Calc::RuntimeError, error_message
        end

        Functions.register(
          builtins,
          "assert-false",
          min_arity: 1,
          max_arity: 2,
          type: "testing",
          description: "Assert that a value is falsey",
          example: "(assert-false false)"
        ) do |args|
          value, message = args

          next true unless builtins.truthy?(value)

          error_message = message ? message.to_s : "expected falsey value, got #{Calc.format_value(value)}"
          raise Calc::RuntimeError, error_message
        end
      end
    end
  end
end
