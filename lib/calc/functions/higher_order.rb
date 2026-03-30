module Calc
  module Functions
    # This module registers higher-order functions that operate on collections
    # and can take other functions as arguments.
    module HigherOrder
      # Registers all higher-order functions with the Builtins registry.
      #
      # @param builtins [Builtins] The Builtins instance to register functions with.
      def self.register(builtins)
        # Applies a function to each item in a list, returning a new list of results:
        # `(map (lambda (x) (+ x 1)) (list 1 2 3))`
        Functions.register(builtins, "map", min_arity: 2, max_arity: 2) do |args, &block|
          callable, collection = args
          list = builtins.normalize_iterable(collection, "map")
          raise Calc::NameError, "map expects a function" unless block

          list.map { |item| block.call(callable, [item]) }
        end

        # Reduces a list to a single value by applying a function cumulatively:
        # `(reduce (lambda (memo x) (+ memo x)) 0 (list 1 2 3))`
        Functions.register(builtins, "reduce", min_arity: 3, max_arity: 3) do |args, &block|
          callable, memo, collection = args
          list = builtins.normalize_iterable(collection, "reduce")
          raise Calc::NameError, "reduce expects a function" unless block

          list.reduce(memo) { |accumulator, item| block.call(callable, [accumulator, item]) }
        end

        # Selects items from a list that satisfy a given predicate function:
        # `(select (lambda (x) (> x 1)) (list 1 2 3))`
        Functions.register(builtins, "select", min_arity: 2, max_arity: 2) do |args, &block|
          callable, collection = args
          list = builtins.normalize_iterable(collection, "select")
          raise Calc::NameError, "select expects a function" unless block

          list.select { |item| builtins.truthy?(block.call(callable, [item])) }
        end

        Functions.register_alias(builtins, "collect", "map")
        Functions.register_alias(builtins, "fold", "reduce")
        Functions.register_alias(builtins, "filter", "select")
      end
    end
  end
end
