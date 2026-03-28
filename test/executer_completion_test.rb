require_relative "test_helper"

class ExecuterCompletionTest < Minitest::Test
  def setup
    @executer = Calc::Executer.new
    @parser = Calc::Parser.new
  end

  def test_completion_candidates_include_defined_function
    @executer.evaluate(@parser.parse("(define (square x) (* x x))").first)

    assert_includes @executer.completion_candidates, "square"
  end

  def test_completion_candidates_include_qualified_namespace_function
    @executer.evaluate(@parser.parse("(namespace crypto (define (twice x) (+ x x)))").first)

    assert_includes @executer.completion_candidates, "crypto.twice"
  end

  def test_completion_candidates_exclude_unqualified_namespace_function
    @executer.evaluate(@parser.parse("(namespace crypto (define (twice x) (+ x x)))").first)

    refute_includes @executer.completion_candidates, "twice"
  end

  def test_completion_candidates_exclude_unqualified_namespace_variable
    @executer.evaluate(@parser.parse("(namespace crypto (define answer 42))").first)

    refute_includes @executer.completion_candidates, "answer"
    assert_includes @executer.completion_candidates, "crypto.answer"
  end

  def test_completion_candidates_include_unqualified_symbols_for_active_namespace
    @executer.evaluate(@parser.parse("(namespace crypto (define answer 42) (define (twice x) (+ x x)))").first)

    candidates = @executer.completion_candidates(namespace_path: "crypto")

    assert_includes candidates, "answer"
    assert_includes candidates, "twice"
  end

  def test_completion_candidates_exclude_ancestor_local_symbols
    @executer.evaluate(@parser.parse("(namespace crypto (define _secret 9) (namespace inner 0))").first)

    candidates = @executer.completion_candidates(namespace_path: "crypto.inner")

    refute_includes candidates, "_secret"
  end

  def test_completion_candidates_fall_back_to_existing_parent_namespace
    @executer.evaluate(@parser.parse("(namespace crypto (define shared 3) 0)").first)

    candidates = @executer.completion_candidates(namespace_path: "crypto.future")

    assert_includes candidates, "shared"
  end

  def test_completion_candidates_include_special_forms
    candidates = @executer.completion_candidates

    assert_includes candidates, "define"
    assert_includes candidates, "load"
  end
end
