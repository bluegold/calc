require "bigdecimal"
require "yaml"
require "strscan"

module Calc
  # Formats a Calc value into a human-readable string representation.
  # This is used for outputting results and error messages.
  #
  # @param value [Object] The Calc value to format.
  # @return [String] The formatted string.
  def self.format_value(value)
    case value
    when BigDecimal
      value.to_s("F").sub(/\.0+\z/, "")
    when Array
      "[#{value.map { |item| format_value(item) }.join(', ')}]"
    when Hash
      entries = value.map { |key, item| "#{key.inspect} => #{format_value(item)}" }

      "{#{entries.join(', ')}}"
    else
      value.to_s
    end
  end

  # Represents a number literal in the Abstract Syntax Tree (AST).
  # @attr value [BigDecimal] The numeric value.
  # @attr line [Integer] The line number in the source code.
  # @attr column [Integer] The column number in the source code.
  NumberNode = Struct.new(:value, :line, :column) do
    # Pretty-prints the node's value.
    def pretty_print(q)
      q.text(Calc.format_value(value))
    end
  end

  # Represents a symbol in the Abstract Syntax Tree (AST).
  # @attr name [String] The name of the symbol.
  # @attr line [Integer] The line number in the source code.
  # @attr column [Integer] The column number in the source code.
  SymbolNode = Struct.new(:name, :line, :column) do
    # Pretty-prints the node's name.
    def pretty_print(q)
      q.text(name)
    end
  end

  # Represents a string literal in the Abstract Syntax Tree (AST).
  # @attr value [String] The string value.
  # @attr line [Integer] The line number in the source code.
  # @attr column [Integer] The column number in the source code.
  StringNode = Struct.new(:value, :line, :column) do
    # Pretty-prints the node's value (inspect format).
    def pretty_print(q)
      q.text(value.inspect)
    end
  end

  # Represents a keyword literal in the Abstract Syntax Tree (AST).
  # @attr name [String] The name of the keyword (without the leading colon).
  # @attr line [Integer] The line number in the source code.
  # @attr column [Integer] The column number in the source code.
  KeywordNode = Struct.new(:name, :line, :column) do
    # Pretty-prints the node's name with a leading colon.
    def pretty_print(q)
      q.text(":#{name}")
    end
  end

  # Represents a list expression in the Abstract Syntax Tree (AST).
  # @attr children [Array<Calc::Node>] An array of child nodes (elements of the list).
  # @attr line [Integer] The line number in the source code.
  # @attr column [Integer] The column number in the source code.
  ListNode = Struct.new(:children, :line, :column) do
    # Pretty-prints the list expression.
    def pretty_print(q)
      q.group(1, "(", ")") do
        children.each_with_index do |child, index|
          q.breakable(" ") unless index.zero?
          child.pretty_print(q)
        end
      end
    end
  end

  # Represents a lambda (anonymous function) expression in the Abstract Syntax Tree (AST).
  # @attr params [Array<String>] An array of parameter names.
  # @attr body [Calc::Node] The AST node representing the body of the lambda.
  # @attr line [Integer] The line number in the source code.
  # @attr column [Integer] The column number in the source code.
  LambdaNode = Struct.new(:params, :body, :line, :column) do
    # Pretty-prints the lambda expression.
    def pretty_print(q)
      q.group(1, "(", ")") do
        q.text("lambda")
        q.breakable(" ")
        q.group(1, "(", ")") do
          params.each_with_index do |param, index|
            q.breakable(" ") unless index.zero?
            q.text(param)
          end
        end
        q.breakable(" ")
        body.pretty_print(q)
      end
    end
  end

  # Utility class for pretty-printing Abstract Syntax Tree (AST) nodes.
  # It converts AST nodes into a human-readable YAML-like representation.
  class ASTPrinter
    # Converts a single AST node or an array of AST nodes into a pretty-printed YAML string.
    #
    # @param nodes [Calc::Node, Array<Calc::Node>] The AST node(s) to pretty-print.
    # @return [String] A YAML-like string representation of the AST.
    def self.pretty(nodes)
      normalized_nodes = nodes.is_a?(Array) ? nodes : [nodes]

      YAML.dump(normalized_nodes.map { |node| render(node) }).sub(/\A---\n?/, "")
    end

    # Recursively renders a single AST node into a hash suitable for YAML serialization.
    #
    # @param node [Calc::Node] The AST node to render.
    # @return [Hash] A hash representation of the AST node.
    def self.render(node)
      case node
      when NumberNode
        { "type" => "number", "value" => Calc.format_value(node.value) }
      when SymbolNode
        { "type" => "symbol", "name" => node.name }
      when StringNode
        { "type" => "string", "value" => node.value }
      when KeywordNode
        { "type" => "keyword", "name" => node.name }
      when LambdaNode
        { "type" => "lambda", "params" => node.params, "body" => render(node.body) }
      when ListNode
        { "type" => "list", "children" => node.children.map { |child| render(child) } }
      else
        { "type" => "unknown", "value" => node.inspect }
      end
    end
  end

  # Parses Calc source code into an Abstract Syntax Tree (AST).
  # It tokenizes the input, handles comments and string escaping,
  # and constructs a hierarchical representation of the code.
  class Parser
    # Parses the given source code into a list of AST forms.
    #
    # @param source [String] The Calc source code string.
    # @return [Array<Calc::Node>] An array of top-level AST nodes (forms).
    def parse(source)
      clean_source = source.sub(/\A#!.*\n?/, "")
      tokens = tokenize(clean_source)
      parse_forms(tokens)
    end

    private

    # Tokenizes the given source code into a stream of Tokens.
    # It removes comments and extracts meaningful lexical units.
    #
    # @param source [String] The source code string.
    # @return [Array<Token>] An array of Token objects.
    # @raise [Calc::SyntaxError] If an unexpected token is encountered.
    def tokenize(source)
      stripped = strip_comments_and_shebang(source)
      tokens = []
      scanner = StringScanner.new(stripped)

      until scanner.eos?
        scanner.skip(/\s+/)
        break if scanner.eos?

        start_offset = scanner.pos
        token = scanner.scan(/"(?:\\.|[^"\\])*"|\(|\)|[^\s()]+/)
        raise Calc::SyntaxError, "unexpected token" unless token

        line, column = line_and_column_for(stripped, start_offset)
        type = case token
               when "("
                 :lparen
               when ")"
                 :rparen
               else
                 :atom
               end

        tokens << Token.new(type, token, line, column)
      end

      tokens
    end

    # Determines the line and column number for a given character offset in the source.
    #
    # @param source [String] The complete source code string.
    # @param offset [Integer] The character offset.
    # @return [Array<Integer, Integer>] An array containing [line_number, column_number].
    def line_and_column_for(source, offset)
      line = 1
      column = 1

      source[0...offset].each_char do |char|
        if char == "\n"
          line += 1
          column = 1
        else
          column += 1
        end
      end

      [line, column]
    end

    # Strips comments (lines starting with ';') and shebang ('#!') from the source code.
    # Handles string literals correctly so that semicolons inside strings are not treated as comments.
    #
    # @param source [String] The raw source code.
    # @return [String] The source code with comments and shebang removed.
    def strip_comments_and_shebang(source)
      output = +""
      in_string = false
      escaped = false

      source.each_line.with_index do |line, index|
        next if index.zero? && line.start_with?("#!")

        line.each_char do |char|
          if in_string
            output << char
            if escaped
              escaped = false
            elsif char == "\\"
              escaped = true
            elsif char == '"'
              in_string = false
            end
            next
          end

          break if char == ";"

          output << char

          if char == '"'
            in_string = true
            escaped = false
          end
        end

        output << "\n"
      end

      output
    end

    # Parses a list of tokens into a list of top-level AST forms.
    #
    # @param tokens [Array<Token>] The array of tokens.
    # @return [Array<Calc::Node>] An array of top-level AST nodes.
    def parse_forms(tokens)
      forms = []
      forms << parse_expression(tokens) until tokens.empty?
      forms
    end

    # Parses a single expression from the token stream.
    # Handles list expressions (parenthesized) and atomic expressions.
    #
    # @param tokens [Array<Token>] The array of tokens (modified in place).
    # @return [Calc::Node] The parsed AST node.
    # @raise [Calc::SyntaxError] If syntax errors like unmatched parentheses or unexpected tokens occur.
    def parse_expression(tokens)
      token = tokens.shift
      raise Calc::SyntaxError, "unexpected end of input" if token.nil?

      case token.type
      when :lparen
        children = []
        until tokens.first&.type == :rparen
          raise Calc::SyntaxError, "missing ')'" if tokens.empty?

          children << parse_expression(tokens)
        end
        raise Calc::SyntaxError, "empty list" if children.empty?

        tokens.shift
        ListNode.new(children: children, line: token.line, column: token.col)
      when :rparen
        raise Calc::SyntaxError, "unexpected ')'"
      else
        atom(token)
      end
    end

    # Converts a Token representing an atom into an appropriate AST node (NumberNode, StringNode, etc.).
    #
    # @param token [Token] The token to convert.
    # @return [Calc::Node] The corresponding AST node.
    # @raise [Calc::SyntaxError] If an unterminated string literal is found.
    def atom(token)
      if token.value.match?(/\A-?(?:\d+\.?\d*|\d*\.\d+)\z/)
        NumberNode.new(value: BigDecimal(token.value), line: token.line, column: token.col)
      elsif token.value.start_with?("\"")
        raise Calc::SyntaxError, "unterminated string literal" unless token.value.end_with?("\"")

        StringNode.new(value: unescape_string(token.value), line: token.line, column: token.col)
      elsif token.value.start_with?(":") && token.value.length > 1
        KeywordNode.new(name: token.value[1..], line: token.line, column: token.col)
      else
        SymbolNode.new(name: token.value, line: token.line, column: token.col)
      end
    end

    # Unescapes common escape sequences in a string literal.
    #
    # @param token [String] The raw string token (including quotes).
    # @return [String] The unescaped string value.
    def unescape_string(token)
      token[1..-2]
        .gsub("\\n", "\n")
        .gsub("\\t", "\t")
        .gsub("\\\\", "\\")
        .gsub('\\"', '"')
    end
  end

  # Represents a token generated during the lexing (tokenization) phase.
  # @attr type [Symbol] The type of the token (e.g., :lparen, :rparen, :atom).
  # @attr value [String] The raw string value of the token.
  # @attr line [Integer] The line number where the token starts.
  # @attr col [Integer] The column number where the token starts.
  Token = Struct.new(:type, :value, :line, :col)
end
