module Calc
  module Cli
    class DebugSourceLineMapper
      def initialize(source, nodes)
        @source = source
        @nodes = nodes
        @source_lines = source.to_s.lines(chomp: true)
        @executable_source_lines = executable_source_lines
      end

      def resolve(source_line)
        return nil if source_line > source_line_count
        return nil unless executable_source_lines.include?(source_line)

        index = @executable_source_lines.index { |line_no| line_no > source_line }
        node_index = index ? index - 1 : @executable_source_lines.length - 1
        return nil if node_index.negative?

        @nodes[node_index]&.line
      end

      def current_source_line_for(ast_line)
        source_lines_for(ast_line).first
      end

      def source_lines_for(ast_line)
        @source_lines_for ||= begin
          mapping = Hash.new { |hash, key| hash[key] = [] }
          @nodes.each_with_index do |node, index|
            next unless node.line

            source_line = @executable_source_lines[index]
            mapping[node.line] << source_line if source_line
          end
          mapping
        end

        @source_lines_for[ast_line]
      end

      private

      def executable_source_lines
        @executable_source_lines ||= begin
          lines = []
          @source_lines.each_with_index do |line, index|
            code = line.sub(/;.*$/, "")
            lines << (index + 1) if code.match?(/\S/)
          end
          lines
        end
      end

      def source_line_count
        @source_line_count ||= @source_lines.length
      end
    end
  end
end
