require "bigdecimal"
require "json"
require_relative "builtins/collection_helpers"
require_relative "builtins/json_helpers"

module Calc
  # Manages all built-in functions, special literals, and utility methods
  # for the Calc interpreter. It acts as a registry and dispatcher for
  # functions callable directly from Calc code.
  class Builtins
    include CollectionHelpers
    include JsonHelpers

    # Special literal values in Calc.
    LITERALS = {
      "true" => true,
      "false" => false,
      "nil" => nil
    }.freeze

    # Struct to hold metadata about each built-in function.
    # @attr name [String] The name of the function.
    # @attr min_arity [Integer] Minimum number of arguments.
    # @attr max_arity [Integer, nil] Maximum number of arguments, nil for variadic.
    # @attr type [String] Type signature or description.
    # @attr description [String] A brief description of the function.
    # @attr example [String] An example usage of the function.
    # @attr callable [Proc] The actual Ruby Proc that implements the function.
    Builtin = Struct.new(:name, :min_arity, :max_arity, :type, :description, :example, :callable)

    # Initializes the Builtins registry and registers all predefined functions.
    def initialize
      @functions = {}

      Functions.register_all(self)
    end

    # Registers a new built-in function with its metadata and implementation.
    #
    # @param name [String] The name of the function.
    # @param min_arity [Integer] The minimum number of arguments the function accepts.
    # @param max_arity [Integer, nil] The maximum number of arguments, nil for variadic functions.
    # @param metadata [Hash] Additional metadata like :type, :description, :example.
    # @param block [Proc] The Ruby Proc that implements the function's logic.
    def register(name, min_arity: 0, max_arity: nil, **metadata, &block)
      @functions[name] = Builtin.new(
        name: name,
        min_arity: min_arity,
        max_arity: max_arity,
        type: metadata[:type],
        description: metadata[:description],
        example: metadata[:example],
        callable: block
      )
    end

    # Registers an alias for an existing built-in function.
    #
    # @param name [String] Alias name to register.
    # @param target [String] Existing built-in function name.
    # @param metadata [Hash] Optional metadata override for the alias.
    # @raise [Calc::NameError] If the target built-in does not exist.
    def register_alias(name, target, **metadata)
      target_builtin = @functions[target]
      raise Calc::NameError, "unknown function: #{target}" unless target_builtin

      @functions[name] = Builtin.new(
        name: name,
        min_arity: target_builtin.min_arity,
        max_arity: target_builtin.max_arity,
        type: metadata.fetch(:type, target_builtin.type),
        description: metadata.fetch(:description, target_builtin.description),
        example: metadata.fetch(:example, target_builtin.example),
        callable: target_builtin.callable
      )
    end

    # Checks if a given name corresponds to a special literal value.
    #
    # @param name [String] The name to check.
    # @return [Boolean] True if the name is a literal, false otherwise.
    def literal?(name)
      LITERALS.key?(name)
    end

    # Resolves a name against special literals.
    #
    # @param name [String] The name to resolve.
    # @return [Array<Boolean, Object>] A pair [found, value]. `found` is true if it's a literal, `value` is the literal's value.
    def resolve(name)
      return [true, LITERALS[name]] if literal?(name)

      [false, nil]
    end

    # Checks if a given name is a reserved literal.
    #
    # @param name [String] The name to check.
    # @return [Boolean] True if the name is reserved (a literal), false otherwise.
    def reserved?(name)
      literal?(name)
    end

    # Checks if a function with the given name is registered as a built-in.
    #
    # @param name [String] The function name to check.
    # @return [Boolean] True if registered, false otherwise.
    def registered?(name)
      @functions.key?(name)
    end

    # Retrieves the Builtin struct for a given function name.
    #
    # @param name [String] The function name.
    # @return [Builtin, nil] The Builtin struct, or nil if not found.
    def builtin(name)
      @functions[name]
    end

    # Iterates over all registered built-in functions.
    #
    # @yieldparam builtin [Builtin] Each Builtin struct.
    # @return [Enumerator] An enumerator if no block is given.
    def each_builtin(&block)
      return enum_for(:each_builtin) unless block

      @functions.values.each(&block)
    end

    # Calls a registered built-in function with the given arguments.
    # Performs arity checks before calling the underlying callable.
    #
    # @param name [String] The name of the function to call.
    # @param args [Array<Object>] An array of arguments for the function.
    # @param block [Proc] An optional callable runner for higher-order functions.
    # @return [Object] The result of the function call.
    # @raise [Calc::NameError] If the function is unknown.
    # @raise [Calc::RuntimeError] If the number of arguments is incorrect.
    def call(name, args, &)
      builtin = @functions[name]
      raise Calc::NameError, "unknown function: #{name}" unless builtin
      raise Calc::RuntimeError, "wrong number of arguments for #{name}" if args.length < builtin.min_arity
      raise Calc::RuntimeError, "wrong number of arguments for #{name}" if builtin.max_arity && args.length > builtin.max_arity

      builtin.callable.call(args, &)
    end

    # Determines if a value is truthy (not false and not nil) in Calc's logic.
    #
    # @param value [Object] The value to check.
    # @return [Boolean] True if truthy, false otherwise.
    def truthy?(value)
      value != false && !value.nil?
    end
  end
end
