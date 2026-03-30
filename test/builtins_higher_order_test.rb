require_relative "test_helper"
require "bigdecimal"

class BuiltinsHigherOrderTest < Minitest::Test
  def setup
    @builtins = Calc::Builtins.new
    @parser = Calc::Parser.new
    @environment = Calc::Environment.new
    @executer = Calc::Executer.new(@environment)
  end

  def test_maps_with_callable_runner
    callable = Calc::LambdaValue.new(["x"], @parser.parse("(+ x 1)").first, @environment.snapshot, nil)

    result = @builtins.call("map", [callable, [1, 2, 3]]) do |callable_value, values|
      @executer.send(:call_lambda, callable_value, values)
    end

    assert_equal [BigDecimal("2"), BigDecimal("3"), BigDecimal("4")], result
  end

  def test_reduce_with_callable_runner
    callable = Calc::LambdaValue.new(%w[memo x], @parser.parse("(+ memo x)").first, @environment.snapshot, nil)

    result = @builtins.call("reduce", [callable, BigDecimal("0"), [1, 2, 3]]) do |callable_value, values|
      @executer.send(:call_lambda, callable_value, values)
    end

    assert_equal BigDecimal("6"), result
  end

  def test_fold_with_callable_runner
    callable = Calc::LambdaValue.new(%w[memo x], @parser.parse("(+ memo x)").first, @environment.snapshot, nil)

    result = @builtins.call("fold", [callable, BigDecimal("0"), [1, 2, 3]]) do |callable_value, values|
      @executer.send(:call_lambda, callable_value, values)
    end

    assert_equal BigDecimal("6"), result
  end

  def test_select_with_callable_runner
    callable = Calc::LambdaValue.new(["x"], @parser.parse("(> x 1)").first, @environment.snapshot, nil)

    result = @builtins.call("select", [callable, [1, 2, 3]]) do |callable_value, values|
      @executer.send(:call_lambda, callable_value, values)
    end

    assert_equal [2, 3], result
  end

  def test_collect_aliases_map
    callable = Calc::LambdaValue.new(["x"], @parser.parse("(+ x 1)").first, @environment.snapshot, nil)

    result = @builtins.call("collect", [callable, [1, 2, 3]]) do |callable_value, values|
      @executer.send(:call_lambda, callable_value, values)
    end

    assert_equal [BigDecimal("2"), BigDecimal("3"), BigDecimal("4")], result
  end

  def test_filter_aliases_select
    callable = Calc::LambdaValue.new(["x"], @parser.parse("(> x 1)").first, @environment.snapshot, nil)

    result = @builtins.call("filter", [callable, [1, 2, 3]]) do |callable_value, values|
      @executer.send(:call_lambda, callable_value, values)
    end

    assert_equal [2, 3], result
  end

  def test_fold_aliases_reduce_callable
    assert_same @builtins.builtin("reduce").callable, @builtins.builtin("fold").callable
  end

  def test_find_returns_first_matching_item
    callable = Calc::LambdaValue.new(["x"], @parser.parse("(> x 1)").first, @environment.snapshot, nil)

    result = @builtins.call("find", [callable, [1, 2, 3]]) do |callable_value, values|
      @executer.send(:call_lambda, callable_value, values)
    end

    assert_equal 2, result
  end

  def test_any_all_none_with_callable_runner
    greater_than_one = Calc::LambdaValue.new(["x"], @parser.parse("(> x 1)").first, @environment.snapshot, nil)
    positive = Calc::LambdaValue.new(["x"], @parser.parse("(> x 0)").first, @environment.snapshot, nil)
    negative = Calc::LambdaValue.new(["x"], @parser.parse("(< x 0)").first, @environment.snapshot, nil)

    any_result = @builtins.call("any?", [greater_than_one, [1, 2, 3]]) do |callable_value, values|
      @executer.send(:call_lambda, callable_value, values)
    end
    all_result = @builtins.call("all?", [positive, [1, 2, 3]]) do |callable_value, values|
      @executer.send(:call_lambda, callable_value, values)
    end
    none_result = @builtins.call("none?", [negative, [1, 2, 3]]) do |callable_value, values|
      @executer.send(:call_lambda, callable_value, values)
    end

    assert any_result
    assert all_result
    assert none_result
  end

  def test_flat_map_flattens_one_level
    callable = Calc::LambdaValue.new(["x"], @parser.parse("(list x (+ x 10))").first, @environment.snapshot, nil)

    result = @builtins.call("flat-map", [callable, [1, 2]]) do |callable_value, values|
      @executer.send(:call_lambda, callable_value, values)
    end

    assert_equal [1, BigDecimal("11"), 2, BigDecimal("12")], result
  end

  def test_count_counts_all_or_matching_items
    greater_than_one = Calc::LambdaValue.new(["x"], @parser.parse("(> x 1)").first, @environment.snapshot, nil)

    total = @builtins.call("count", [[1, 2, 3]])
    matched = @builtins.call("count", [greater_than_one, [1, 2, 3]]) do |callable_value, values|
      @executer.send(:call_lambda, callable_value, values)
    end

    assert_equal BigDecimal("3"), total
    assert_equal BigDecimal("2"), matched
  end

  # rubocop:disable Minitest/MultipleAssertions
  def test_higher_order_functions_accept_hash_iterables
    pair_to_value = Calc::LambdaValue.new(["pair"], @parser.parse("(get pair 1)").first, @environment.snapshot, nil)
    pair_predicate = Calc::LambdaValue.new(["pair"], @parser.parse("(== (get pair 0) :enabled)").first,
                                           @environment.snapshot, nil)
    pair_reduce = Calc::LambdaValue.new(%w[memo pair], @parser.parse("(+ memo (get pair 1))").first,
                                        @environment.snapshot, nil)
    hash = { "enabled" => BigDecimal("2"), "disabled" => BigDecimal("1") }

    mapped = @builtins.call("map", [pair_to_value, hash]) { |fn, values| @executer.send(:call_lambda, fn, values) }
    selected = @builtins.call("select", [pair_predicate, hash]) { |fn, values| @executer.send(:call_lambda, fn, values) }
    reduced = @builtins.call("reduce", [pair_reduce, BigDecimal("0"), hash]) do |fn, values|
      @executer.send(:call_lambda, fn, values)
    end
    folded = @builtins.call("fold", [pair_reduce, BigDecimal("0"), hash]) do |fn, values|
      @executer.send(:call_lambda, fn, values)
    end

    assert_equal [BigDecimal("2"), BigDecimal("1")], mapped
    assert_equal [[":enabled", BigDecimal("2")]], selected
    assert_equal BigDecimal("3"), reduced
    assert_equal BigDecimal("3"), folded
  end
  # rubocop:enable Minitest/MultipleAssertions
end
