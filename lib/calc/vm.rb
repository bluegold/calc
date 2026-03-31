module Calc
  # Stack-based virtual machine for executing Calc bytecode.
  # Phase 2 supports a safe subset (literals, symbol load, builtin function call).
  class Vm
    attr_writer :trace_enabled

    def initialize(executer:, builtins:, trace_enabled: false, trace_io: $stderr)
      @executer = executer
      @builtins = builtins
      @trace_enabled = trace_enabled
      @trace_io = trace_io
      @last_loaded_file_trace = nil
    end

    def trace_enabled?
      @trace_enabled
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
      @last_loaded_file_trace = nil

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
      ast_body = metadata[:ast_body]
      code_body = metadata.fetch(:code)
      @executer.send(:build_runtime_lambda, params, body_node: ast_body, code_body: code_body)
    end

    def truthy?(value)
      value != false && !value.nil?
    end

    def load_file(metadata)
      result = @executer.send(:load_runtime_file, metadata.fetch(:path), namespace: metadata[:namespace])
      @last_loaded_file_trace = @executer.send(:consume_last_loaded_file_trace)
      result
    end

    def trace_header(code)
      return unless @trace_enabled

      @trace_io.puts(colorize("=== VM trace #{code.name || '<expr>'} ===", :header))
    end

    # rubocop:disable Metrics/ParameterLists
    def trace_instruction(code, ip, instruction, stack_before, stack_after, next_ip)
      return unless @trace_enabled

      header = format(
        "%<name>s bc[%<ip>04d] %<op>s arg=%<arg>s next=%<next>04d",
        name: code.name || "<expr>",
        ip: ip,
        op: format_trace_op(instruction.op),
        arg: format_trace_operand(instruction.a),
        next: next_ip
      )
      flow = format_trace_flow(instruction, next_ip, ip)
      @trace_io.puts(header)
      @trace_io.puts("    stack: #{format_trace_stack(stack_before)} -> #{format_trace_stack(stack_after)}")
      @trace_io.puts("    flow : #{flow}") if flow
    end
    # rubocop:enable Metrics/ParameterLists

    def trace_footer(result)
      return unless @trace_enabled

      @trace_io.puts(colorize("=> #{format_trace_value(result)}", :result))
    end

    def format_trace_stack(values)
      "[#{values.map { |value| format_trace_value(value) }.join(', ')}]"
    end

    def format_trace_operand(value)
      value.nil? ? "-" : format_trace_value(value)
    end

    def format_trace_op(op)
      op_text = op.to_s
      case op
      when :call, :load_fn, :make_closure
        colorize(op_text, :call)
      when :jump, :jump_false, :jump_true
        colorize(op_text, :jump)
      when :store, :store_fn
        colorize(op_text, :store)
      else
        op_text
      end
    end

    def format_trace_flow(instruction, next_ip, ip)
      case instruction.op
      when :jump
        colorize("unconditional jump to #{next_ip}", :jump)
      when :jump_false, :jump_true
        return nil if next_ip == ip + 1

        colorize("branch taken to #{next_ip}", :jump)
      when :call
        colorize("function call executed", :call)
      when :make_closure
        colorize("closure created", :call)
      when :load_file
        format_load_file_flow
      end
    end

    def format_load_file_flow
      trace = @last_loaded_file_trace
      return nil unless trace

      action = trace[:status] == :cached ? "reused" : "loaded"
      colorize("#{action} #{trace[:kind]} file #{trace[:resolved_path]}", :call)
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

    def colorize(text, role)
      return text unless color_enabled?

      code = case role
             when :header
               36
             when :result
               32
             when :call
               35
             when :jump
               33
             when :store
               34
             else
               0
             end
      "\e[#{code}m#{text}\e[0m"
    end

    def color_enabled?
      @trace_io.respond_to?(:tty?) && @trace_io.tty?
    end
  end
end
