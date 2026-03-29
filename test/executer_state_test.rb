require_relative "test_helper"
require "bigdecimal"

class ExecuterStateTest < Minitest::Test
  def setup
    @executer = Calc::Executer.new
    @parser = Calc::Parser.new
  end

  def test_wrong_lambda_arity_does_not_corrupt_executor_state
    @executer.evaluate(@parser.parse("(define add (lambda (x) (lambda (y) (+ x y))))").first)

    assert_raises(Calc::RuntimeError) do
      @executer.evaluate(@parser.parse("(add 2 3)").first)
    end

    assert_includes @executer.completion_candidates, "add"
    assert_equal BigDecimal("5"), @executer.evaluate(@parser.parse("((add 2) 3)").first)
  end
end
