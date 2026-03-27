require_relative "test_helper"
require "bigdecimal"
require "json"

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

  # rubocop:disable Minitest/MultipleAssertions
  def test_marks_reserved_literals
    assert @builtins.reserved?("true")
    assert @builtins.reserved?("false")
    assert @builtins.reserved?("nil")

    refute @builtins.reserved?("x")
  end
  # rubocop:enable Minitest/MultipleAssertions

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
    assert @builtins.call("<=", [BigDecimal("1"), BigDecimal("2")])
    refute @builtins.call("<=", [BigDecimal("3"), BigDecimal("2")])
  end

  def test_calls_less_than
    assert @builtins.call("<", [BigDecimal("1"), BigDecimal("2")])
    refute @builtins.call("<", [BigDecimal("2"), BigDecimal("2")])
  end

  def test_calls_greater_than
    assert @builtins.call(">", [BigDecimal("3"), BigDecimal("2")])
    refute @builtins.call(">", [BigDecimal("2"), BigDecimal("2")])
  end

  def test_calls_greater_than_or_equal
    assert @builtins.call(">=", [BigDecimal("3"), BigDecimal("2")])
    refute @builtins.call(">=", [BigDecimal("1"), BigDecimal("2")])
  end

  def test_calls_equal
    assert @builtins.call("==", [BigDecimal("2"), BigDecimal("2")])
    refute @builtins.call("==", [BigDecimal("1"), BigDecimal("2")])
  end

  def test_calls_not_equal
    assert @builtins.call("!=", [BigDecimal("1"), BigDecimal("2")])
    refute @builtins.call("!=", [BigDecimal("2"), BigDecimal("2")])
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

  def test_builds_hashes_with_last_key_wins
    result = @builtins.call("hash", [":name", "taro", ":name", "hanako", ":age", BigDecimal("20")])

    assert_equal({ "name" => "hanako", "age" => BigDecimal("20") }, result)
  end

  def test_rejects_non_keyword_hash_keys
    error = assert_raises(Calc::RuntimeError) { @builtins.call("hash", %w[name taro]) }

    assert_equal "hash keys must be keywords", error.message
  end

  def test_get_reads_from_hashes_and_lists
    hash = { "name" => "taro" }

    assert_equal "taro", @builtins.call("get", [hash, ":name"])
    assert_equal BigDecimal("2"), @builtins.call("get", [[BigDecimal("1"), BigDecimal("2")], BigDecimal("1")])
    assert_nil @builtins.call("get", [hash, ":missing"])
  end

  def test_set_returns_new_hashes_and_lists
    hash = { "name" => "taro" }
    list = [BigDecimal("1"), BigDecimal("2")]

    assert_equal({ "name" => "hanako" }, @builtins.call("set", [hash, ":name", "hanako"]))
    assert_equal([BigDecimal("1"), BigDecimal("9")], @builtins.call("set", [list, BigDecimal("1"), BigDecimal("9")]))
  end

  def test_set_rejects_non_keyword_hash_keys_and_invalid_indices
    error = assert_raises(Calc::RuntimeError) { @builtins.call("set", [{}, BigDecimal("0"), "value"]) }

    assert_equal "hash keys must be keywords", error.message
  end

  def test_entries_returns_key_value_pairs
    result = @builtins.call("entries", [{ "name" => "taro", "age" => BigDecimal("20") }])

    assert_equal [%w[name taro], ["age", BigDecimal("20")]], result
  end

  def test_parses_json_into_calc_values
    result = @builtins.call("parse-json", ['{"name":"taro","scores":[1,2.5],"meta":{"active":true}}'])

    assert_equal "taro", result["name"]
    assert_equal [BigDecimal("1"), BigDecimal("2.5")], result["scores"]
    assert_equal({ "active" => true }, result["meta"])
  end

  def test_parse_json_requires_string
    error = assert_raises(Calc::RuntimeError) { @builtins.call("parse-json", [123]) }

    assert_equal "parse-json expects a string", error.message
  end

  def test_stringifies_calc_values_into_json
    value = { "name" => "taro", "scores" => [BigDecimal("1"), BigDecimal("2.5")], "meta" => { "active" => true } }

    assert_equal '{"name":"taro","scores":[1,2.5],"meta":{"active":true}}', @builtins.call("stringify-json", [value])
  end

  def test_stringify_json_keeps_unrepresentable_bigdecimals_as_strings
    huge = BigDecimal("1e1000")
    value = { "huge" => huge, "tiny" => BigDecimal("0.1") }
    expected = { "huge" => huge.to_s("F"), "tiny" => 0.1 }

    assert_equal JSON.generate(expected), @builtins.call("stringify-json", [value])
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
    callable = Calc::LambdaValue.new(%w[memo x], @parser.parse("(+ memo x)").first, @environment.snapshot, nil)
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

  # rubocop:disable Minitest/MultipleAssertions
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
  # rubocop:enable Minitest/MultipleAssertions
end
