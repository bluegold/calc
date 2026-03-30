module Calc
  # Bytecode representation for the Calc virtual machine.
  # Defines the instruction set and the compiled code container (CodeObject).
  module Bytecode
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
  end
end
