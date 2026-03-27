require "bigdecimal"

module Calc
  class Builtins
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
      register("map", min_arity: 2, max_arity: 2, description: "Map a function over a list",
                          example: "(map (lambda (x) (+ x 1)) (list 1 2 3))") do |args, &callable_runner|
        callable, list = args
        raise Calc::RuntimeError, "map expects a list" unless list.is_a?(Array)
        raise Calc::NameError, "map expects a function" unless callable_runner

        list.map { |item| callable_runner.call(callable, [item]) }
      end
      register("reduce", min_arity: 3, max_arity: 3, description: "Reduce a list with a function",
                              example: "(reduce (lambda (memo x) (+ memo x)) 0 (list 1 2 3))") do |args, &callable_runner|
        callable, memo, list = args
        raise Calc::RuntimeError, "reduce expects a list" unless list.is_a?(Array)
        raise Calc::NameError, "reduce expects a function" unless callable_runner

        list.reduce(memo) { |accumulator, item| callable_runner.call(callable, [accumulator, item]) }
      end
      register("select", min_arity: 2, max_arity: 2, description: "Select items with a predicate",
                              example: "(select (lambda (x) (> x 1)) (list 1 2 3))") do |args, &callable_runner|
        callable, list = args
        raise Calc::RuntimeError, "select expects a list" unless list.is_a?(Array)
        raise Calc::NameError, "select expects a function" unless callable_runner

        list.select { |item| truthy?(callable_runner.call(callable, [item])) }
      end

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

    def call(name, args, &callable_runner)
      builtin = @functions[name]
      raise Calc::NameError, "unknown function: #{name}" unless builtin
      raise Calc::RuntimeError, "wrong number of arguments for #{name}" if args.length < builtin.min_arity
      raise Calc::RuntimeError, "wrong number of arguments for #{name}" if builtin.max_arity && args.length > builtin.max_arity

      builtin.callable.call(args, &callable_runner)
    end

    def truthy?(value)
      value != false && !value.nil?
    end
  end
end
