module Calc
  module Cli
    class ReplCommandHandler
      # Builds a handler for REPL colon commands such as :help and :ast.
      def initialize(parser:, builtins:, out: $stdout, err: $stderr)
        @parser = parser
        @builtins = builtins
        @out = out
        @err = err
      end

      # Handles a single REPL command line and reports command-specific output.
      def handle(line)
        command, payload = line[1..].split(/\s+/, 2)

        case command
        when "ast"
          source = payload.to_s.strip
          @out.puts Calc::ASTPrinter.pretty(@parser.parse(source))
          true
        when "help"
          print_help
          true
        else
          @err.puts "unknown command: :#{command}"
          false
        end
      rescue StandardError => e
        @err.puts "#{e.class}: #{e.message}"
        false
      end

      private

      # Prints command help and grouped builtin reference lines.
      def print_help
        @out.puts "Commands:"
        @out.puts "  :ast <expr>   Print the AST for an expression"
        @out.puts "  :help         Show this help"
        @out.puts
        @out.puts "Builtins:"
        @builtins.each_builtin.group_by { |builtin| builtin.type || "other" }.sort.each do |type, entries|
          @out.puts "  [#{format_builtin_group(type)}]"
          entries.sort_by(&:name).each do |builtin|
            line = "    #{builtin.name}"
            line += " - #{builtin.description}" if builtin.description
            @out.puts line
            @out.puts "      example: #{builtin.example}" if builtin.example
          end
        end
      end

      # Converts builtin metadata group keys to a display label.
      def format_builtin_group(type)
        type.split("-").map(&:capitalize).join(" ")
      end
    end
  end
end
