require "bigdecimal"
require "json"

module Calc
  class Builtins
    LITERALS = {
      "true" => true,
      "false" => false,
      "nil" => nil
    }.freeze

    Builtin = Struct.new(:name, :min_arity, :max_arity, :type, :description, :example, :callable)

    def initialize
      @functions = {}

      Functions.register_all(self)
    end

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

    def literal?(name)
      LITERALS.key?(name)
    end

    def resolve(name)
      return [true, LITERALS[name]] if literal?(name)

      [false, nil]
    end

    def reserved?(name)
      literal?(name)
    end

    def registered?(name)
      @functions.key?(name)
    end

    def builtin(name)
      @functions[name]
    end

    def each_builtin(&block)
      return enum_for(:each_builtin) unless block

      @functions.values.each(&block)
    end

    def call(name, args, &)
      builtin = @functions[name]
      raise Calc::NameError, "unknown function: #{name}" unless builtin
      raise Calc::RuntimeError, "wrong number of arguments for #{name}" if args.length < builtin.min_arity
      raise Calc::RuntimeError, "wrong number of arguments for #{name}" if builtin.max_arity && args.length > builtin.max_arity

      builtin.callable.call(args, &)
    end

    def truthy?(value)
      value != false && !value.nil?
    end

    private

    def normalize_hash_key(key)
      case key
      when String
        raise Calc::RuntimeError, "hash keys must be keywords" unless key.start_with?(":")

        key.delete_prefix(":")
      else
        raise Calc::RuntimeError, "hash keys must be keywords"
      end
    end

    def parse_json_value(value)
      raise Calc::RuntimeError, "parse-json expects a string" unless value.is_a?(String)

      JSON.parse(value, symbolize_names: false, decimal_class: BigDecimal).then { |parsed| convert_json_to_calc(parsed) }
    rescue JSON::ParserError => e
      raise Calc::SyntaxError, e.message
    end

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

    def entries_from_hash(hash)
      hash.map { |key, value| [keyword_for_key(key), value] }
    end

    def keyword_for_key(key)
      ":#{key}"
    end

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

    def normalize_index(key)
      case key
      when Integer
        key
      when BigDecimal
        return nil unless key.frac.zero?

        key.to_i
      end
    end

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
  end
end
