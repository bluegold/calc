module Calc
  # Represents an evaluation environment, managing variable bindings and their scope.
  # Environments can be nested, allowing for lexical scoping.
  class Environment
    # Initializes a new environment.
    #
    # @param parent [Environment, nil] The parent environment, if any.
    def initialize(parent = nil)
      @parent = parent
      @bindings = {}
    end

    # Creates a deep copy of the current environment, including its parent chain.
    # This is crucial for implementing closures where lambdas capture their defining environment.
    #
    # @return [Environment] A new Environment instance that is a deep copy.
    def snapshot
      copy = Environment.new(@parent&.snapshot)
      @bindings.each { |name, value| copy.set(name, value) }
      copy
    end

    # Sets the value of a variable in the current environment.
    # If the variable already exists, its value is updated.
    #
    # @param name [String] The name of the variable.
    # @param value [Object] The value to assign.
    def set(name, value)
      @bindings[name] = value
    end

    # Retrieves the value of a variable, searching up the parent chain if necessary.
    #
    # @param name [String] The name of the variable.
    # @return [Object] The value of the variable.
    # @raise [Calc::NameError] If the variable is unbound.
    def get(name)
      return @bindings[name] if @bindings.key?(name)
      return @parent.get(name) if @parent

      raise Calc::NameError, "unknown variable: #{name}"
    end

    # Checks if a variable is bound in this environment or any parent environment.
    #
    # @param name [String] The name of the variable.
    # @return [Boolean] True if bound, false otherwise.
    def bound?(name)
      return true if @bindings.key?(name)
      return @parent.bound?(name) if @parent

      false
    end

    # Checks if a variable is bound in the current environment only (not searching parents).
    #
    # @param name [String] The name of the variable.
    # @return [Boolean] True if bound locally, false otherwise.
    def bound_local?(name)
      @bindings.key?(name)
    end

    # Retrieves the value of a variable from the current environment only.
    # Unlike `get`, this does not search parent environments.
    #
    # @param name [String] The name of the variable.
    # @return [Object] The value of the local variable.
    # @raise [Calc::NameError] If the variable is unbound in the current scope.
    def get_local(name)
      return @bindings[name] if @bindings.key?(name)

      raise Calc::NameError, "unknown variable: #{name}"
    end

    # Returns a list of all unique variable names bound in this environment and its parents.
    #
    # @return [Array<String>] An array of unique bound variable names.
    def binding_names
      names = @parent ? @parent.binding_names : []
      (names + @bindings.keys).uniq
    end
  end
end
