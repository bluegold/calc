module Calc
  # Tracks the lifecycle of a debugger session.
  # The state machine is intentionally small so pause/resume semantics can be
  # expanded without entangling UI code.
  class DebuggerState
    VALID_STATES = %i[idle running paused terminated].freeze

    attr_reader :state, :pause_reason

    def initialize(state: :idle, pause_reason: nil)
      @state = validate_state(state)
      @pause_reason = validate_pause_reason(pause_reason)
    end

    def idle?
      @state == :idle
    end

    def running?
      @state == :running
    end

    def paused?
      @state == :paused
    end

    def terminated?
      @state == :terminated
    end

    def start!
      transition_to(:running)
    end

    def pause!(reason:)
      raise ArgumentError, "paused debugger state requires a pause reason" if reason.nil?

      transition_to(:paused)
      @pause_reason = reason
      self
    end

    def resume!
      transition_to(:running)
    end

    def terminate!
      transition_to(:terminated)
    end

    private

    def transition_to(new_state)
      validate_transition!(new_state)
      @state = new_state
      @pause_reason = nil unless new_state == :paused
      self
    end

    def validate_state(state)
      return state if VALID_STATES.include?(state)

      raise ArgumentError, "invalid debugger state: #{state.inspect}"
    end

    def validate_pause_reason(pause_reason)
      if @state == :paused
        raise ArgumentError, "paused debugger state requires a pause reason" if pause_reason.nil?

        return pause_reason
      end

      nil
    end

    def validate_transition!(new_state)
      return if new_state == @state

      allowed = {
        idle: %i[running terminated],
        running: %i[paused terminated],
        paused: %i[running terminated],
        terminated: []
      }.fetch(@state)

      return if allowed.include?(new_state)

      raise ArgumentError, "invalid debugger transition: #{@state} -> #{new_state}"
    end
  end
end
