require "bigdecimal"
require "json"

module Calc
  class Builtins
    HASH_EXAMPLE = "(hash :name \"taro\" :age 20)".freeze
    GET_EXAMPLE = "(get user :name)".freeze
    SET_EXAMPLE = "(set user :name \"taro\")".freeze
    ENTRIES_EXAMPLE = "(entries user)".freeze
    PARSE_JSON_EXAMPLE = "(parse-json \"{\\\"name\\\":\\\"taro\\\"}\")".freeze
    STRINGIFY_JSON_EXAMPLE = "(stringify-json (hash :name \"taro\"))".freeze

    LITERALS = {
      "true" => true,
      "false" => false,
      "nil" => nil
    }.freeze

    Builtin = Struct.new(:name, :min_arity, :max_arity, :description, :example, :callable)

    def initialize
      @functions = {}

      register("+", min_arity: 0, description: "Add numbers", example: "(+ 1 2 3)") do |args|
        args.reduce(BigDecimal("0"), :+)
      end
      register("-", min_arity: 1, description: "Subtract numbers",
                    example: "(- 5 2)") do |args|
        if args.length == 1
          -args.first
        else
          args.reduce do |memo, v|
            memo - v
          end
        end
      end
      register("*", min_arity: 0, description: "Multiply numbers", example: "(* 2 3 4)") do |args|
        args.reduce(BigDecimal("1"), :*)
      end
      register("/", min_arity: 1, description: "Divide numbers", example: "(/ 8 2)") do |args|
        args.reduce do |memo, v|
          raise DivisionByZeroError, "division by zero" if v.zero?

          memo / v
        end
      end
      register("<", min_arity: 2, max_arity: 2, description: "Less than", example: "(< 1 2)") do |args|
        args[0] < args[1]
      end
      register("<=", min_arity: 2, max_arity: 2, description: "Less than or equal", example: "(<= 1 2)") do |args|
        args[0] <= args[1]
      end
      register(">", min_arity: 2, max_arity: 2, description: "Greater than", example: "(> 2 1)") do |args|
        args[0] > args[1]
      end
      register(">=", min_arity: 2, max_arity: 2, description: "Greater than or equal", example: "(>= 2 1)") do |args|
        args[0] >= args[1]
      end
      register("==", min_arity: 2, max_arity: 2, description: "Equal", example: "(== 1 1)") do |args|
        args[0] == args[1]
      end
      register("!=", min_arity: 2, max_arity: 2, description: "Not equal", example: "(!= 1 2)") do |args|
        args[0] != args[1]
      end
      register("concat", min_arity: 0, description: "Concatenate strings", example: "(concat \"a\" \"b\")", &:join)
      register("length", min_arity: 1, max_arity: 1, description: "String length", example: "(length \"calc\")") do |args|
        args.first.to_s.length
      end
      register("print", min_arity: 0, description: "Print values", example: "(print \"hello\" 1)") do |args|
        args.each do |value|
          $stdout.puts Calc.format_value(value)
        end

        nil
      end
      register("list", min_arity: 0, description: "Create a list", example: "(list 1 2 3)") do |args|
        args
      end
      register_dictionary_builtins
      register_higher_order_builtins

      Functions::Pow.register(self)
      Functions::Sqrt.register(self)
    end

    def register(name, min_arity: 0, max_arity: nil, description: nil, example: nil, &block)
      @functions[name] = Builtin.new(
        name: name,
        min_arity: min_arity,
        max_arity: max_arity,
        description: description,
        example: example,
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

    # rubocop:disable Layout/HashAlignment
    def register_dictionary_builtins
      register("hash", min_arity: 0, description: "Create a hash", example: HASH_EXAMPLE) do |args|
        raise Calc::RuntimeError, "hash expects key/value pairs" if args.length.odd?

        args.each_slice(2).with_object({}) do |(key, value), result|
          result[normalize_hash_key(key)] = value
        end
      end
      register("get", min_arity: 2, max_arity: 2, description: "Read a value from a list or hash", example: GET_EXAMPLE) do |args|
        container, key = args
        get_value(container, key)
      end
      register("set", min_arity: 3, max_arity: 3, description: "Return a new list or hash with an updated value",
                      example: SET_EXAMPLE) do |args|
        container, key, value = args
        set_value(container, key, value)
      end
      register("entries", min_arity: 1, max_arity: 1, description: "Return hash entries as [key, value] pairs",
                      example: ENTRIES_EXAMPLE) do |args|
        container = args.first
        raise Calc::RuntimeError, "entries expects a hash" unless container.is_a?(Hash)

        container.map { |key, value| [key, value] }
      end
      register("parse-json", min_arity: 1, max_arity: 1, description: "Parse JSON into Calc values",
                      example: PARSE_JSON_EXAMPLE) do |args|
        parse_json_value(args.first)
      end
      register("stringify-json", min_arity: 1, max_arity: 1, description: "Convert Calc values to JSON",
                      example: STRINGIFY_JSON_EXAMPLE) do |args|
        JSON.generate(jsonify_value(args.first))
      end
    end
    # rubocop:enable Layout/HashAlignment

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

      JSON.parse(value, symbolize_names: false).then { |parsed| convert_json_to_calc(parsed) }
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
      when Integer, Float
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

    def register_higher_order_builtins
      register("map", min_arity: 2, max_arity: 2, description: "Map a function over a list",
                      example: "(map (lambda (x) (+ x 1)) (list 1 2 3))") do |args, &block|
        callable, list = args
        raise Calc::RuntimeError, "map expects a list" unless list.is_a?(Array)
        raise Calc::NameError, "map expects a function" unless block

        list.map { |item| block.call(callable, [item]) }
      end
      register("reduce", min_arity: 3, max_arity: 3, description: "Reduce a list with a function",
                         example: "(reduce (lambda (memo x) (+ memo x)) 0 (list 1 2 3))") do |args, &block|
        callable, memo, list = args
        raise Calc::RuntimeError, "reduce expects a list" unless list.is_a?(Array)
        raise Calc::NameError, "reduce expects a function" unless block

        list.reduce(memo) { |accumulator, item| block.call(callable, [accumulator, item]) }
      end
      register("select", min_arity: 2, max_arity: 2, description: "Select items with a predicate",
                         example: "(select (lambda (x) (> x 1)) (list 1 2 3))") do |args, &block|
        callable, list = args
        raise Calc::RuntimeError, "select expects a list" unless list.is_a?(Array)
        raise Calc::NameError, "select expects a function" unless block

        list.select { |item| truthy?(block.call(callable, [item])) }
      end
    end
  end
end
