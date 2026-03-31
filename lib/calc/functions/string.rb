module Calc
  module Functions
    # This module registers built-in string manipulation functions for the Calc interpreter.
    # It includes concatenation, reversal, splitting, and joining operations.
    module Strings
      # Registers all string functions with the Builtins registry.
      #
      # @param builtins [Builtins] The Builtins instance to register functions with.
      def self.register(builtins)
        register_concat(builtins)
        register_reverse(builtins)
        register_split(builtins)
        register_join(builtins)
      end

      def self.register_concat(builtins)
        # String concatenation: `(concat "a" "b" 10)`
        Functions.register(builtins, "concat", min_arity: 0) do |args|
          args.map { |value| Calc.format_value(value) }.join
        end
      end

      def self.register_reverse(builtins)
        # Reverse list items or string characters: `(reverse (list 1 2 3))`
        Functions.register(builtins, "reverse", min_arity: 1, max_arity: 1) do |args|
          value = args.first
          raise Calc::RuntimeError, "reverse expects a list or string" unless value.is_a?(Array) || value.is_a?(String)

          value.reverse
        end
      end

      def self.register_split(builtins)
        # Split a string into characters or by a given separator: `(split "a,b" ",")`
        Functions.register(builtins, "split", min_arity: 1, max_arity: 2) do |args|
          source = args[0]
          raise Calc::RuntimeError, "split expects a string" unless source.is_a?(String)

          if args.length == 1
            source.chars
          else
            separator = args[1]
            raise Calc::RuntimeError, "split separator expects a string" unless separator.is_a?(String)

            source.split(separator)
          end
        end
      end

      def self.register_join(builtins)
        # Join list items into a string using an optional separator: `(join (list "a" "b") "-")`
        Functions.register(builtins, "join", min_arity: 1, max_arity: 2) do |args|
          list = args[0]
          raise Calc::RuntimeError, "join expects a list" unless list.is_a?(Array)

          separator = args.length == 2 ? args[1] : ""
          raise Calc::RuntimeError, "join separator expects a string" unless separator.is_a?(String)

          list.join(separator)
        end
      end

      private_class_method :register_concat, :register_reverse, :register_split, :register_join
    end
  end
end
