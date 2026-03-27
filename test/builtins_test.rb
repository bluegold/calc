require_relative "test_helper"
require "bigdecimal"

class BuiltinsTest < Minitest::Test
  def setup
    @builtins = Calc::Builtins.new
    @parser = Calc::Parser.new
    @environment = Calc::Environment.new
  end

  def test_resolves_boolean_literals
    assert_equal [true, true], @builtins.resolve("true")
    assert_equal [true, false], @builtins.resolve("false")
    assert_equal [true, nil], @builtins.resolve("nil")
  end

  def test_marks_reserved_literals
    assert @builtins.reserved?("true")
    assert @builtins.reserved?("false")
    assert @builtins.reserved?("nil")
    refute @builtins.reserved?("x")
  end

  def test_calls_addition
    result = @builtins.call("+", [BigDecimal("1"), BigDecimal("2")])

    assert_equal BigDecimal("3"), result
  end

  def test_calls_multiplication
    result = @builtins.call("*", [BigDecimal("2"), BigDecimal("3")])

    assert_equal BigDecimal("6"), result
  end

  def test_division_by_zero_raises_custom_error
    error = assert_raises(Calc::DivisionByZeroError) do
      @builtins.call("/", [BigDecimal("8"), BigDecimal("0")])
    end

    assert_equal "division by zero", error.message
  end

  def test_registers_custom_function
    @builtins.register("square", min_arity: 1, max_arity: 1, description: "Square a number",
                                 example: "(square 4)") do |args|
      args.first * args.first
    end

    result = @builtins.call("square", [BigDecimal("4")])

    assert_equal BigDecimal("16"), result
    builtin = @builtins.builtin("square")
    assert_equal "Square a number", builtin.description
    assert_equal "(square 4)", builtin.example
  end

  def test_calls_pow
    result = @builtins.call("pow", [BigDecimal("2"), BigDecimal("3")])

    assert_equal BigDecimal("8"), result
  end

  def test_calls_sqrt
    result = @builtins.call("sqrt", [BigDecimal("9")])

    assert_equal BigDecimal("3"), result
  end

  def test_calls_less_than_or_equal
    assert_equal true, @builtins.call("<=", [BigDecimal("1"), BigDecimal("2")])
    assert_equal false, @builtins.call("<=", [BigDecimal("3"), BigDecimal("2")])
  end

  def test_calls_less_than
    assert_equal true, @builtins.call("<", [BigDecimal("1"), BigDecimal("2")])
    assert_equal false, @builtins.call("<", [BigDecimal("2"), BigDecimal("2")])
  end

  def test_calls_greater_than
    assert_equal true, @builtins.call(">", [BigDecimal("3"), BigDecimal("2")])
    assert_equal false, @builtins.call(">", [BigDecimal("2"), BigDecimal("2")])
  end

  def test_calls_greater_than_or_equal
    assert_equal true, @builtins.call(">=", [BigDecimal("3"), BigDecimal("2")])
    assert_equal false, @builtins.call(">=", [BigDecimal("1"), BigDecimal("2")])
  end

  def test_calls_equal
    assert_equal true, @builtins.call("==", [BigDecimal("2"), BigDecimal("2")])
    assert_equal false, @builtins.call("==", [BigDecimal("1"), BigDecimal("2")])
  end

  def test_calls_not_equal
    assert_equal true, @builtins.call("!=", [BigDecimal("1"), BigDecimal("2")])
    assert_equal false, @builtins.call("!=", [BigDecimal("2"), BigDecimal("2")])
  end

  def test_concatenates_strings
    result = @builtins.call("concat", %w[cal c])

    assert_equal "calc", result
  end

  def test_returns_string_length
    result = @builtins.call("length", ["calc"])

    assert_equal 4, result
  end

  def test_prints_values_to_stdout_and_returns_nil
    out, err = capture_io do
      result = @builtins.call("print", ["calc", BigDecimal("1.5"), true])

      assert_nil result
    end

    assert_equal "calc\n1.5\ntrue\n", out
    assert_empty err
  end

  def test_builds_lists
    result = @builtins.call("list", [1, 2, 3])

    assert_equal [1, 2, 3], result
  end

  def test_formats_nested_lists
    assert_equal "[1, 2, 3]", Calc.format_value([BigDecimal("1"), BigDecimal("2"), BigDecimal("3")])
  end

  def test_maps_with_callable_runner
    callable = Calc::LambdaValue.new(["x"], @parser.parse("(+ x 1)").first, @environment.snapshot, nil)
    result = @builtins.call("map", [callable, [1, 2, 3]]) do |callable_value, values|
      Calc::Executer.new(@environment).send(:call_lambda, callable_value, values)
    end

    assert_equal [BigDecimal("2"), BigDecimal("3"), BigDecimal("4")], result
  end

  def test_reduce_with_callable_runner
    callable = Calc::LambdaValue.new(["memo", "x"], @parser.parse("(+ memo x)").first, @environment.snapshot, nil)
    result = @builtins.call("reduce", [callable, BigDecimal("0"), [1, 2, 3]]) do |callable_value, values|
      Calc::Executer.new(@environment).send(:call_lambda, callable_value, values)
    end

    assert_equal BigDecimal("6"), result
  end

  def test_select_with_callable_runner
    callable = Calc::LambdaValue.new(["x"], @parser.parse("(> x 1)").first, @environment.snapshot, nil)
    result = @builtins.call("select", [callable, [1, 2, 3]]) do |callable_value, values|
      Calc::Executer.new(@environment).send(:call_lambda, callable_value, values)
    end

    assert_equal [2, 3], result
  end

  def test_enumerates_builtins
    names = @builtins.each_builtin.map(&:name)

    assert_includes names, "+"
    assert_includes names, "<="
    assert_includes names, "<"
    assert_includes names, ">"
    assert_includes names, ">="
    assert_includes names, "=="
    assert_includes names, "!="
    assert_includes names, "concat"
    assert_includes names, "length"
    assert_includes names, "print"
    assert_includes names, "list"
    assert_includes names, "pow"
    assert_includes names, "sqrt"
  end
end
