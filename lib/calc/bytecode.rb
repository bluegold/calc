module Calc
  # Bytecode representation for the Calc virtual machine.
  # Defines the instruction set and the compiled code container (CodeObject).
  module Bytecode
    FILE_EXTENSION = ".calcbc".freeze
    FILE_FORMAT = "calc-bytecode".freeze
    FILE_VERSION = 1

    # A single bytecode instruction.
    # @attr op [Symbol] The opcode.
    # @attr a  [Object] The operand (nil for operand-less instructions).
    # @attr line   [Integer, nil] Source line number for debug info.
    # @attr column [Integer, nil] Source column number for debug info.
    Instruction = Struct.new(:op, :a, :line, :column) do
      def to_s
        a.nil? ? op.to_s : "#{op} #{a.inspect}"
      end
    end

    # A compiled sequence of instructions representing one evaluatable unit
    # (a top-level expression, a lambda body, etc.).
    # @attr instructions [Array<Instruction>] The instruction sequence.
    # @attr name [String, nil] An optional name for debugging.
    CodeObject = Struct.new(:instructions, :name) do
      def initialize(name: nil)
        super([], name)
      end

      # Appends an instruction and returns its index (for back-patching).
      def emit(op, a = nil, line: nil, column: nil)
        instructions << Instruction.new(op, a, line, column)
        instructions.length - 1
      end

      # Replaces the operand of a previously emitted instruction (for back-patching jumps).
      def patch(index, value)
        instructions[index].a = value
      end

      # Returns the index of the next instruction to be emitted.
      def size
        instructions.length
      end

      # Human-readable disassembly (for debugging).
      def disassemble(indent: 0)
        lines = instructions.each_with_index.flat_map do |instr, i|
          render_instruction_lines(instr, i, indent)
        end

        prefix = " " * indent
        header = name ? "#{prefix}=== #{name} ===\n" : ""
        header + lines.join("\n")
      end

      private

      def render_instruction_lines(instr, index, indent)
        lines = [format_instruction_line(instr, index, indent)]
        code = closure_code(instr)
        return lines unless code

        lines << "#{' ' * (indent + 2)}; closure body"
        lines.concat(code.instructions.each_with_index.map do |body_instr, body_index|
          format_instruction_line(body_instr, body_index, indent + 4)
        end)
        lines
      end

      def format_instruction_line(instr, index, indent)
        prefix = " " * indent
        location = instr.line ? " ; L#{instr.line}" : ""
        instruction = instruction_label(instr)
        prefix + format("%<index>04d  %<instruction>s%<location>s",
                        index: index,
                        instruction: instruction,
                        location: location)
      end

      def instruction_label(instr)
        return instr.to_s unless instr.op == :make_closure && instr.a.is_a?(Hash)

        params = instr.a[:params] || []
        "make_closure params=#{params.inspect}"
      end

      def closure_code(instr)
        return nil unless instr.op == :make_closure && instr.a.is_a?(Hash)

        code = instr.a[:code]
        code.is_a?(CodeObject) ? code : nil
      end
    end

    module_function

    # Saves a CodeObject to a file.
    def save(code, path, include_debug: true, include_ast: include_debug)
      payload = {
        format: FILE_FORMAT,
        version: FILE_VERSION,
        code: serialize_code_object(code, include_debug: include_debug, include_ast: include_ast)
      }

      File.binwrite(path, Marshal.dump(payload))
      path
    end

    # Loads a CodeObject from a file.
    def load(path)
      payload = Marshal.load(File.binread(path)) # rubocop:disable Security/MarshalLoad
      validate_payload!(payload)

      deserialize_code_object(payload.fetch(:code))
    rescue StandardError => e
      raise Calc::RuntimeError, "failed to load bytecode: #{e.message}"
    end

    def serialize_code_object(code, include_debug:, include_ast:)
      {
        name: code.name,
        instructions: code.instructions.map do |instruction|
          {
            op: instruction.op,
            a: serialize_operand(instruction.a, include_debug: include_debug, include_ast: include_ast),
            line: include_debug ? instruction.line : nil,
            column: include_debug ? instruction.column : nil
          }
        end
      }
    end

    def deserialize_code_object(data)
      code = CodeObject.new(name: data[:name])

      data.fetch(:instructions).each do |instruction|
        code.emit(
          instruction.fetch(:op),
          deserialize_operand(instruction[:a]),
          line: instruction[:line],
          column: instruction[:column]
        )
      end

      code
    end

    def serialize_operand(value, include_debug:, include_ast:)
      case value
      when CodeObject
        { __bytecode_code_object__: serialize_code_object(value, include_debug: include_debug, include_ast: include_ast) }
      when Array
        value.map { |item| serialize_operand(item, include_debug: include_debug, include_ast: include_ast) }
      when Hash
        value.each_with_object({}) do |(key, item), result|
          next if !include_ast && key == :ast_body

          result[key] = serialize_operand(item, include_debug: include_debug, include_ast: include_ast)
        end
      else
        value
      end
    end

    def deserialize_operand(value)
      case value
      when Array
        value.map { |item| deserialize_operand(item) }
      when Hash
        serialized_code = value[:__bytecode_code_object__]
        return deserialize_code_object(serialized_code) if serialized_code

        value.transform_values { |item| deserialize_operand(item) }
      else
        value
      end
    end

    def validate_payload!(payload)
      raise Calc::RuntimeError, "invalid bytecode payload" unless payload.is_a?(Hash)
      raise Calc::RuntimeError, "unsupported bytecode format" unless payload[:format] == FILE_FORMAT
      raise Calc::RuntimeError, "unsupported bytecode version" unless payload[:version] == FILE_VERSION
      raise Calc::RuntimeError, "missing code object" unless payload[:code].is_a?(Hash)
    end
    private_class_method :serialize_code_object, :deserialize_code_object,
                         :serialize_operand, :deserialize_operand, :validate_payload!
  end
end
