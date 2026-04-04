require_relative "test_helper"

class DebugCompletionTest < Minitest::Test
  def test_candidates_for_debug_commands
    completion = Calc::Cli::DebugCompletion.new

    candidates = completion.candidates("co", "co", 2)

    assert_includes candidates, "continue"
    refute_includes candidates, "quit"
  end

  def test_candidates_ignore_non_command_context
    completion = Calc::Cli::DebugCompletion.new

    candidates = completion.candidates("x", "(+ x 1)", 3)

    assert_empty candidates
  end

  def test_candidates_do_not_crash_on_nil_cursor_context
    completion = Calc::Cli::DebugCompletion.new

    candidates = completion.candidates("x", "x", 0)

    assert_empty candidates
  end
end
