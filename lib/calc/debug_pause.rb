module Calc
  # Raised by the VM when debugger execution should pause.
  class DebugPause < StandardError
    attr_reader :reason, :code, :ip, :instruction

    def initialize(reason:, code:, ip:, instruction:)
      @reason = reason
      @code = code
      @ip = ip
      @instruction = instruction
      super("debugger paused: #{reason}")
    end
  end
end
