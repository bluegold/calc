module Calc
  module Functions
    module HigherOrder
      def self.register(builtins)
        Functions.register(builtins, "map", min_arity: 2, max_arity: 2) do |args, &block|
          callable, collection = args
          list = builtins.send(:normalize_iterable, collection, "map")
          raise Calc::NameError, "map expects a function" unless block

          list.map { |item| block.call(callable, [item]) }
        end

        Functions.register(builtins, "reduce", min_arity: 3, max_arity: 3) do |args, &block|
          callable, memo, collection = args
          list = builtins.send(:normalize_iterable, collection, "reduce")
          raise Calc::NameError, "reduce expects a function" unless block

          list.reduce(memo) { |accumulator, item| block.call(callable, [accumulator, item]) }
        end

        Functions.register(builtins, "fold", min_arity: 3, max_arity: 3) do |args, &block|
          callable, memo, collection = args
          list = builtins.send(:normalize_iterable, collection, "fold")
          raise Calc::NameError, "fold expects a function" unless block

          list.reduce(memo) { |accumulator, item| block.call(callable, [accumulator, item]) }
        end

        Functions.register(builtins, "select", min_arity: 2, max_arity: 2) do |args, &block|
          callable, collection = args
          list = builtins.send(:normalize_iterable, collection, "select")
          raise Calc::NameError, "select expects a function" unless block

          list.select { |item| builtins.truthy?(block.call(callable, [item])) }
        end
      end
    end
  end
end
