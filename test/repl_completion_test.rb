require_relative "test_helper"

class ReplCompletionTest < Minitest::Test
  def setup
    @completion = Calc::ReplCompletion.new(Calc::Builtins.new)
  end

  def test_completes_repl_commands_at_head
    line = ":he"

    assert_equal [":help"], @completion.candidates(":he", line, line.length)
  end

  def test_completes_bytecode_command_at_head
    line = ":by"

    assert_equal [":bytecode"], @completion.candidates(":by", line, line.length)
  end

  def test_completes_trace_vm_command_at_head
    line = ":tr"

    assert_equal [":trace-vm"], @completion.candidates(":tr", line, line.length)
  end

  def test_does_not_suggest_commands_in_expression_context
    line = "(hash :he"

    refute_includes @completion.candidates(":he", line, line.length), ":help"
  end

  def test_completes_builtin_names
    line = "(stri"

    assert_includes @completion.candidates("stri", line, line.length), "stringify-json"
  end

  def test_completes_literal_names
    line = "tr"

    assert_equal ["true"], @completion.candidates("tr", line, line.length)
  end

  def test_handles_symbolic_builtin_prefix
    line = "(+"

    assert_equal ["+"], @completion.candidates("+", line, line.length)
  end

  def test_uses_symbol_candidates_provider_when_given
    completion = Calc::ReplCompletion.new(
      Calc::Builtins.new,
      symbol_candidates_provider: -> { ["square", "crypto.twice"] }
    )

    assert_equal ["square"], completion.candidates("sq", "(sq", 3)
  end

  def test_passes_active_namespace_to_symbol_candidates_provider
    captured_namespace = nil
    completion = Calc::ReplCompletion.new(
      Calc::Builtins.new,
      symbol_candidates_provider: lambda { |namespace_path|
        captured_namespace = namespace_path
        ["twice"]
      }
    )

    line = "(namespace crypto (tw"

    assert_equal ["twice"], completion.candidates("tw", line, line.length)
    assert_equal "crypto", captured_namespace
  end
end
