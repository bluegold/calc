require_relative "test_helper"
require "bigdecimal"

class ExecuterHighOrderTest < Minitest::Test
  def setup
    @executer = Calc::Executer.new(Calc::Environment.new)
    @parser = Calc::Parser.new
  end

  def test_map_applies_lambda_to_each_item
    ast = @parser.parse("(map (lambda (x) (+ x 1)) (list 1 2 3))").first

    assert_equal [BigDecimal("2"), BigDecimal("3"), BigDecimal("4")], @executer.evaluate(ast)
  end

  def test_reduce_accumulates_values
    ast = @parser.parse("(reduce (lambda (memo x) (+ memo x)) 0 (list 1 2 3))").first

    assert_equal BigDecimal("6"), @executer.evaluate(ast)
  end

  def test_fold_accumulates_values
    ast = @parser.parse("(fold (lambda (memo x) (+ memo x)) 0 (list 1 2 3))").first

    assert_equal BigDecimal("6"), @executer.evaluate(ast)
  end

  def test_select_filters_values
    ast = @parser.parse("(select (lambda (x) (> x 1)) (list 1 2 3))").first

    assert_equal [BigDecimal("2"), BigDecimal("3")], @executer.evaluate(ast)
  end

  def test_collect_maps_values
    ast = @parser.parse("(collect (lambda (x) (+ x 1)) (list 1 2 3))").first

    assert_equal [BigDecimal("2"), BigDecimal("3"), BigDecimal("4")], @executer.evaluate(ast)
  end

  def test_filter_filters_values
    ast = @parser.parse("(filter (lambda (x) (> x 1)) (list 1 2 3))").first

    assert_equal [BigDecimal("2"), BigDecimal("3")], @executer.evaluate(ast)
  end

  def test_find_returns_first_matching_value
    ast = @parser.parse("(find (lambda (x) (> x 1)) (list 1 2 3))").first

    assert_equal BigDecimal("2"), @executer.evaluate(ast)
  end

  def test_any_all_none_with_predicates
    any_ast = @parser.parse("(any? (lambda (x) (> x 2)) (list 1 2 3))").first
    all_ast = @parser.parse("(all? (lambda (x) (> x 0)) (list 1 2 3))").first
    none_ast = @parser.parse("(none? (lambda (x) (< x 0)) (list 1 2 3))").first

    assert @executer.evaluate(any_ast)
    assert @executer.evaluate(all_ast)
    assert @executer.evaluate(none_ast)
  end

  def test_flat_map_expands_nested_lists
    ast = @parser.parse("(flat-map (lambda (x) (list x (+ x 10))) (list 1 2))").first

    assert_equal [BigDecimal("1"), BigDecimal("11"), BigDecimal("2"), BigDecimal("12")], @executer.evaluate(ast)
  end

  def test_count_with_and_without_predicate
    count_ast = @parser.parse("(count (list 1 2 3))").first
    count_filtered_ast = @parser.parse("(count (lambda (x) (> x 1)) (list 1 2 3))").first

    assert_equal BigDecimal("3"), @executer.evaluate(count_ast)
    assert_equal BigDecimal("2"), @executer.evaluate(count_filtered_ast)
  end
end
