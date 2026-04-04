module Calc
  module Cli
    class DebugListCommand
      Context = Struct.new(:source, :code, :nodes, :cursor, :breakpoints, :line_mapper)

      def initialize(context:, out:)
        @context = context
        @out = out
      end

      def call(payload)
        lines, show_bytecode = parse_args(payload)
        current_ast_line = current_node&.line || 1
        current_source_line = @context.line_mapper.current_source_line_for(current_ast_line) || current_ast_line
        start_line = [current_source_line - lines, 1].max
        end_line = [current_source_line + lines, source_lines.length].min

        render_source_window(start_line, end_line, current_source_line)
        render_bytecode(start_line, end_line) if show_bytecode
      end

      private

      def parse_args(payload)
        parts = payload.to_s.split
        show_bytecode = parts.include?("bytecode")
        count_part = parts.reject { |part| part == "bytecode" }.first
        count = count_part ? Integer(count_part, 10) : 3
        [count, show_bytecode]
      end

      def render_source_window(start_line, end_line, current_line)
        (start_line..end_line).each do |line_no|
          marker = source_marker(line_no, current_line)
          ast_line = @context.line_mapper.resolve(line_no)
          @out.puts format("%<marker>s src %<source_line>4d | ast %<ast_line>4s | %<source>s",
                           marker: marker,
                           source_line: line_no,
                           ast_line: ast_line ? ast_line.to_s : "-",
                           source: source_lines[line_no - 1])
        end
      end

      def render_bytecode(start_line, end_line)
        @out.puts "bytecode:"
        ast_lines = (start_line..end_line).filter_map { |line_no| @context.line_mapper.resolve(line_no) }.uniq
        ast_lines.each do |ast_line|
          render_bytecode_for_ast_line(ast_line)
        end
      end

      def render_bytecode_for_ast_line(ast_line)
        instructions = @context.code.instructions.select { |instruction| instruction.line == ast_line }
        return if instructions.empty?

        @out.puts format("  L%<line_no>d", line_no: ast_line)
        instructions.each do |instruction|
          @out.puts format("    %<index>04d  %<instruction>s",
                           index: instruction_index(instruction),
                           instruction: instruction_label(instruction))
          render_closure_body(instruction, indent: 6)
        end
      end

      def render_closure_body(instruction, indent:)
        code = closure_code(instruction)
        return unless code

        @out.puts "#{' ' * indent}; closure body"
        code.instructions.each_with_index do |body_instruction, index|
          @out.puts format("%<indent>s%<index>04d  %<instruction>s",
                           indent: ' ' * (indent + 2),
                           index: index,
                           instruction: instruction_label(body_instruction))
          render_closure_body(body_instruction, indent: indent + 4)
        end
      end

      def instruction_index(instruction)
        @context.code.instructions.index(instruction) || 0
      end

      def instruction_label(instruction)
        return instruction.to_s unless instruction.op == :make_closure

        params = closure_params(instruction)
        "make_closure params=#{params.inspect}"
      end

      def closure_code(instruction)
        return nil unless instruction.op == :make_closure

        code = closure_metadata_value(instruction, :code)
        code.is_a?(Calc::Bytecode::CodeObject) ? code : nil
      end

      def closure_params(instruction)
        Array(closure_metadata_value(instruction, :params))
      end

      def closure_metadata_value(instruction, key)
        metadata = instruction.a
        return metadata[key] if metadata.respond_to?(:[]) && metadata.respond_to?(:key?) && metadata.key?(key)

        return metadata.public_send(key) if metadata.respond_to?(key)

        nil
      end

      def current_node
        @context.nodes[@context.cursor] || @context.nodes.last
      end

      def source_lines
        @context.source.to_s.lines(chomp: true)
      end

      def source_marker(line_no, current_line)
        ast_line = @context.line_mapper.resolve(line_no)
        return " " if ast_line.nil?
        return "B" if breakpoint_lines.include?(ast_line)
        return ">" if line_no == current_line

        " "
      end

      def breakpoint_lines
        @context.breakpoints
      end
    end
  end
end
