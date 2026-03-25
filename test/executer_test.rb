require_relative "test_helper"
require "bigdecimal"

class ExecuterTest < Minitest::Test
  def setup
    @environment = Calc::Environment.new
    @executer = Calc::Executer.new(@environment)
    @parser = Calc::Parser.new
  end

  def test_addition
    ast = @parser.parse("(+ 1 2 3)").first

    assert_equal BigDecimal("6"), @executer.evaluate(ast)
  end

  def test_variable_definition
    define_ast = @parser.parse("(define x 7)").first
    use_ast = @parser.parse("(+ x 2)").first

    assert_equal BigDecimal("7"), @executer.evaluate(define_ast)
    assert_equal BigDecimal("9"), @executer.evaluate(use_ast)
  end

  def test_unknown_variable_raises
    ast = @parser.parse("x").first

    error = assert_raises(NameError) { @executer.evaluate(ast) }
    assert_match "unknown variable", error.message
  end

  def test_reserved_literals_cannot_be_redefined
    error = assert_raises(NameError) { @executer.evaluate(@parser.parse("(define true 1)").first) }

    assert_match "cannot redefine reserved literal", error.message
  end

  def test_if_evaluates_then_branch_for_truthy_values
    ast = @parser.parse("(if true 1 2)").first

    assert_equal BigDecimal("1"), @executer.evaluate(ast)
  end

  def test_if_evaluates_else_branch_for_false
    ast = @parser.parse("(if false 1 2)").first

    assert_equal BigDecimal("2"), @executer.evaluate(ast)
  end

  def test_if_does_not_evaluate_unselected_branch
    ast = @parser.parse("(if true 1 unknown)").first

    assert_equal BigDecimal("1"), @executer.evaluate(ast)
  end
end
