require_relative "test_helper"
require "bigdecimal"

class ParserTest < Minitest::Test
  def setup
    @parser = Calc::Parser.new
  end

  def test_parses_basic_list
    ast = @parser.parse("(+ 1 2)").first

    assert_instance_of Calc::ListNode, ast
    assert_equal "+", ast.children[0].name
    assert_equal BigDecimal("1"), ast.children[1].value
    assert_equal BigDecimal("2"), ast.children[2].value
  end

  def test_parses_nested_expression
    ast = @parser.parse("(* (+ 1 2) 3)").first

    inner = ast.children[1]
    assert_instance_of Calc::ListNode, inner
    assert_equal "+", inner.children[0].name
  end

  def test_ignores_shebang_line
    ast = @parser.parse("#!/usr/bin/env calc\n(+ 1 2)").first

    assert_equal "+", ast.children[0].name
  end

  def test_ignores_line_comments
    ast = @parser.parse("(+ 1 2) ; comment\n(+ 3 4)")

    assert_equal 2, ast.size
    assert_equal BigDecimal("1"), ast.first.children[1].value
    assert_equal BigDecimal("3"), ast.last.children[1].value
  end

  def test_parses_decimal_numbers
    ast = @parser.parse("(+ 1.5 2.25)").first

    assert_equal BigDecimal("1.5"), ast.children[1].value
    assert_equal BigDecimal("2.25"), ast.children[2].value
  end

  def test_parses_string_literal
    ast = @parser.parse("\"hello\\nworld\"").first

    assert_instance_of Calc::StringNode, ast
    assert_equal "hello\nworld", ast.value
  end

  def test_rejects_unterminated_string_literal
    error = assert_raises(Calc::SyntaxError) { @parser.parse("\"hello") }

    assert_match "unterminated string literal", error.message
  end

  def test_pretty_prints_ast
    ast = @parser.parse("(+ 1 (* 2 3))")

    assert_equal <<~YAML, Calc::ASTPrinter.pretty(ast)
      - type: list
        children:
        - type: symbol
          name: "+"
        - type: number
          value: '1'
        - type: list
          children:
          - type: symbol
            name: "*"
          - type: number
            value: '2'
          - type: number
            value: '3'
    YAML
  end

  def test_pretty_prints_string_literal
    ast = @parser.parse("\"hello\"")

    assert_equal <<~YAML, Calc::ASTPrinter.pretty(ast)
      - type: string
        value: hello
    YAML
  end

  def test_rejects_empty_list
    error = assert_raises(Calc::SyntaxError) { @parser.parse("()") }

    assert_match "empty list", error.message
  end

  def test_rejects_missing_closing_paren
    error = assert_raises(Calc::SyntaxError) { @parser.parse("(+ 1 2") }

    assert_match "missing ')'", error.message
  end

  def test_rejects_unexpected_closing_paren
    error = assert_raises(Calc::SyntaxError) { @parser.parse(")") }

    assert_match "unexpected ')'", error.message
  end

  def test_parses_sample_with_shebang_and_comments
    source = <<~CALC
      #!/usr/bin/env calc
      ; sample program
      (define x 1)
      (+ x 2) ; trailing comment
    CALC

    ast = @parser.parse(source)

    assert_equal 2, ast.size
    assert_equal "define", ast.first.children.first.name
    assert_equal "+", ast.last.children.first.name
  end
end
