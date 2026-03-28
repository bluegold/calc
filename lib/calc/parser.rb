require "bigdecimal"
require "yaml"
require "strscan"

module Calc
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

  NumberNode = Struct.new(:value, :line, :column) do
    def pretty_print(q)
      q.text(Calc.format_value(value))
    end
  end

  SymbolNode = Struct.new(:name, :line, :column) do
    def pretty_print(q)
      q.text(name)
    end
  end

  StringNode = Struct.new(:value, :line, :column) do
    def pretty_print(q)
      q.text(value.inspect)
    end
  end

  KeywordNode = Struct.new(:name, :line, :column) do
    def pretty_print(q)
      q.text(":#{name}")
    end
  end

  ListNode = Struct.new(:children, :line, :column) do
    def pretty_print(q)
      q.group(1, "(", ")") do
        children.each_with_index do |child, index|
          q.breakable(" ") unless index.zero?
          child.pretty_print(q)
        end
      end
    end
  end

  LambdaNode = Struct.new(:params, :body, :line, :column) do
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

  class ASTPrinter
    def self.pretty(nodes)
      normalized_nodes = nodes.is_a?(Array) ? nodes : [nodes]

      YAML.dump(normalized_nodes.map { |node| render(node) }).sub(/\A---\n?/, "")
    end

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

  class Parser
    def parse(source)
      clean_source = source.sub(/\A#!.*\n?/, "")
      tokens = tokenize(clean_source)
      parse_forms(tokens)
    end

    private

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

    def parse_forms(tokens)
      forms = []
      forms << parse_expression(tokens) until tokens.empty?
      forms
    end

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

    def unescape_string(token)
      token[1..-2]
        .gsub("\\n", "\n")
        .gsub("\\t", "\t")
        .gsub("\\\\", "\\")
        .gsub('\\"', '"')
    end
  end

  Token = Struct.new(:type, :value, :line, :col)
end
