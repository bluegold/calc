module Calc
  module Functions
    # This module registers built-in functions for dictionary (hash) manipulation.
    # It includes functions for creating hashes, accessing and setting values,
    # retrieving keys/values/entries, and JSON serialization/deserialization.
    module Dictionary
      # Registers all dictionary-related functions with the Builtins registry.
      #
      # @param builtins [Builtins] The Builtins instance to register functions with.
      def self.register(builtins)
        register_basic_accessors(builtins)
        register_lookup_helpers(builtins)
        register_transform_helpers(builtins)
        register_json_helpers(builtins)
      end

      # Registers basic hash creation and access functions.
      #
      # @param builtins [Builtins] The Builtins instance.
      def self.register_basic_accessors(builtins)
        # Creates a hash from key-value pairs: `(hash :name "taro" :age 20)`
        Functions.register(builtins, "hash", min_arity: 0) do |args|
          raise Calc::RuntimeError, "hash expects key/value pairs" if args.length.odd?

          args.each_slice(2).with_object({}) do |(key, value), result|
            result[builtins.normalize_hash_key(key)] = value
          end
        end

        # Retrieves a value from a hash or list: `(get user :name)`
        Functions.register(builtins, "get", min_arity: 2, max_arity: 2) do |args|
          container, key = args
          builtins.get_value(container, key)
        end

        # Returns a new hash or list with an updated value (immutable set): `(set user :name "taro")`
        Functions.register(builtins, "set", min_arity: 3, max_arity: 3) do |args|
          container, key, value = args
          builtins.set_value(container, key, value)
        end
      end

      # Registers functions for looking up hash content.
      #
      # @param builtins [Builtins] The Builtins instance.
      def self.register_lookup_helpers(builtins)
        # Returns hash entries as a list of [key, value] pairs: `(entries user)`
        Functions.register(builtins, "entries", min_arity: 1, max_arity: 1) do |args|
          container = args.first
          raise Calc::RuntimeError, "entries expects a hash" unless container.is_a?(Hash)

          builtins.entries_from_hash(container)
        end

        # Returns a list of all keys in a hash: `(keys user)`
        Functions.register(builtins, "keys", min_arity: 1, max_arity: 1) do |args|
          container = args.first
          raise Calc::RuntimeError, "keys expects a hash" unless container.is_a?(Hash)

          container.keys.map { |key| builtins.keyword_for_key(key) }
        end

        # Returns a list of all values in a hash: `(values user)`
        Functions.register(builtins, "values", min_arity: 1, max_arity: 1) do |args|
          container = args.first
          raise Calc::RuntimeError, "values expects a hash" unless container.is_a?(Hash)

          container.values
        end

        # Checks if a hash contains a key or if a list contains an index: `(has? user :name)`
        Functions.register(builtins, "has?", min_arity: 2, max_arity: 2) do |args|
          container, key = args
          builtins.value_exists(container, key)
        end
      end

      # Registers functions for transforming and traversing hashes.
      #
      # @param builtins [Builtins] The Builtins instance.
      def self.register_transform_helpers(builtins)
        # Traverses nested hashes/lists using a path of keys/indices: `(dig payload :items 0 :name)`
        Functions.register(builtins, "dig", min_arity: 2) do |args|
          container, *path = args
          builtins.dig_value(container, path)
        end

        # Builds a hash from a list of `[key, value]` pairs: `(hash-from-pairs (list (list :name "taro")))`
        Functions.register(builtins, "hash-from-pairs", min_arity: 1, max_arity: 1) do |args|
          pairs = args.first
          raise Calc::RuntimeError, "hash-from-pairs expects a list" unless pairs.is_a?(Array)

          pairs.each_with_object({}) do |pair, result|
            raise Calc::RuntimeError, "hash-from-pairs expects [key, value] pairs" unless pair.is_a?(Array) && pair.length == 2

            key, value = pair
            result[builtins.normalize_hash_key(key)] = value
          end
        end
      end

      # Registers functions for JSON serialization and deserialization.
      #
      # @param builtins [Builtins] The Builtins instance.
      def self.register_json_helpers(builtins)
        # Parses a JSON string into Calc values: `(parse-json "{\"name\":\"taro\"}")`
        Functions.register(builtins, "parse-json", min_arity: 1, max_arity: 1) do |args|
          builtins.parse_json_value(args.first)
        end

        # Converts Calc values to a JSON string: `(stringify-json (hash :name "taro"))`
        Functions.register(builtins, "stringify-json", min_arity: 1, max_arity: 1) do |args|
          JSON.generate(builtins.jsonify_value(args.first))
        end
      end
    end
  end
end
