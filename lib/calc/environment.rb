module Calc
  class Environment
    def initialize(parent = nil)
      @parent = parent
      @bindings = {}
    end

    def snapshot
      copy = Environment.new(@parent&.snapshot)
      @bindings.each { |name, value| copy.set(name, value) }
      copy
    end

    def set(name, value)
      @bindings[name] = value
    end

    def get(name)
      return @bindings[name] if @bindings.key?(name)
      return @parent.get(name) if @parent

      raise Calc::NameError, "unknown variable: #{name}"
    end

    def bound?(name)
      return true if @bindings.key?(name)
      return @parent.bound?(name) if @parent

      false
    end

    def bound_local?(name)
      @bindings.key?(name)
    end

    def get_local(name)
      return @bindings[name] if @bindings.key?(name)

      raise Calc::NameError, "unknown variable: #{name}"
    end

    def binding_names
      names = @parent ? @parent.binding_names : []
      (names + @bindings.keys).uniq
    end
  end
end
