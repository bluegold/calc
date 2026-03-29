require_relative "test_helper"
require "bigdecimal"

class BuiltinsCoreTest < Minitest::Test
  def setup
    @builtins = Calc::Builtins.new
  end

  def test_resolves_boolean_literals
    assert_equal [true, true], @builtins.resolve("true")
    assert_equal [true, false], @builtins.resolve("false")
    assert_equal [true, nil], @builtins.resolve("nil")
  end

  # rubocop:disable Minitest/MultipleAssertions
  def test_marks_reserved_literals
    assert @builtins.reserved?("true")
    assert @builtins.reserved?("false")
    assert @builtins.reserved?("nil")

    refute @builtins.reserved?("x")
  end
  # rubocop:enable Minitest/MultipleAssertions

  def test_calls_addition
    assert_equal BigDecimal("3"), @builtins.call("+", [BigDecimal("1"), BigDecimal("2")])
  end

  def test_calls_multiplication
    assert_equal BigDecimal("6"), @builtins.call("*", [BigDecimal("2"), BigDecimal("3")])
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

    assert_equal BigDecimal("16"), @builtins.call("square", [BigDecimal("4")])

    builtin = @builtins.builtin("square")

    assert_equal "Square a number", builtin.description
    assert_equal "(square 4)", builtin.example
  end

  def test_calls_pow
    assert_equal BigDecimal("8"), @builtins.call("pow", [BigDecimal("2"), BigDecimal("3")])
  end

  def test_calls_abs
    assert_equal BigDecimal("3.5"), @builtins.call("abs", [BigDecimal("-3.5")])
  end

  def test_calls_mod
    assert_equal BigDecimal("1"), @builtins.call("mod", [BigDecimal("10"), BigDecimal("3")])
  end

  def test_mod_by_zero_raises_custom_error
    error = assert_raises(Calc::DivisionByZeroError) do
      @builtins.call("mod", [BigDecimal("8"), BigDecimal("0")])
    end

    assert_equal "division by zero", error.message
  end

  # rubocop:disable Minitest/MultipleAssertions
  def test_calls_rounding_helpers
    assert_equal BigDecimal("3"), @builtins.call("floor", [BigDecimal("3.9")])
    assert_equal BigDecimal("4"), @builtins.call("ceil", [BigDecimal("3.1")])
    assert_equal BigDecimal("4"), @builtins.call("round", [BigDecimal("3.6")])
  end
  # rubocop:enable Minitest/MultipleAssertions

  def test_calls_sqrt
    assert_equal BigDecimal("3"), @builtins.call("sqrt", [BigDecimal("9")])
  end

  # rubocop:disable Minitest/MultipleAssertions
  def test_calls_comparison_operators
    assert @builtins.call("<=", [BigDecimal("1"), BigDecimal("2")])
    refute @builtins.call("<=", [BigDecimal("3"), BigDecimal("2")])
    assert @builtins.call("<", [BigDecimal("1"), BigDecimal("2")])
    refute @builtins.call("<", [BigDecimal("2"), BigDecimal("2")])
    assert @builtins.call(">", [BigDecimal("3"), BigDecimal("2")])
    refute @builtins.call(">", [BigDecimal("2"), BigDecimal("2")])
    assert @builtins.call(">=", [BigDecimal("3"), BigDecimal("2")])
    refute @builtins.call(">=", [BigDecimal("1"), BigDecimal("2")])
    assert @builtins.call("==", [BigDecimal("2"), BigDecimal("2")])
    refute @builtins.call("==", [BigDecimal("1"), BigDecimal("2")])
    assert @builtins.call("!=", [BigDecimal("1"), BigDecimal("2")])
    refute @builtins.call("!=", [BigDecimal("2"), BigDecimal("2")])
  end
  # rubocop:enable Minitest/MultipleAssertions

  def test_concatenates_strings
    assert_equal "calc", @builtins.call("concat", %w[cal c])
  end

  def test_returns_string_length
    assert_equal 4, @builtins.call("length", ["calc"])
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
    assert_equal [1, 2, 3], @builtins.call("list", [1, 2, 3])
  end

  def test_formats_nested_lists
    value = [BigDecimal("1"), BigDecimal("2"), BigDecimal("3")]

    assert_equal "[1, 2, 3]", Calc.format_value(value)
  end

  # rubocop:disable Minitest/MultipleAssertions
  def test_enumerates_core_and_math_builtins
    names = @builtins.each_builtin.map(&:name)

    assert_includes names, "+"
    assert_includes names, "-"
    assert_includes names, "*"
    assert_includes names, "/"
    assert_includes names, "<="
    assert_includes names, "<"
    assert_includes names, ">"
    assert_includes names, ">="
    assert_includes names, "=="
    assert_includes names, "!="
    assert_includes names, "concat"
    assert_includes names, "length"
    assert_includes names, "pow"
    assert_includes names, "abs"
    assert_includes names, "mod"
    assert_includes names, "floor"
    assert_includes names, "ceil"
    assert_includes names, "round"
    assert_includes names, "sqrt"
    assert_includes names, "list"
    assert_includes names, "print"
  end
  # rubocop:enable Minitest/MultipleAssertions
end
