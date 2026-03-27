module Calc
  module Functions
    module Dictionary
      HASH_EXAMPLE = "(hash :name \"taro\" :age 20)".freeze
      GET_EXAMPLE = "(get user :name)".freeze
      SET_EXAMPLE = "(set user :name \"taro\")".freeze
      ENTRIES_EXAMPLE = "(entries user)".freeze
      KEYS_EXAMPLE = "(keys user)".freeze
      VALUES_EXAMPLE = "(values user)".freeze
      HAS_EXAMPLE = "(has? user :name)".freeze
      DIG_EXAMPLE = "(dig payload :items 0 :name)".freeze
      HASH_FROM_PAIRS_EXAMPLE = "(hash-from-pairs (list (list :name \"taro\")))".freeze
      PARSE_JSON_EXAMPLE = "(parse-json \"{\\\"name\\\":\\\"taro\\\"}\")".freeze
      STRINGIFY_JSON_EXAMPLE = "(stringify-json (hash :name \"taro\"))".freeze

      def self.register(builtins)
        register_basic_accessors(builtins)
        register_lookup_helpers(builtins)
        register_transform_helpers(builtins)
        register_json_helpers(builtins)
      end

      def self.register_basic_accessors(builtins)
        builtins.register("hash", min_arity: 0, description: "Create a hash", example: HASH_EXAMPLE) do |args|
          raise Calc::RuntimeError, "hash expects key/value pairs" if args.length.odd?

          args.each_slice(2).with_object({}) do |(key, value), result|
            result[builtins.send(:normalize_hash_key, key)] = value
          end
        end

        builtins.register("get", min_arity: 2, max_arity: 2, description: "Read a value from a list or hash",
                                 example: GET_EXAMPLE) do |args|
          container, key = args
          builtins.send(:get_value, container, key)
        end

        builtins.register("set", min_arity: 3, max_arity: 3, description: "Return a new list or hash with an updated value",
                                 example: SET_EXAMPLE) do |args|
          container, key, value = args
          builtins.send(:set_value, container, key, value)
        end
      end

      def self.register_lookup_helpers(builtins)
        builtins.register("entries", min_arity: 1, max_arity: 1, description: "Return hash entries as [key, value] pairs",
                                     example: ENTRIES_EXAMPLE) do |args|
          container = args.first
          raise Calc::RuntimeError, "entries expects a hash" unless container.is_a?(Hash)

          builtins.send(:entries_from_hash, container)
        end

        builtins.register("keys", min_arity: 1, max_arity: 1, description: "Return hash keys", example: KEYS_EXAMPLE) do |args|
          container = args.first
          raise Calc::RuntimeError, "keys expects a hash" unless container.is_a?(Hash)

          container.keys.map { |key| builtins.send(:keyword_for_key, key) }
        end

        builtins.register("values", min_arity: 1, max_arity: 1, description: "Return hash values",
                                    example: VALUES_EXAMPLE) do |args|
          container = args.first
          raise Calc::RuntimeError, "values expects a hash" unless container.is_a?(Hash)

          container.values
        end

        builtins.register("has?", min_arity: 2, max_arity: 2, description: "Check whether a hash key or list index exists",
                                  example: HAS_EXAMPLE) do |args|
          container, key = args
          builtins.send(:value_exists, container, key)
        end
      end

      def self.register_transform_helpers(builtins)
        builtins.register("dig", min_arity: 2, description: "Traverse nested hash/list values", example: DIG_EXAMPLE) do |args|
          container, *path = args
          builtins.send(:dig_value, container, path)
        end

        builtins.register("hash-from-pairs", min_arity: 1, max_arity: 1, description: "Build hash from [key, value] pairs",
                                             example: HASH_FROM_PAIRS_EXAMPLE) do |args|
          pairs = args.first
          raise Calc::RuntimeError, "hash-from-pairs expects a list" unless pairs.is_a?(Array)

          pairs.each_with_object({}) do |pair, result|
            raise Calc::RuntimeError, "hash-from-pairs expects [key, value] pairs" unless pair.is_a?(Array) && pair.length == 2

            key, value = pair
            result[builtins.send(:normalize_hash_key, key)] = value
          end
        end
      end

      def self.register_json_helpers(builtins)
        builtins.register("parse-json", min_arity: 1, max_arity: 1, description: "Parse JSON into Calc values",
                                        example: PARSE_JSON_EXAMPLE) do |args|
          builtins.send(:parse_json_value, args.first)
        end

        builtins.register("stringify-json", min_arity: 1, max_arity: 1, description: "Convert Calc values to JSON",
                                            example: STRINGIFY_JSON_EXAMPLE) do |args|
          JSON.generate(builtins.send(:jsonify_value, args.first))
        end
      end
    end
  end
end
