require "bigdecimal"
require "yaml"

module Calc
  def self.format_value(value)
    case value
    when BigDecimal
      value.to_s("F").sub(/\.0+\z/, "")
    when Array
      "[#{value.map { |item| format_value(item) }.join(', ')}]"
    else
      value.to_s
    end
  end

  NumberNode = Struct.new(:value) do
    def pretty_print(q)
      q.text(Calc.format_value(value))
    end
  end

  SymbolNode = Struct.new(:name) do
    def pretty_print(q)
      q.text(name)
    end
  end

  StringNode = Struct.new(:value) do
    def pretty_print(q)
      q.text(value.inspect)
    end
  end

  ListNode = Struct.new(:children) do
    def pretty_print(q)
      q.group(1, "(", ")") do
        children.each_with_index do |child, index|
          q.breakable(" ") unless index.zero?
          child.pretty_print(q)
        end
      end
    end
  end

  LambdaNode = Struct.new(:params, :body) do
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
      stripped.scan(/"(?:\\.|[^"\\])*"|\(|\)|[^\s()]+/)
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

      case token
      when "("
        children = []
        until tokens.first == ")"
          raise Calc::SyntaxError, "missing ')'" if tokens.empty?

          children << parse_expression(tokens)
        end
        raise Calc::SyntaxError, "empty list" if children.empty?

        tokens.shift
        ListNode.new(children: children)
      when ")"
        raise Calc::SyntaxError, "unexpected ')'"
      else
        atom(token)
      end
    end

    def atom(token)
      if token.match?(/\A-?(?:\d+\.?\d*|\d*\.\d+)\z/)
        NumberNode.new(value: BigDecimal(token))
      elsif token.start_with?("\"")
        raise Calc::SyntaxError, "unterminated string literal" unless token.end_with?("\"")

        StringNode.new(value: unescape_string(token))
      else
        SymbolNode.new(name: token)
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
end
