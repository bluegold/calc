require_relative "test_helper"
require "bigdecimal"

class Phase0SemanticLockTest < Minitest::Test
  def setup
    @executer = Calc::Executer.new
    @parser = Calc::Parser.new
  end

  def eval_expr(source)
    @executer.evaluate(@parser.parse(source).first)
  end

  def test_if_requires_else_branch
    error = assert_raises(Calc::SyntaxError) { eval_expr("(if true 1)") }

    assert_includes error.message, "invalid if"
  end

  def test_and_with_no_operands_returns_true
    assert_equal true, eval_expr("(and)")
  end

  def test_or_with_no_operands_returns_false
    assert_equal false, eval_expr("(or)")
  end

  def test_and_returns_first_falsey_value_not_booleanized
    assert_nil eval_expr("(and true nil 10)")
  end

  def test_or_returns_first_truthy_value_not_booleanized
    assert_equal BigDecimal("0"), eval_expr("(or false 0 10)")
  end

  def test_cond_with_no_match_returns_nil
    assert_nil eval_expr("(cond (false 1) (nil 2))")
  end

  def test_cond_else_must_be_last
    error = assert_raises(Calc::SyntaxError) { eval_expr("(cond (else 1) (true 2))") }

    assert_includes error.message, "invalid cond"
  end
end
