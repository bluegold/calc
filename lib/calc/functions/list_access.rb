module Calc
  module Functions
    module ListAccess
      def self.register(builtins)
        Functions.register(builtins, "cons", min_arity: 2, max_arity: 2) do |args|
          value, list = args
          raise Calc::RuntimeError, "cons expects a list" unless list.is_a?(Array)

          [value, *list]
        end

        Functions.register(builtins, "append", min_arity: 2, max_arity: 2) do |args|
          list, value = args
          raise Calc::RuntimeError, "append expects a list" unless list.is_a?(Array)

          [*list, value]
        end

        Functions.register(builtins, "concat-list", min_arity: 2, max_arity: 2) do |args|
          left, right = args
          raise Calc::RuntimeError, "concat-list expects lists" unless left.is_a?(Array) && right.is_a?(Array)

          [*left, *right]
        end

        Functions.register(builtins, "nth", min_arity: 2, max_arity: 2) do |args|
          index, list = args
          raise Calc::RuntimeError, "nth expects a list" unless list.is_a?(Array)

          normalized_index = builtins.send(:normalize_index, index)
          next nil if normalized_index.nil? || normalized_index.negative? || normalized_index >= list.length

          list[normalized_index]
        end

        Functions.register(builtins, "first", min_arity: 1, max_arity: 1) do |args|
          list = args.first
          raise Calc::RuntimeError, "first expects a list" unless list.is_a?(Array)

          list.first
        end

        Functions.register(builtins, "rest", min_arity: 1, max_arity: 1) do |args|
          list = args.first
          raise Calc::RuntimeError, "rest expects a list" unless list.is_a?(Array)

          list.drop(1)
        end
      end
    end
  end
end
