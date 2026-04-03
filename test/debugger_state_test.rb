require_relative "test_helper"

class DebuggerStateTest < Minitest::Test
  def test_defaults_to_idle
    state = Calc::DebuggerState.new

    assert_predicate state, :idle?
    refute_predicate state, :running?
    assert_nil state.pause_reason
  end

  def test_non_paused_state_clears_pause_reason_on_initialize
    state = Calc::DebuggerState.new(state: :running, pause_reason: :breakpoint)

    assert_predicate state, :running?
    assert_nil state.pause_reason
  end

  def test_paused_state_requires_pause_reason
    error = assert_raises(ArgumentError) do
      Calc::DebuggerState.new(state: :paused)
    end

    assert_includes error.message, "requires a pause reason"
  end

  def test_start_transitions_to_running
    state = Calc::DebuggerState.new

    assert_same state, state.start!
    assert_predicate state, :running?
  end

  def test_pause_transitions_to_paused
    state = Calc::DebuggerState.new.start!

    assert_same state, state.pause!(reason: :breakpoint)
    assert_predicate state, :paused?
    assert_equal :breakpoint, state.pause_reason
  end

  def test_pause_requires_reason
    state = Calc::DebuggerState.new.start!

    error = assert_raises(ArgumentError) do
      state.pause!(reason: nil)
    end

    assert_includes error.message, "requires a pause reason"
  end

  def test_resume_transitions_to_running
    state = Calc::DebuggerState.new(state: :paused, pause_reason: :step)

    assert_same state, state.resume!
    assert_predicate state, :running?
    assert_nil state.pause_reason
  end

  def test_terminate_transitions_to_terminated
    state = Calc::DebuggerState.new(state: :paused, pause_reason: :breakpoint)

    assert_same state, state.terminate!
    assert_predicate state, :terminated?
    assert_nil state.pause_reason
  end

  def test_failed_pause_does_not_mutate_reason
    state = Calc::DebuggerState.new(state: :terminated, pause_reason: :step)

    assert_raises(ArgumentError) do
      state.pause!(reason: :breakpoint)
    end

    assert_nil state.pause_reason
  end

  def test_rejects_invalid_transition
    state = Calc::DebuggerState.new(state: :terminated)

    error = assert_raises(ArgumentError) do
      state.resume!
    end

    assert_includes error.message, "invalid debugger transition"
  end
end
