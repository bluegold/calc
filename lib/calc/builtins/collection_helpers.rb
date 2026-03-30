module Calc
  class Builtins
    # Helpers for list/hash operations used by multiple built-in functions.
    module CollectionHelpers
      # Normalizes a hash key, converting keyword strings to plain strings.
      #
      # @param key [String] The key to normalize.
      # @return [String] The normalized key.
      # @raise [Calc::RuntimeError] If the key is not a keyword string or is of an invalid type.
      def normalize_hash_key(key)
        case key
        when String
          raise Calc::RuntimeError, "hash keys must be keywords" unless key.start_with?(":")

          key.delete_prefix(":")
        else
          raise Calc::RuntimeError, "hash keys must be keywords"
        end
      end

      # Retrieves a value from a container (Hash or Array) using a given key/index.
      #
      # @param container [Hash, Array] The container to get the value from.
      # @param key [String, Integer, BigDecimal] The key (for Hash) or index (for Array).
      # @return [Object, nil] The value, or nil if not found or out of bounds for Array.
      # @raise [Calc::RuntimeError] If the container is not a hash or list.
      def get_value(container, key)
        case container
        when Hash
          container[normalize_hash_key(key)]
        when Array
          index = normalize_index(key)
          return nil if index.nil? || index.negative? || index >= container.length

          container[index]
        else
          raise Calc::RuntimeError, "get expects a hash or list"
        end
      end

      # Checks if a value exists in a container (Hash or Array) with a given key/index.
      #
      # @param container [Hash, Array] The container to check.
      # @param key [String, Integer, BigDecimal] The key (for Hash) or index (for Array).
      # @return [Boolean] True if the value exists, false otherwise.
      # @raise [Calc::RuntimeError] If the container is not a hash or list.
      def value_exists(container, key)
        case container
        when Hash
          container.key?(normalize_hash_key(key))
        when Array
          index = normalize_index(key)
          !index.nil? && index >= 0 && index < container.length
        else
          raise Calc::RuntimeError, "has? expects a hash or list"
        end
      end

      # Recursively digs into nested Hashes or Arrays to retrieve a value specified by a path.
      #
      # @param container [Hash, Array] The initial container.
      # @param path [Array<String, Integer, BigDecimal>] An array of keys/indices forming the path.
      # @return [Object, nil] The value found at the path, or nil if any part of the path is invalid.
      def dig_value(container, path)
        path.reduce(container) do |current, key|
          return nil if current.nil?

          case current
          when Hash, Array
            get_value(current, key)
          else
            return nil
          end
        end
      end

      # Converts a Ruby Hash into an array of key-value pairs suitable for Calc (using keywords for keys).
      #
      # @param hash [Hash] The Ruby Hash to convert.
      # @return [Array<Array>] An array of [keyword, value] pairs.
      def entries_from_hash(hash)
        hash.map { |key, value| [keyword_for_key(key), value] }
      end

      # Converts a string key to a Calc keyword string (e.g., "foo" to ":foo").
      #
      # @param key [String] The string key.
      # @return [String] The keyword string.
      def keyword_for_key(key)
        ":#{key}"
      end

      # Sets a value in a container (Hash or Array) at a specified key/index,
      # returning a new updated container (immutable operation).
      #
      # @param container [Hash, Array] The original container.
      # @param key [String, Integer, BigDecimal] The key (for Hash) or index (for Array).
      # @param value [Object] The value to set.
      # @return [Hash, Array] A new container with the updated value.
      # @raise [Calc::RuntimeError] If the container is not a hash or list, or for invalid array index.
      def set_value(container, key, value)
        case container
        when Hash
          normalized_key = normalize_hash_key(key)
          container.merge(normalized_key => value)
        when Array
          index = normalize_index(key)
          raise Calc::RuntimeError, "set expects a valid list index" if index.nil? || index.negative? || index >= container.length

          updated = container.dup
          updated[index] = value
          updated
        else
          raise Calc::RuntimeError, "set expects a hash or list"
        end
      end

      # Normalizes a collection (Array or Hash) into an iterable format.
      # Hashes are converted to arrays of key-value pairs.
      #
      # @param collection [Array, Hash] The collection to normalize.
      # @param name [String] The name of the calling function (for error messages).
      # @return [Array] The normalized iterable.
      # @raise [Calc::RuntimeError] If the collection is not an Array or Hash.
      def normalize_iterable(collection, name)
        case collection
        when Array
          collection
        when Hash
          entries_from_hash(collection)
        else
          raise Calc::RuntimeError, "#{name} expects a list or hash"
        end
      end

      # Normalizes an index value, converting BigDecimal to Integer if it's a whole number.
      #
      # @param key [Integer, BigDecimal] The value to normalize as an index.
      # @return [Integer, nil] The normalized integer index, or nil if not a valid integer.
      def normalize_index(key)
        case key
        when Integer
          key
        when BigDecimal
          return nil unless key.frac.zero?

          key.to_i
        end
      end
    end
  end
end
