module Calc
  module Functions
    module HigherOrder
      def self.register(builtins)
        builtins.register("map", min_arity: 2, max_arity: 2, description: "Map a function over a list",
                                 example: "(map (lambda (x) (+ x 1)) (list 1 2 3))") do |args, &block|
          callable, collection = args
          list = builtins.send(:normalize_iterable, collection, "map")
          raise Calc::NameError, "map expects a function" unless block

          list.map { |item| block.call(callable, [item]) }
        end

        builtins.register("reduce", min_arity: 3, max_arity: 3, description: "Reduce a list with a function",
                                    example: "(reduce (lambda (memo x) (+ memo x)) 0 (list 1 2 3))") do |args, &block|
          callable, memo, collection = args
          list = builtins.send(:normalize_iterable, collection, "reduce")
          raise Calc::NameError, "reduce expects a function" unless block

          list.reduce(memo) { |accumulator, item| block.call(callable, [accumulator, item]) }
        end

        builtins.register("select", min_arity: 2, max_arity: 2, description: "Select items with a predicate",
                                    example: "(select (lambda (x) (> x 1)) (list 1 2 3))") do |args, &block|
          callable, collection = args
          list = builtins.send(:normalize_iterable, collection, "select")
          raise Calc::NameError, "select expects a function" unless block

          list.select { |item| builtins.truthy?(block.call(callable, [item])) }
        end
      end
    end
  end
end
