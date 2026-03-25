require "bigdecimal"

module Calc
  class Builtins
    LITERALS = {
      "true" => true,
      "false" => false,
      "nil" => nil,
    }.freeze

    Builtin = Struct.new(:name, :min_arity, :max_arity, :callable, keyword_init: true)

    def initialize
      @functions = {}

      register("+", min_arity: 0) do |args|
        args.reduce(BigDecimal("0"), :+)
      end

      register("-", min_arity: 1) do |args|
        args.length == 1 ? -args.first : args.reduce { |memo, v| memo - v }
      end

      register("*", min_arity: 0) do |args|
        args.reduce(BigDecimal("1"), :*)
      end

      register("/", min_arity: 1) do |args|
        args.reduce { |memo, v| memo / v }
      end
    end

    def register(name, min_arity: 0, max_arity: nil, &block)
      @functions[name] = Builtin.new(
        name: name,
        min_arity: min_arity,
        max_arity: max_arity,
        callable: block,
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

    def call(name, args)
      builtin = @functions[name]
      raise NameError, "unknown function: #{name}" unless builtin
      raise ArgumentError, "wrong number of arguments for #{name}" if args.length < builtin.min_arity
      if builtin.max_arity && args.length > builtin.max_arity
        raise ArgumentError, "wrong number of arguments for #{name}"
      end

      builtin.callable.call(args)
    end
  end
end
