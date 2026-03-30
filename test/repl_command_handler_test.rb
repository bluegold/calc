require_relative "test_helper"
require "stringio"

class ReplCommandHandlerTest < Minitest::Test
  def setup
    @parser = Calc::Parser.new
    @builtins = Calc::Builtins.new
    @executer = Calc::Executer.new(execution_mode: "vm")
    @out = StringIO.new
    @err = StringIO.new
    @handler = Calc::Cli::ReplCommandHandler.new(
      parser: @parser,
      builtins: @builtins,
      executer: @executer,
      io: { out: @out, err: @err }
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

  def test_help_lists_trace_vm_command
    @handler.handle(":help")

    assert_includes @out.string, ":trace-vm <on|off|status>"
  end

  def test_trace_vm_command_enables_trace
    handled = @handler.handle(":trace-vm on")

    assert handled
    assert_predicate @executer, :vm_trace_enabled?
    assert_includes @out.string, "VM trace: ON"
  end

  def test_trace_vm_command_disables_trace
    @handler.handle(":trace-vm on")
    handled = @handler.handle(":trace-vm off")

    assert handled
    refute_predicate @executer, :vm_trace_enabled?
    assert_includes @out.string, "VM trace: OFF"
  end

  def test_trace_vm_command_reports_status
    handled = @handler.handle(":trace-vm status")

    assert handled
    assert_includes @out.string, "VM trace: OFF"
  end

  def test_trace_vm_command_rejects_invalid_argument
    handled = @handler.handle(":trace-vm maybe")

    refute handled
    assert_includes @err.string, "usage: :trace-vm <on|off|status>"
  end
end
