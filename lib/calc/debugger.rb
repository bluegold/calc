module Calc
  # Minimal debugger hook target used by the VM.
  class Debugger
    def initialize(breakpoints: [])
      @breakpoints = breakpoints
    end

    def pause_reason_for(code, ip, instruction, stack)
      breakpoint_hit_reason(code, ip, instruction, stack)
    end

    private

    def breakpoint_hit_reason(_code, _ip, instruction, stack)
      return nil if @breakpoints.empty?

      node_line = instruction.line
      return :breakpoint if node_line && @breakpoints.any? { |breakpoint| breakpoint.line? && breakpoint.target == node_line }

      return nil unless instruction.op == :call

      callee_name = callable_name(stack, instruction.a)
      return nil unless callee_name

      :breakpoint if @breakpoints.any? { |breakpoint| breakpoint.function? && breakpoint.target == callee_name }
    end

    def callable_name(stack, argc)
      callable = stack[-(argc + 1)]

      case callable
      when Array
        callable[1]
      when LambdaValue
        callable.code_body&.name
      end
    end
  end
end
