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
end
