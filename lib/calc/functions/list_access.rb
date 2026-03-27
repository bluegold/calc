module Calc
  module Functions
    module ListAccess
      NTH_EXAMPLE = "(nth 0 (list 1 2 3))".freeze
      FIRST_EXAMPLE = "(first (list 1 2 3))".freeze
      REST_EXAMPLE = "(rest (list 1 2 3))".freeze

      def self.register(builtins)
        builtins.register("nth", min_arity: 2, max_arity: 2, description: "Return list item at index",
                                 example: NTH_EXAMPLE) do |args|
          index, list = args
          raise Calc::RuntimeError, "nth expects a list" unless list.is_a?(Array)

          normalized_index = builtins.send(:normalize_index, index)
          next nil if normalized_index.nil? || normalized_index.negative? || normalized_index >= list.length

          list[normalized_index]
        end

        builtins.register("first", min_arity: 1, max_arity: 1, description: "Return first item from list",
                                   example: FIRST_EXAMPLE) do |args|
          list = args.first
          raise Calc::RuntimeError, "first expects a list" unless list.is_a?(Array)

          list.first
        end

        builtins.register("rest", min_arity: 1, max_arity: 1, description: "Return list without first item",
                                  example: REST_EXAMPLE) do |args|
          list = args.first
          raise Calc::RuntimeError, "rest expects a list" unless list.is_a?(Array)

          list.drop(1)
        end
      end
    end
  end
end
