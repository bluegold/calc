module Calc
  # Custom error classes for the Calc interpreter.
  # These errors provide more specific information about issues encountered
  # during parsing, name resolution, and runtime evaluation.

  # Raised when a syntax error occurs during parsing.
  class SyntaxError < StandardError; end

  # Raised when a name (variable or function) cannot be resolved.
  class NameError < StandardError; end

  # Raised when a general runtime error occurs during evaluation.
  class RuntimeError < StandardError; end

  # Raised specifically when a division by zero operation is attempted.
  class DivisionByZeroError < RuntimeError; end
end
