module Calc
  module Functions
    # This module registers higher-order functions that operate on collections
    # and can take other functions as arguments.
    module HigherOrder
      # Registers all higher-order functions with the Builtins registry.
      #
      # @param builtins [Builtins] The Builtins instance to register functions with.
      def self.register(builtins)
        register_map(builtins)
        register_reduce(builtins)
        register_select(builtins)
        register_find(builtins)
        register_predicates(builtins)
        register_flat_map(builtins)
        register_count(builtins)
        register_aliases(builtins)
      end

      def self.register_map(builtins)
        # Applies a function to each item in a list, returning a new list of results:
        # `(map (lambda (x) (+ x 1)) (list 1 2 3))`
        Functions.register(builtins, "map", min_arity: 2, max_arity: 2) do |args, &block|
          callable, collection = args
          list = builtins.normalize_iterable(collection, "map")
          raise Calc::NameError, "map expects a function" unless block

          list.map { |item| block.call(callable, [item]) }
        end
      end

      def self.register_reduce(builtins)
        # Reduces a list to a single value by applying a function cumulatively:
        # `(reduce (lambda (memo x) (+ memo x)) 0 (list 1 2 3))`
        Functions.register(builtins, "reduce", min_arity: 3, max_arity: 3) do |args, &block|
          callable, memo, collection = args
          list = builtins.normalize_iterable(collection, "reduce")
          raise Calc::NameError, "reduce expects a function" unless block

          list.reduce(memo) { |accumulator, item| block.call(callable, [accumulator, item]) }
        end
      end

      def self.register_select(builtins)
        # Selects items from a list that satisfy a given predicate function:
        # `(select (lambda (x) (> x 1)) (list 1 2 3))`
        Functions.register(builtins, "select", min_arity: 2, max_arity: 2) do |args, &block|
          callable, collection = args
          list = builtins.normalize_iterable(collection, "select")
          raise Calc::NameError, "select expects a function" unless block

          list.select { |item| builtins.truthy?(block.call(callable, [item])) }
        end
      end

      def self.register_find(builtins)
        Functions.register(builtins, "find", min_arity: 2, max_arity: 2) do |args, &block|
          callable, collection = args
          list = builtins.normalize_iterable(collection, "find")
          raise Calc::NameError, "find expects a function" unless block

          list.find { |item| builtins.truthy?(block.call(callable, [item])) }
        end
      end

      def self.register_predicates(builtins)
        Functions.register(builtins, "any?", min_arity: 2, max_arity: 2) do |args, &block|
          callable, collection = args
          list = builtins.normalize_iterable(collection, "any?")
          raise Calc::NameError, "any? expects a function" unless block

          list.any? { |item| builtins.truthy?(block.call(callable, [item])) }
        end

        Functions.register(builtins, "all?", min_arity: 2, max_arity: 2) do |args, &block|
          callable, collection = args
          list = builtins.normalize_iterable(collection, "all?")
          raise Calc::NameError, "all? expects a function" unless block

          list.all? { |item| builtins.truthy?(block.call(callable, [item])) }
        end

        Functions.register(builtins, "none?", min_arity: 2, max_arity: 2) do |args, &block|
          callable, collection = args
          list = builtins.normalize_iterable(collection, "none?")
          raise Calc::NameError, "none? expects a function" unless block

          list.none? { |item| builtins.truthy?(block.call(callable, [item])) }
        end
      end

      def self.register_flat_map(builtins)
        Functions.register(builtins, "flat-map", min_arity: 2, max_arity: 2) do |args, &block|
          callable, collection = args
          list = builtins.normalize_iterable(collection, "flat-map")
          raise Calc::NameError, "flat-map expects a function" unless block

          list.flat_map do |item|
            mapped = block.call(callable, [item])
            mapped.is_a?(Array) ? mapped : [mapped]
          end
        end
      end

      def self.register_count(builtins)
        Functions.register(builtins, "count", min_arity: 1, max_arity: 2) do |args, &block|
          if args.length == 1
            collection = args.first
            list = builtins.normalize_iterable(collection, "count")
            next BigDecimal(list.length.to_s)
          end

          callable, collection = args
          list = builtins.normalize_iterable(collection, "count")
          raise Calc::NameError, "count expects a function when called with two arguments" unless block

          matched = list.count { |item| builtins.truthy?(block.call(callable, [item])) }
          BigDecimal(matched.to_s)
        end
      end

      def self.register_aliases(builtins)
        Functions.register_alias(builtins, "collect", "map")
        Functions.register_alias(builtins, "fold", "reduce")
        Functions.register_alias(builtins, "filter", "select")
      end

      private_class_method :register_map,
                           :register_reduce,
                           :register_select,
                           :register_find,
                           :register_predicates,
                           :register_flat_map,
                           :register_count,
                           :register_aliases
    end
  end
end
