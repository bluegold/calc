module Calc
  # Stack-based virtual machine for executing Calc bytecode.
  # Phase 2 supports a safe subset (literals, symbol load, builtin function call).
  class Vm
    def initialize(executer:, builtins:, trace_enabled: false, trace_io: $stderr)
      @executer = executer
      @builtins = builtins
      @trace_enabled = trace_enabled
      @trace_io = trace_io
    end

    # Executes a compiled CodeObject and returns the top value of the stack.
    def run(code)
      stack = []

      ip = 0
      namespace_frames = []

      trace_header(code)

      while ip < code.instructions.length
        instruction = code.instructions[ip]
        stack_before = stack.dup
        next_ip = execute_instruction(instruction, stack, namespace_frames, ip)
        trace_instruction(code, ip, instruction, stack_before, stack, next_ip)
        ip = next_ip
      end

      trace_footer(stack.last)
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

    def trace_header(code)
      return unless @trace_enabled

      @trace_io.puts("=== VM trace #{code.name || '<expr>'} ===")
    end

    # rubocop:disable Metrics/ParameterLists
    def trace_instruction(code, ip, instruction, stack_before, stack_after, next_ip)
      return unless @trace_enabled

      @trace_io.puts(
        format(
          "%<name>s ip=%<ip>04d op=%<op>s arg=%<arg>s next=%<next>04d stack_before=%<before>s stack_after=%<after>s",
          name: code.name || "<expr>",
          ip: ip,
          op: instruction.op,
          arg: format_trace_operand(instruction.a),
          next: next_ip,
          before: format_trace_stack(stack_before),
          after: format_trace_stack(stack_after)
        )
      )
    end
    # rubocop:enable Metrics/ParameterLists

    def trace_footer(result)
      return unless @trace_enabled

      @trace_io.puts("=> #{format_trace_value(result)}")
    end

    def format_trace_stack(values)
      "[#{values.map { |value| format_trace_value(value) }.join(', ')}]"
    end

    def format_trace_operand(value)
      value.nil? ? "-" : format_trace_value(value)
    end

    def format_trace_value(value)
      case value
      when LambdaValue
        "<lambda params=#{value.params.inspect}>"
      when Array
        format_trace_array(value)
      when Hash, String
        value.inspect
      else
        Calc.format_value(value)
      end
    end

    def format_trace_array(value)
      return "<builtin #{value[1]}>" if value.length == 2 && value[0] == :builtin

      "[#{value.map { |item| format_trace_value(item) }.join(', ')}]"
    end
  end
end
