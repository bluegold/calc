require_relative "test_helper"
require "bigdecimal"

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
end
