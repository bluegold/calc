require "bigdecimal"
require "json"

module Calc
  # Manages all built-in functions, special literals, and utility methods
  # for the Calc interpreter. It acts as a registry and dispatcher for
  # functions callable directly from Calc code.
  class Builtins
    # Special literal values in Calc.
    LITERALS = {
      "true" => true,
      "false" => false,
      "nil" => nil
    }.freeze

    # Struct to hold metadata about each built-in function.
    # @attr name [String] The name of the function.
    # @attr min_arity [Integer] Minimum number of arguments.
    # @attr max_arity [Integer, nil] Maximum number of arguments, nil for variadic.
    # @attr type [String] Type signature or description.
    # @attr description [String] A brief description of the function.
    # @attr example [String] An example usage of the function.
    # @attr callable [Proc] The actual Ruby Proc that implements the function.
    Builtin = Struct.new(:name, :min_arity, :max_arity, :type, :description, :example, :callable)

    # Initializes the Builtins registry and registers all predefined functions.
    def initialize
      @functions = {}

      Functions.register_all(self)
    end

    # Registers a new built-in function with its metadata and implementation.
    #
    # @param name [String] The name of the function.
    # @param min_arity [Integer] The minimum number of arguments the function accepts.
    # @param max_arity [Integer, nil] The maximum number of arguments, nil for variadic functions.
    # @param metadata [Hash] Additional metadata like :type, :description, :example.
    # @param block [Proc] The Ruby Proc that implements the function's logic.
    def register(name, min_arity: 0, max_arity: nil, **metadata, &block)
      @functions[name] = Builtin.new(
        name: name,
        min_arity: min_arity,
        max_arity: max_arity,
        type: metadata[:type],
        description: metadata[:description],
        example: metadata[:example],
        callable: block
      )
    end

    # Checks if a given name corresponds to a special literal value.
    #
    # @param name [String] The name to check.
    # @return [Boolean] True if the name is a literal, false otherwise.
    def literal?(name)
      LITERALS.key?(name)
    end

    # Resolves a name against special literals.
    #
    # @param name [String] The name to resolve.
    # @return [Array<Boolean, Object>] A pair [found, value]. `found` is true if it's a literal, `value` is the literal's value.
    def resolve(name)
      return [true, LITERALS[name]] if literal?(name)

      [false, nil]
    end

    # Checks if a given name is a reserved literal.
    #
    # @param name [String] The name to check.
    # @return [Boolean] True if the name is reserved (a literal), false otherwise.
    def reserved?(name)
      literal?(name)
    end

    # Checks if a function with the given name is registered as a built-in.
    #
    # @param name [String] The function name to check.
    # @return [Boolean] True if registered, false otherwise.
    def registered?(name)
      @functions.key?(name)
    end

    # Retrieves the Builtin struct for a given function name.
    #
    # @param name [String] The function name.
    # @return [Builtin, nil] The Builtin struct, or nil if not found.
    def builtin(name)
      @functions[name]
    end

    # Iterates over all registered built-in functions.
    #
    # @yieldparam builtin [Builtin] Each Builtin struct.
    # @return [Enumerator] An enumerator if no block is given.
    def each_builtin(&block)
      return enum_for(:each_builtin) unless block

      @functions.values.each(&block)
    end

    # Calls a registered built-in function with the given arguments.
    # Performs arity checks before calling the underlying callable.
    #
    # @param name [String] The name of the function to call.
    # @param args [Array<Object>] An array of arguments for the function.
    # @param block [Proc] An optional callable runner for higher-order functions.
    # @return [Object] The result of the function call.
    # @raise [Calc::NameError] If the function is unknown.
    # @raise [Calc::RuntimeError] If the number of arguments is incorrect.
    def call(name, args, &)
      builtin = @functions[name]
      raise Calc::NameError, "unknown function: #{name}" unless builtin
      raise Calc::RuntimeError, "wrong number of arguments for #{name}" if args.length < builtin.min_arity
      raise Calc::RuntimeError, "wrong number of arguments for #{name}" if builtin.max_arity && args.length > builtin.max_arity

      builtin.callable.call(args, &)
    end

    # Determines if a value is truthy (not false and not nil) in Calc's logic.
    #
    # @param value [Object] The value to check.
    # @return [Boolean] True if truthy, false otherwise.
    def truthy?(value)
      value != false && !value.nil?
    end

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

    # Parses a JSON string value and converts it into Calc's internal representation.
    #
    # @param value [String] The JSON string to parse.
    # @return [Object] The Calc-compatible representation of the JSON value.
    # @raise [Calc::RuntimeError] If the input is not a string.
    # @raise [Calc::SyntaxError] If the JSON string is malformed.
    def parse_json_value(value)
      raise Calc::RuntimeError, "parse-json expects a string" unless value.is_a?(String)

      JSON.parse(value, symbolize_names: false, decimal_class: BigDecimal).then { |parsed| convert_json_to_calc(parsed) }
    rescue JSON::ParserError => e
      raise Calc::SyntaxError, e.message
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
    # @return [Array<Array>] An array of `[keyword, value]` pairs.
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

    private

    # Recursively converts parsed JSON values into Calc's internal data types.
    #
    # @param value [Object] The value parsed from JSON.
    # @return [Object] The Calc-compatible representation.
    def convert_json_to_calc(value)
      case value
      when Array
        value.map { |item| convert_json_to_calc(item) }
      when Hash
        value.each_with_object({}) do |(key, item), result|
          result[key] = convert_json_to_calc(item)
        end
      when Integer, BigDecimal
        BigDecimal(value.to_s)
      else
        value
      end
    end

    public

    # Recursively converts Calc's internal data types into JSON-serializable types.
    # Handles BigDecimal to Float/Integer conversion for JSON compatibility.
    #
    # @param value [Object] The Calc value to jsonify.
    # @return [Object] The JSON-serializable representation.
    def jsonify_value(value)
      case value
      when Array
        value.map { |item| jsonify_value(item) }
      when Hash
        value.each_with_object({}) do |(key, item), result|
          result[key.to_s] = jsonify_value(item)
        end
      when BigDecimal
        float_value = value.to_f
        return value.to_i if value.frac.zero? && value.abs <= BigDecimal(Float::MAX.to_s)
        return float_value if float_value.finite? && BigDecimal(float_value.to_s) == value

        value.to_s("F")
      else
        value
      end
    end
  end
end
