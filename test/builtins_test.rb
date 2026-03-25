require_relative "test_helper"
require "bigdecimal"

class BuiltinsTest < Minitest::Test
  def setup
    @builtins = Calc::Builtins.new
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

  def test_registers_custom_function
    @builtins.register("square", min_arity: 1, max_arity: 1) do |args|
      args.first * args.first
    end

    result = @builtins.call("square", [BigDecimal("4")])

    assert_equal BigDecimal("16"), result
  end

  def test_calls_pow
    result = @builtins.call("pow", [BigDecimal("2"), BigDecimal("3")])

    assert_equal BigDecimal("8"), result
  end

  def test_calls_sqrt
    result = @builtins.call("sqrt", [BigDecimal("9")])

    assert_equal BigDecimal("3"), result
  end
end
