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

      ip = 0
      namespace_frames = []

      while ip < code.instructions.length
        instruction = code.instructions[ip]
        ip = execute_instruction(instruction, stack, namespace_frames, ip)
      end

      stack.last
    ensure
      namespace_frames.reverse_each do |previous_namespace|
        @executer.send(:leave_runtime_namespace, previous_namespace)
      end
    end

    private

    # rubocop:disable Metrics/CyclomaticComplexity
    def execute_instruction(instruction, stack, namespace_frames, ip)
      case instruction.op
      when :push_const
        push_const(stack, instruction.a)
      when :push_keyword
        push_keyword(stack, instruction.a)
      when :load
        load_symbol(stack, instruction.a)
      when :load_fn
        load_function(stack, instruction.a)
      when :store
        store_variable(stack, instruction.a)
      when :store_fn
        store_function(stack, instruction.a)
      when :make_closure
        make_closure_value(stack, instruction.a)
      when :call
        invoke_callable(stack, instruction.a)
      when :pop
        stack.pop
      when :dup
        stack << stack.last
      when :jump
        return jump(instruction.a)
      when :jump_false
        target = jump_false(stack, instruction.a)
        return target if target
      when :jump_true
        target = jump_true(stack, instruction.a)
        return target if target
      when :enter_ns
        enter_namespace(namespace_frames, instruction.a)
      when :leave_ns
        leave_namespace(namespace_frames)
      when :load_file
        load_file_value(stack, instruction.a)
      else
        raise Calc::RuntimeError, "unsupported opcode in vm phase3: #{instruction.op}"
      end

      ip + 1
    end
    # rubocop:enable Metrics/CyclomaticComplexity

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

    def push_const(stack, value)
      stack << value
    end

    def push_keyword(stack, value)
      stack << ":#{value}"
    end

    def load_symbol(stack, name)
      stack << @executer.send(:resolve_symbol_name, name)
    end

    def load_function(stack, name)
      stack << @executer.send(:resolve_callable_name, name)
    end

    def store_variable(stack, name)
      stack << @executer.send(:define_runtime_variable, name, stack.last)
    end

    def store_function(stack, name)
      stack << @executer.send(:define_runtime_function, name, stack.pop)
    end

    def make_closure_value(stack, metadata)
      stack << make_closure(metadata)
    end

    def invoke_callable(stack, argc)
      args = stack.pop(argc)
      callable = stack.pop
      stack << call(callable, args)
    end

    def jump(target)
      target
    end

    def jump_false(stack, target)
      condition = stack.pop
      truthy?(condition) ? nil : target
    end

    def jump_true(stack, target)
      condition = stack.pop
      truthy?(condition) ? target : nil
    end

    def enter_namespace(namespace_frames, name)
      namespace_frames << @executer.send(:enter_runtime_namespace, name)
    end

    def leave_namespace(namespace_frames)
      previous_namespace = namespace_frames.pop
      @executer.send(:leave_runtime_namespace, previous_namespace)
    end

    def load_file_value(stack, metadata)
      stack << load_file(metadata)
    end

    def make_closure(metadata)
      params = metadata.fetch(:params)
      ast_body = metadata.fetch(:ast_body)
      code_body = metadata.fetch(:code)
      @executer.send(:build_runtime_lambda, params, body_node: ast_body, code_body: code_body)
    end

    def truthy?(value)
      value != false && !value.nil?
    end

    def load_file(metadata)
      @executer.send(:load_runtime_file, metadata.fetch(:path), namespace: metadata[:namespace])
    end
  end
end
