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
      def disassemble
        lines = instructions.each_with_index.map do |instr, i|
          loc = instr.line ? " ; L#{instr.line}" : ""
          format("%<index>04d  %<instruction>s%<location>s",
                 index: i,
                 instruction: instr,
                 location: loc)
        end
        header = name ? "=== #{name} ===\n" : ""
        header + lines.join("\n")
      end
    end
  end
end
