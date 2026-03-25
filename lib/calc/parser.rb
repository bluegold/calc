require "pp"
require "bigdecimal"

module Calc
  def self.format_value(value)
    case value
    when BigDecimal
      value.to_s("F").sub(/\.0+\z/, "")
    else
      value.to_s
    end
  end

  NumberNode = Struct.new(:value, keyword_init: true) do
    def pretty_print(q)
      q.text(Calc.format_value(value))
    end
  end

  SymbolNode = Struct.new(:name, keyword_init: true) do
    def pretty_print(q)
      q.text(name)
    end
  end

  ListNode = Struct.new(:children, keyword_init: true) do
    def pretty_print(q)
      q.group(1, "(", ")") do
        children.each_with_index do |child, index|
          q.breakable(" ") unless index.zero?
          child.pretty_print(q)
        end
      end
    end
  end

  class ASTPrinter
    def self.pretty(nodes)
      Array(nodes).map { |node| render(node).strip }.join("\n")
    end

    def self.render(node)
      PP.pp(node, +"", 80)
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
      source.gsub(/;.*$/, "").scan(/\(|\)|[^\s()]+/)
    end

    def parse_forms(tokens)
      forms = []
      until tokens.empty?
        forms << parse_expression(tokens)
      end
      forms
    end

    def parse_expression(tokens)
      token = tokens.shift
      raise SyntaxError, "unexpected end of input" if token.nil?

      case token
      when "("
        children = []
        until tokens.first == ")"
          raise SyntaxError, "missing ')'" if tokens.empty?
          children << parse_expression(tokens)
        end
        raise SyntaxError, "empty list" if children.empty?
        tokens.shift
        ListNode.new(children: children)
      when ")"
        raise SyntaxError, "unexpected ')'"
      else
        atom(token)
      end
    end

    def atom(token)
      if token.match?(/\A-?(?:\d+\.?\d*|\d*\.\d+)\z/)
        NumberNode.new(value: BigDecimal(token))
      else
        SymbolNode.new(name: token)
      end
    end
  end
end
