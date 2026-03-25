module Calc
  NumberNode = Struct.new(:value, keyword_init: true)
  SymbolNode = Struct.new(:name, keyword_init: true)
  ListNode = Struct.new(:children, keyword_init: true)

  class Parser
    def parse(source)
      clean_source = source.sub(/\A#!.*\n?/, "")
      tokens = tokenize(clean_source)
      parse_forms(tokens)
    end

    private

    def tokenize(source)
      source.scan(/\(|\)|[^\s()]+/)
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
        tokens.shift
        ListNode.new(children: children)
      when ")"
        raise SyntaxError, "unexpected ')'"
      else
        atom(token)
      end
    end

    def atom(token)
      if token.match?(/\A-?\d+\z/)
        NumberNode.new(value: Integer(token))
      else
        SymbolNode.new(name: token)
      end
    end
  end
end
