require_relative "functions/metadata"

Dir.glob(File.join(__dir__, "functions", "*.rb")).each do |path|
  next if path.end_with?("/metadata.rb")

  require_relative path.delete_prefix("#{__dir__}/")
end

module Calc
  # This module serves as the central manager for registering all built-in
  # functions of the Calc interpreter. It loads function definitions from
  # subdirectories and provides methods to register them with the Builtins
  # class, along with their metadata.
  module Functions
    # Registers a single built-in function with the `Builtins` registry.
    # It fetches additional metadata from the `Metadata` module if available.
    #
    # @param builtins [Builtins] The Builtins instance to register the function with.
    # @param name [String] The name of the function.
    # @param min_arity [Integer] The minimum number of arguments.
    # @param max_arity [Integer, nil] The maximum number of arguments, nil for variadic.
    # @param metadata [Hash] Additional metadata for the function (e.g., type, description, example).
    # @param block [Proc] The Proc object implementing the function's logic.
    def self.register(builtins, name, min_arity: 0, max_arity: nil, **metadata, &)
      builtin_metadata = begin
        Metadata.fetch(name)
      rescue KeyError
        {}
      end

      builtins.register(
        name,
        min_arity: min_arity,
        max_arity: max_arity,
        type: metadata.fetch(:type, builtin_metadata[:type]),
        description: metadata.fetch(:description, builtin_metadata[:description]),
        example: metadata.fetch(:example, builtin_metadata[:example]),
        &
      )
    end

    # Discovers all modules/classes within `Calc::Functions` that implement
    # a `register` class method. These are considered function registrars.
    #
    # @return [Array<Module>] A sorted array of function registrar modules/classes.
    def self.registrars
      constants(false)
        .map { |name| const_get(name) }
        .select { |constant| constant.respond_to?(:register) }
        .sort_by(&:name)
    end

    # Iterates through all discovered function registrars and invokes their
    # `register` method to add all built-in functions to the `Builtins` instance.
    #
    # @param builtins [Builtins] The Builtins instance to register functions with.
    def self.register_all(builtins)
      registrars.each { |registrar| registrar.register(builtins) }
    end
  end
end
