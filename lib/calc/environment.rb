module Calc
  class Environment
    def initialize(parent = nil)
      @parent = parent
      @bindings = {}
    end

    def set(name, value)
      @bindings[name] = value
    end

    def get(name)
      return @bindings[name] if @bindings.key?(name)
      return @parent.get(name) if @parent

      raise NameError, "unknown variable: #{name}"
    end
  end
end
