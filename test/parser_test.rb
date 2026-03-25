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

  def test_pretty_prints_ast
    ast = @parser.parse("(+ 1 (* 2 3))")

    assert_equal "(+ 1 (* 2 3))", Calc::ASTPrinter.pretty(ast)
  end
end
