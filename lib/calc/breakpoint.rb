module Calc
  # Represents a debugger breakpoint.
  class Breakpoint
    attr_reader :id, :kind, :target

    def initialize(id:, kind:, target:)
      @id = id
      @kind = validate_kind(kind)
      @target = target
    end

    def line?
      @kind == :line
    end

    def function?
      @kind == :function
    end

    private

    def validate_kind(kind)
      return kind if %i[line function].include?(kind)

      raise ArgumentError, "invalid breakpoint kind: #{kind.inspect}"
    end
  end
end
