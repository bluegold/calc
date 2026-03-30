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
end
