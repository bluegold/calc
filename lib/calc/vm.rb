module Calc
  # Stack-based virtual machine for executing Calc bytecode.
  # Phase 2 supports a safe subset (literals, symbol load, builtin function call).
  class Vm
    def initialize(executer:, builtins:)
      @executer = executer
      @builtins = builtins
    end

    # Executes a compiled CodeObject and returns the top value of the stack.
    def run(code)
      stack = []

      code.instructions.each do |instruction|
        execute_instruction(instruction, stack)
      end

      stack.last
    end

    private

    def execute_instruction(instruction, stack)
      case instruction.op
      when :push_const
        stack << instruction.a
      when :push_keyword
        stack << ":#{instruction.a}"
      when :load
        stack << @executer.send(:resolve_symbol_name, instruction.a)
      when :load_fn
        stack << [:builtin, instruction.a]
      when :call
        args = stack.pop(instruction.a)
        callable = stack.pop
        stack << call(callable, args)
      when :pop
        stack.pop
      else
        raise Calc::RuntimeError, "unsupported opcode in vm phase2: #{instruction.op}"
      end
    end

    def call(callable, args)
      case callable
      when Array
        call_builtin(callable, args)
      when LambdaValue
        @executer.send(:call_lambda, callable, args)
      else
        raise Calc::NameError, "expected a function"
      end
    end

    def call_builtin(callable, args)
      type, name = callable
      raise Calc::NameError, "expected a function" unless type == :builtin

      callable_runner = proc { |value_callable, values| @executer.send(:call_value_callable, value_callable, values) }
      @builtins.call(name, args, &callable_runner)
    end
  end
end
