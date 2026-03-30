module Calc
  module Functions
    # This module registers built-in functions for manipulating and accessing lists.
    # It includes functions for adding elements, concatenating lists, and retrieving
    # specific elements or sub-lists.
    module ListAccess
      # Registers all list access and manipulation functions with the Builtins registry.
      #
      # @param builtins [Builtins] The Builtins instance to register functions with.
      def self.register(builtins)
        # Prepends a value to the beginning of a list: `(cons 1 (list 2 3))`
        Functions.register(builtins, "cons", min_arity: 2, max_arity: 2) do |args|
          value, list = args
          raise Calc::RuntimeError, "cons expects a list" unless list.is_a?(Array)

          [value, *list]
        end

        # Appends a value to the end of a list: `(append (list 1 2) 3)`
        Functions.register(builtins, "append", min_arity: 2, max_arity: 2) do |args|
          list, value = args
          raise Calc::RuntimeError, "append expects a list" unless list.is_a?(Array)

          [*list, value]
        end

        # Concatenates two lists into a new single list: `(concat-list (list 1) (list 2 3))`
        Functions.register(builtins, "concat-list", min_arity: 2, max_arity: 2) do |args|
          left, right = args
          raise Calc::RuntimeError, "concat-list expects lists" unless left.is_a?(Array) && right.is_a?(Array)

          [*left, *right]
        end

        # Retrieves the element at a specific index from a list: `(nth 0 (list 1 2 3))`
        Functions.register(builtins, "nth", min_arity: 2, max_arity: 2) do |args|
          index, list = args
          raise Calc::RuntimeError, "nth expects a list" unless list.is_a?(Array)

          normalized_index = builtins.normalize_index(index)
          next nil if normalized_index.nil? || normalized_index.negative? || normalized_index >= list.length

          list[normalized_index]
        end

        # Returns the first element of a list: `(first (list 1 2 3))`
        Functions.register(builtins, "first", min_arity: 1, max_arity: 1) do |args|
          list = args.first
          raise Calc::RuntimeError, "first expects a list" unless list.is_a?(Array)

          list.first
        end

        # Returns a new list containing all elements except the first: `(rest (list 1 2 3))`
        Functions.register(builtins, "rest", min_arity: 1, max_arity: 1) do |args|
          list = args.first
          raise Calc::RuntimeError, "rest expects a list" unless list.is_a?(Array)

          list.drop(1)
        end
      end
    end
  end
end
