require "bigdecimal"

module Calc
  module Functions
    # This module registers core built-in functions for the Calc interpreter.
    # It includes basic arithmetic operations, comparison operators, string manipulation,
    # I/O, and list creation.
    module Core
      # Registers all core functions with the Builtins registry.
      #
      # @param builtins [Builtins] The Builtins instance to register functions with.
      def self.register(builtins)
        # Addition function: `(+)` or `(+ 1 2 3)`
        Functions.register(builtins, "+", min_arity: 0) do |args|
          args.reduce(BigDecimal("0"), :+)
        end

        # Subtraction function: `(- 5)` (negation) or `(- 5 2)`
        Functions.register(builtins, "-", min_arity: 1) do |args|
          if args.length == 1
            -args.first
          else
            args.reduce { |memo, value| memo - value }
          end
        end

        # Multiplication function: `(*)` or `(* 2 3 4)`
        Functions.register(builtins, "*", min_arity: 0) do |args|
          args.reduce(BigDecimal("1"), :*)
        end

        # Division function: `(/ 8 2)` or `(/ 10 2 2)`
        Functions.register(builtins, "/", min_arity: 1) do |args|
          args.reduce do |memo, value|
            raise DivisionByZeroError, "division by zero" if value.zero?

            memo / value
          end
        end

        # Less than comparison: `(< 1 2)`
        Functions.register(builtins, "<", min_arity: 2, max_arity: 2) do |args|
          args[0] < args[1]
        end
        # Less than or equal comparison: `(<= 1 2)`
        Functions.register(builtins, "<=", min_arity: 2, max_arity: 2) do |args|
          args[0] <= args[1]
        end
        # Greater than comparison: `(> 2 1)`
        Functions.register(builtins, ">", min_arity: 2, max_arity: 2) do |args|
          args[0] > args[1]
        end
        # Greater than or equal comparison: `(>= 2 1)`
        Functions.register(builtins, ">=", min_arity: 2, max_arity: 2) do |args|
          args[0] >= args[1]
        end
        # Equality comparison: `(== 1 1)`
        Functions.register(builtins, "==", min_arity: 2, max_arity: 2) do |args|
          args[0] == args[1]
        end
        # Inequality comparison: `(!= 1 2)`
        Functions.register(builtins, "!=", min_arity: 2, max_arity: 2) do |args|
          args[0] != args[1]
        end
        # Logical negation: `(not value)`
        Functions.register(builtins, "not", min_arity: 1, max_arity: 1) do |args|
          value = args.first
          value == false || value.nil?
        end

        # String concatenation: `(concat "a" "b" "c")`
        Functions.register(builtins, "concat", min_arity: 0, &:join)
        # String length: `(length "hello")`
        Functions.register(builtins, "length", min_arity: 1, max_arity: 1) do |args|
          args.first.to_s.length
        end

        # Prints values to standard output: `(print "hello" 1)`
        Functions.register(builtins, "print", min_arity: 0) do |args|
          args.each { |value| $stdout.puts Calc.format_value(value) }
          nil
        end

        # Creates a new list: `(list 1 2 "a")`
        Functions.register(builtins, "list", min_arity: 0) { |args| args }
      end
    end
  end
end
