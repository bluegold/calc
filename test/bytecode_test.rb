require_relative "test_helper"
require "bigdecimal"
require "tmpdir"

class BytecodeTest < Minitest::Test
  def test_save_and_load_roundtrip_preserves_program_behavior
    parser = Calc::Parser.new
    compiler = Calc::Compiler.new(Calc::Builtins.new)
    executer = Calc::Executer.new(execution_mode: "vm")
    code = compiler.compile_program(parser.parse("(+ 1 2 3)"), name: "sum")

    Dir.mktmpdir do |dir|
      bytecode_path = File.join(dir, "sum.calcbc")
      Calc::Bytecode.save(code, bytecode_path)
      loaded = Calc::Bytecode.load(bytecode_path)

      assert_equal "sum", loaded.name
      assert_equal BigDecimal("6"), executer.evaluate_bytecode(loaded)
    end
  end

  # rubocop:disable Minitest/MultipleAssertions
  def test_save_without_debug_and_ast_strips_location_and_ast_body
    parser = Calc::Parser.new
    compiler = Calc::Compiler.new(Calc::Builtins.new)
    code = compiler.compile_program(parser.parse("((lambda (x) (+ x 1)) 4)"), name: "lambda")

    Dir.mktmpdir do |dir|
      bytecode_path = File.join(dir, "lambda.calcbc")
      Calc::Bytecode.save(code, bytecode_path, include_debug: false, include_ast: false)
      loaded = Calc::Bytecode.load(bytecode_path)

      make_closure = loaded.instructions.find { |instruction| instruction.op == :make_closure }

      refute_nil make_closure
      assert_nil make_closure.line
      assert_nil make_closure.column
      refute_includes make_closure.a.keys, :ast_body
    end
  end
  # rubocop:enable Minitest/MultipleAssertions
end
