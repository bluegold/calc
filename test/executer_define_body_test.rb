require_relative "test_helper"
require "bigdecimal"

class ExecuterDefineBodyTest < Minitest::Test
  def setup
    @executer = Calc::Executer.new(Calc::Environment.new)
    @parser = Calc::Parser.new
  end

  def test_define_function_supports_multiple_body_expressions
    source = <<~CALC
      (define (binary items target)
        (define (_search low high)
          (if (> low high)
              nil
              (do
                (define mid (floor (/ (+ low high) 2)))
                (define val (nth mid items))
                (cond
                  ((== val target) mid)
                  ((> val target) (_search low (- mid 1)))
                  (else (_search (+ mid 1) high))))))
        (_search 0 (- (count items) 1)))
    CALC

    @executer.evaluate(@parser.parse(source).first)
    result = @executer.evaluate(@parser.parse("(binary (list 10 20 30 40 50) 30)").first)

    assert_equal BigDecimal("2"), result
  end
end
