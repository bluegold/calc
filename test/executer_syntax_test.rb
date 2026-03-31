require_relative "test_helper"

class ExecuterSyntaxTest < Minitest::Test
  def setup
    @parser = Calc::Parser.new
  end

  def evaluate_in_mode(source, mode)
    executer = Calc::Executer.new(Calc::Environment.new, Calc::Builtins.new, Calc::NamespaceRegistry.new,
                                  execution_mode: mode)
    executer.evaluate(@parser.parse(source).first)
  end

  def assert_syntax_error(source, message_fragment)
    %w[tree vm].each do |mode|
      error = assert_raises(Calc::SyntaxError) { evaluate_in_mode(source, mode) }
      assert_includes error.message, message_fragment
    end
  end

  def test_define_variable_rejects_extra_expressions
    assert_syntax_error("(define x 1 2)", "invalid define: expected (define name value)")
  end

  def test_if_requires_condition_then_and_else
    assert_syntax_error("(if true 1)", "invalid if: expected (if condition then-expr else-expr)")
  end

  def test_cond_requires_two_element_clauses
    assert_syntax_error("(cond (true 1 2) (else 3))", "invalid cond: each clause must be (test expr)")
  end

  def test_cond_requires_else_to_be_last_clause
    assert_syntax_error("(cond (else 1) (true 2))", "invalid cond: else must be the last clause")
  end
end
