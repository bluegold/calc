require_relative "test_helper"
require "stringio"

class ReplCommandHandlerTest < Minitest::Test
  def setup
    @parser = Calc::Parser.new
    @builtins = Calc::Builtins.new
    @out = StringIO.new
    @err = StringIO.new
    @handler = Calc::Cli::ReplCommandHandler.new(
      parser: @parser,
      builtins: @builtins,
      out: @out,
      err: @err
    )
  end

  def test_handles_bytecode_command_and_prints_disassembly_header
    handled = @handler.handle(":bytecode (+ 1 2)")

    assert handled
    assert_includes @out.string, "=== <repl> ==="
  end

  def test_handles_bytecode_command_and_includes_instruction
    @handler.handle(":bytecode (+ 1 2)")

    assert_includes @out.string, "load_fn \"+\""
  end

  def test_handles_bytecode_command_without_errors
    @handler.handle(":bytecode (+ 1 2)")

    assert_empty @err.string
  end

  def test_help_lists_bytecode_command
    handled = @handler.handle(":help")

    assert handled
    assert_includes @out.string, ":bytecode <expr>"
  end
end
