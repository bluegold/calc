require_relative "test_helper"
require "bigdecimal"

class CompilerTest < Minitest::Test
  def setup
    @parser = Calc::Parser.new
    @compiler = Calc::Compiler.new(Calc::Builtins.new)
  end

  def compile(source, name: "<expr>")
    @compiler.compile(@parser.parse(source).first, name: name)
  end

  def instruction_ops(code)
    code.instructions.map(&:op)
  end

  def test_compile_literal_expression
    code = compile("42")

    assert_equal [:push_const], instruction_ops(code)
    assert_equal BigDecimal("42"), code.instructions.first.a
  end

  def test_compile_function_call_uses_load_fn_then_call
    code = compile("(+ 1 2)")

    assert_equal %i[load_fn push_const push_const call], instruction_ops(code)
    assert_equal "+", code.instructions.first.a
    assert_equal 2, code.instructions.last.a
  end

  def test_compile_program_discards_intermediate_results
    nodes = @parser.parse("(define x 1) (+ x 2)")
    code = @compiler.compile_program(nodes, name: "sample")

    assert_equal %i[push_const store pop load_fn load push_const call], instruction_ops(code)
    assert_equal "sample", code.name
  end

  def test_compile_if_requires_else_branch
    error = assert_raises(Calc::SyntaxError) do
      compile("(if true 1)")
    end

    assert_includes error.message, "invalid if"
  end

  def test_compile_and_preserves_last_value_shape
    code = compile("(and true 1 2)")

    assert_equal %i[push_const dup jump_false pop push_const dup jump_false pop push_const], instruction_ops(code)
  end

  def test_compile_or_preserves_first_truthy_value_shape
    code = compile("(or false 1 2)")
    expected = %i[
      push_const dup jump_false jump pop push_const dup jump_false
      jump pop push_const dup jump_true pop push_const
    ]

    assert_equal expected, instruction_ops(code)
  end

  def test_compile_lambda_embeds_parameter_metadata
    code = compile("(lambda (x) (+ x 1))")
    closure_meta = code.instructions.first.a

    assert_equal [:make_closure], instruction_ops(code)
    assert_equal ["x"], closure_meta[:params]
  end

  def test_compile_lambda_embeds_body_code_object
    code = compile("(lambda (x) (+ x 1))")
    closure_meta = code.instructions.first.a

    assert_instance_of Calc::Bytecode::CodeObject, closure_meta[:code]
    assert_equal %i[load_fn load push_const call], instruction_ops(closure_meta[:code])
  end

  def test_disassemble_includes_name_and_line_information
    code = compile("(+ 1 2)", name: "math")
    disassembly = code.disassemble

    assert_includes disassembly, "=== math ==="
    assert_includes disassembly, "0000  load_fn \"+\" ; L1"
  end
end
