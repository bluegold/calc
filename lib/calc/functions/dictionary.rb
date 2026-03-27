module Calc
  module Functions
    module Dictionary
      def self.register(builtins)
        register_basic_accessors(builtins)
        register_lookup_helpers(builtins)
        register_transform_helpers(builtins)
        register_json_helpers(builtins)
      end

      def self.register_basic_accessors(builtins)
        Functions.register(builtins, "hash", min_arity: 0) do |args|
          raise Calc::RuntimeError, "hash expects key/value pairs" if args.length.odd?

          args.each_slice(2).with_object({}) do |(key, value), result|
            result[builtins.send(:normalize_hash_key, key)] = value
          end
        end

        Functions.register(builtins, "get", min_arity: 2, max_arity: 2) do |args|
          container, key = args
          builtins.send(:get_value, container, key)
        end

        Functions.register(builtins, "set", min_arity: 3, max_arity: 3) do |args|
          container, key, value = args
          builtins.send(:set_value, container, key, value)
        end
      end

      def self.register_lookup_helpers(builtins)
        Functions.register(builtins, "entries", min_arity: 1, max_arity: 1) do |args|
          container = args.first
          raise Calc::RuntimeError, "entries expects a hash" unless container.is_a?(Hash)

          builtins.send(:entries_from_hash, container)
        end

        Functions.register(builtins, "keys", min_arity: 1, max_arity: 1) do |args|
          container = args.first
          raise Calc::RuntimeError, "keys expects a hash" unless container.is_a?(Hash)

          container.keys.map { |key| builtins.send(:keyword_for_key, key) }
        end

        Functions.register(builtins, "values", min_arity: 1, max_arity: 1) do |args|
          container = args.first
          raise Calc::RuntimeError, "values expects a hash" unless container.is_a?(Hash)

          container.values
        end

        Functions.register(builtins, "has?", min_arity: 2, max_arity: 2) do |args|
          container, key = args
          builtins.send(:value_exists, container, key)
        end
      end

      def self.register_transform_helpers(builtins)
        Functions.register(builtins, "dig", min_arity: 2) do |args|
          container, *path = args
          builtins.send(:dig_value, container, path)
        end

        Functions.register(builtins, "hash-from-pairs", min_arity: 1, max_arity: 1) do |args|
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
        Functions.register(builtins, "parse-json", min_arity: 1, max_arity: 1) do |args|
          builtins.send(:parse_json_value, args.first)
        end

        Functions.register(builtins, "stringify-json", min_arity: 1, max_arity: 1) do |args|
          JSON.generate(builtins.send(:jsonify_value, args.first))
        end
      end
    end
  end
end
