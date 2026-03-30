require_relative "test_helper"
require "bigdecimal"
require "fileutils"
require "stringio"
require "tmpdir"

class ExecuterVmTest < Minitest::Test
  def setup
    @parser = Calc::Parser.new
    @executer = Calc::Executer.new(
      Calc::Environment.new,
      Calc::Builtins.new,
      Calc::NamespaceRegistry.new,
      execution_mode: "vm"
    )
  end

  def test_vm_mode_evaluates_arithmetic_function_call
    ast = @parser.parse("(+ 1 2 3)").first

    assert_equal BigDecimal("6"), @executer.evaluate(ast)
  end

  def test_vm_mode_evaluates_nested_builtin_calls
    ast = @parser.parse("(+ (* 2 3) 4)").first

    assert_equal BigDecimal("10"), @executer.evaluate(ast)
  end

  def test_vm_mode_falls_back_to_tree_walk_for_special_forms
    ast = @parser.parse("(if true 1 2)").first

    assert_equal BigDecimal("1"), @executer.evaluate(ast)
  end

  def test_vm_mode_can_resolve_symbols_from_environment
    @executer.evaluate(@parser.parse("(define x 10)").first)

    ast = @parser.parse("(+ x 5)").first

    assert_equal BigDecimal("15"), @executer.evaluate(ast)
  end

  def test_vm_mode_evaluates_if_without_touching_unselected_branch
    ast = @parser.parse("(if true 1 unknown)").first

    assert_equal BigDecimal("1"), @executer.evaluate(ast)
  end

  def test_vm_mode_evaluates_and_or_and_cond
    and_ast = @parser.parse("(and true 1 2)").first
    or_ast = @parser.parse("(or false nil 7)").first
    cond_ast = @parser.parse("(cond ((> 2 3) 10) ((< 2 3) 20) (else 30))").first

    assert_equal BigDecimal("2"), @executer.evaluate(and_ast)
    assert_equal BigDecimal("7"), @executer.evaluate(or_ast)
    assert_equal BigDecimal("20"), @executer.evaluate(cond_ast)
  end

  def test_vm_mode_evaluates_define_function_and_lambda_call
    define_ast = @parser.parse("(define (inc x) (+ x 1))").first
    call_ast = @parser.parse("(inc 4)").first
    immediate_lambda_ast = @parser.parse("((lambda (x) (+ x 2)) 3)").first

    assert_equal "defined function inc(x)", @executer.evaluate(define_ast)
    assert_equal BigDecimal("5"), @executer.evaluate(call_ast)
    assert_equal BigDecimal("5"), @executer.evaluate(immediate_lambda_ast)
  end

  def test_vm_mode_evaluates_do_blocks
    ast = @parser.parse("(do (define x 10) (define y 5) (+ x y))").first

    assert_equal BigDecimal("15"), @executer.evaluate(ast)
  end

  def test_vm_mode_evaluates_namespace_blocks
    ast = @parser.parse("(namespace crypto (define shared 5) (define (twice x) (+ x shared)) (twice 3))").first
    call_ast = @parser.parse("(crypto.twice 4)").first

    assert_equal BigDecimal("8"), @executer.evaluate(ast)
    assert_equal BigDecimal("9"), @executer.evaluate(call_ast)
  end

  def test_vm_mode_loads_files
    Dir.mktmpdir do |dir|
      path = File.join(dir, "math.calc")
      File.write(path, "(define (inc x) (+ x 1))\n")

      result = @executer.evaluate_source(%((do (load "#{path}") (inc 4))))

      assert_equal BigDecimal("5"), result
    end
  end

  def test_vm_mode_load_supports_as_namespace_with_symbol
    Dir.mktmpdir do |dir|
      path = File.join(dir, "math.calc")
      File.write(path, "(define (inc x) (+ x 1))\n")

      result = @executer.evaluate_source(%((do (load "#{path}" :as tools) (tools.inc 4))))

      assert_equal BigDecimal("5"), result
    end
  end

  def test_vm_trace_mode_writes_instruction_trace
    trace = StringIO.new
    executer = Calc::Executer.new(
      Calc::Environment.new,
      Calc::Builtins.new,
      Calc::NamespaceRegistry.new,
      execution_mode: "vm",
      vm_trace: true,
      vm_trace_io: trace
    )

    ast = @parser.parse("(+ 1 2)").first

    assert_equal BigDecimal("3"), executer.evaluate(ast)
    assert_includes trace.string, "=== VM trace <expr> ==="
    assert_includes trace.string, "op=load_fn"
  end

  def test_vm_trace_mode_includes_stack_and_result
    trace = StringIO.new
    executer = Calc::Executer.new(
      Calc::Environment.new,
      Calc::Builtins.new,
      Calc::NamespaceRegistry.new,
      execution_mode: "vm",
      vm_trace: true,
      vm_trace_io: trace
    )

    ast = @parser.parse("(+ 1 2)").first

    executer.evaluate(ast)

    assert_includes trace.string, "=== VM trace <expr> ==="
    assert_includes trace.string, "stack_after=[<builtin +>]"
    assert_includes trace.string, "=> 3"
  end
end
