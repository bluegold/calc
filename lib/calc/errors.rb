module Calc
  class SyntaxError < StandardError; end

  class NameError < StandardError; end

  class RuntimeError < StandardError; end

  class DivisionByZeroError < RuntimeError; end
end
