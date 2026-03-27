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

  def test_string_literal_evaluates_to_string
    ast = @parser.parse("\"hello\"").first

    assert_equal "hello", @executer.evaluate(ast)
  end

  def test_lambda_returns_callable_value
    ast = @parser.parse("(lambda (x) (+ x 1))").first

    value = @executer.evaluate(ast)

    assert_instance_of Calc::LambdaValue, value
    assert_equal ["x"], value.params
  end

  def test_lambda_can_be_called_directly
    ast = @parser.parse("((lambda (x) (+ x 1)) 4)").first

    assert_equal BigDecimal("5"), @executer.evaluate(ast)
  end

  def test_define_uses_lambda_sugar
    ast = @parser.parse("(define (square x) (* x x))").first

    assert_equal "defined function square(x)", @executer.evaluate(ast)
    assert_equal BigDecimal("16"), @executer.evaluate(@parser.parse("(square 4)").first)
  end

  def test_lambda_closes_over_local_environment
    ast = @parser.parse("(do (define x 10) (define f (lambda (y) (+ x y))) (define x 20) (f 5))").first

    assert_equal BigDecimal("15"), @executer.evaluate(ast)
  end

  def test_map_applies_lambda_to_each_item
    ast = @parser.parse("(map (lambda (x) (+ x 1)) (list 1 2 3))").first

    assert_equal [BigDecimal("2"), BigDecimal("3"), BigDecimal("4")], @executer.evaluate(ast)
  end

  def test_reduce_accumulates_values
    ast = @parser.parse("(reduce (lambda (memo x) (+ memo x)) 0 (list 1 2 3))").first

    assert_equal BigDecimal("6"), @executer.evaluate(ast)
  end

  def test_select_filters_values
    ast = @parser.parse("(select (lambda (x) (> x 1)) (list 1 2 3))").first

    assert_equal [BigDecimal("2"), BigDecimal("3")], @executer.evaluate(ast)
  end

  def test_reports_unknown_function_with_expression_context
    ast = @parser.parse("(do (define x 10)(define f (lambda (y) (missing y)))(define x 20)(f 5))").first

    error = assert_raises(Calc::NameError) { @executer.evaluate(ast) }

    assert_match "unknown function: missing", error.message
    assert_match "while evaluating", error.message
  end

  def test_division_by_zero_raises_custom_error
    ast = @parser.parse("(/ 8 0)").first

    error = assert_raises(Calc::DivisionByZeroError) { @executer.evaluate(ast) }
    assert_equal "division by zero", error.message
  end

  def test_variable_definition
    define_ast = @parser.parse("(define x 7)").first
    use_ast = @parser.parse("(+ x 2)").first

    assert_equal BigDecimal("7"), @executer.evaluate(define_ast)
    assert_equal BigDecimal("9"), @executer.evaluate(use_ast)
  end

  def test_unknown_variable_raises
    ast = @parser.parse("x").first

    error = assert_raises(Calc::NameError) { @executer.evaluate(ast) }
    assert_match "unknown variable", error.message
  end

  def test_reserved_literals_cannot_be_redefined
    error = assert_raises(Calc::NameError) { @executer.evaluate(@parser.parse("(define true 1)").first) }

    assert_match "cannot redefine reserved literal", error.message
  end

  def test_builtin_namespace_is_reserved
    error = assert_raises(Calc::NameError) { @executer.evaluate(@parser.parse("(namespace builtin (define x 1))").first) }

    assert_match "cannot modify reserved namespace", error.message
  end

  def test_builtin_allows_nested_namespaces
    ast = @parser.parse("(namespace builtin (namespace crypto (define x 1)))").first

    assert_equal BigDecimal("1"), @executer.evaluate(ast)
    assert_equal BigDecimal("1"),
                 @executer.instance_variable_get(:@namespaces).resolve_variable("builtin.crypto", "x")[:value]
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

  def test_namespace_keeps_defined_variables
    ast = @parser.parse("(namespace crypto (define _tmp 7))").first

    assert_equal BigDecimal("7"), @executer.evaluate(ast)
    assert_equal BigDecimal("7"),
                 @executer.instance_variable_get(:@namespaces).resolve_variable("crypto", "_tmp")[:value]
  end

  def test_namespace_nested_dotted_path
    ast = @parser.parse("(namespace crypto.cipher (define _tmp 3))").first

    assert_equal BigDecimal("3"), @executer.evaluate(ast)
    assert_equal BigDecimal("3"),
                 @executer.instance_variable_get(:@namespaces).resolve_variable("crypto.cipher", "_tmp")[:value]
  end

  def test_defines_and_calls_user_functions
    define_ast = @parser.parse("(define (square x) (* x x))").first
    call_ast = @parser.parse("(square 4)").first

    assert_equal "defined function square(x)", @executer.evaluate(define_ast)
    assert_equal BigDecimal("16"), @executer.evaluate(call_ast)
  end

  def test_user_function_can_see_namespace_variable
    ast = @parser.parse("(namespace crypto (define shared 5) (define (twice x) (+ x shared)) (twice 3))").first

    assert_equal BigDecimal("8"), @executer.evaluate(ast)
  end

  def test_can_call_namespaced_function_with_qualified_name
    ast = @parser.parse("(namespace crypto (define (twice x) (+ x x)))").first
    call_ast = @parser.parse("(crypto.twice 4)").first

    @executer.evaluate(ast)
    assert_equal BigDecimal("8"), @executer.evaluate(call_ast)
  end

  def test_builtin_function_is_not_shadowed_by_namespace_function_call
    ast = @parser.parse("(namespace crypto (define (pow x y) (* x y)))").first
    call_ast = @parser.parse("(pow 2 3)").first

    @executer.evaluate(ast)
    assert_equal BigDecimal("8"), @executer.evaluate(call_ast)
  end

  def test_plain_symbol_prefers_variable_over_function
    ast = @parser.parse("(namespace crypto (define twice 7) (define (twice x) (+ x x)) twice)").first

    assert_equal BigDecimal("7"), @executer.evaluate(ast)
  end

  def test_builtin_function_is_not_shadowed_by_local_variable
    ast = @parser.parse("(do (define pow 7) (pow 2 3))").first

    assert_equal BigDecimal("8"), @executer.evaluate(ast)
  end

  def test_namespace_local_variable_does_not_leak_to_root
    ast = @parser.parse("(namespace crypto (define _tmp 5))").first

    @executer.evaluate(ast)
    error = assert_raises(Calc::NameError) { @executer.evaluate(@parser.parse("_tmp").first) }
    assert_match "unknown variable", error.message
  end

  def test_function_parameter_beats_namespace_binding
    ast = @parser.parse("(namespace crypto (define x 10) (define (echo x) x) (echo 4))").first

    assert_equal BigDecimal("4"), @executer.evaluate(ast)
  end

  def test_recursive_fibonacci_function
    ast = @parser.parse("(define (fib n) (if (<= n 1) n (+ (fib (- n 1)) (fib (- n 2)))))").first
    call_ast = @parser.parse("(fib 10)").first

    @executer.evaluate(ast)
    assert_equal BigDecimal("55"), @executer.evaluate(call_ast)
  end

  def test_namespaced_recursive_fibonacci_function
    ast = @parser.parse("(namespace crypto (define (fib n) (if (<= n 1) n (+ (fib (- n 1)) (fib (- n 2))))) (fib 10))").first

    assert_equal BigDecimal("55"), @executer.evaluate(ast)
  end
end
