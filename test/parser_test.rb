require_relative "test_helper"

class ParserTest < Minitest::Test
  def setup
    @parser = Calc::Parser.new
  end

  def test_parses_basic_list
    ast = @parser.parse("(+ 1 2)").first

    assert_instance_of Calc::ListNode, ast
    assert_equal "+", ast.children[0].name
    assert_equal 1, ast.children[1].value
    assert_equal 2, ast.children[2].value
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
end
