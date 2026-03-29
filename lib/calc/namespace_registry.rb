module Calc
  # Manages the hierarchical structure of namespaces, variables, and functions
  # within the Calc interpreter. It provides mechanisms for defining, resolving,
  # and accessing entities within specific scopes.
  class NamespaceRegistry
    # Represents a single namespace in the hierarchy.
    # Each namespace can have a parent, children (sub-namespaces),
    # and contain its own set of variables and functions.
    #
    # @attr name [String] The name of the namespace (e.g., "my-lib", "core").
    # @attr parent [Namespace, nil] The parent namespace, or nil if it's the root.
    # @attr children [Hash] A hash of child namespaces, keyed by their names.
    # @attr variables [Hash] A hash of variables defined in this namespace.
    # @attr functions [Hash] A hash of functions defined in this namespace.
    Namespace = Struct.new(:name, :parent, :children, :variables, :functions) do
      # Initializes a new Namespace.
      #
      # @param name [String] The name of the namespace.
      # @param parent [Namespace, nil] The parent namespace.
      def initialize(name:, parent: nil)
        super
        self.children ||= {}
        self.variables ||= {}
        self.functions ||= {}
      end

      # Checks if an identifier is considered a local name within this namespace.
      # Local names are typically prefixed with an underscore.
      #
      # @param identifier [String] The identifier to check.
      # @return [Boolean] True if the identifier is local, false otherwise.
      def local_name?(identifier)
        identifier.start_with?("_")
      end

      # Retrieves or creates a child namespace by name.
      #
      # @param name [String] The name of the child namespace.
      # @return [Namespace] The child namespace.
      def child(name)
        children[name] ||= Namespace.new(name: name, parent: self)
      end

      # Returns the full path of the namespace (e.g., "my-lib.sub-ns").
      #
      # @return [String] The full path of the namespace.
      def path
        return name unless parent
        return name if parent.parent.nil?

        [parent.path, name].join(".")
      end
    end

    # Initializes the NamespaceRegistry with a root namespace and ensures the "builtin" namespace exists.
    def initialize
      @root = Namespace.new(name: nil)
      ensure_namespace("builtin")
    end

    # Checks if a given namespace path is reserved.
    # Currently, "builtin" is the only reserved namespace.
    #
    # @param path [String] The namespace path to check.
    # @return [Boolean] True if the path is reserved, false otherwise.
    def reserved_namespace?(path)
      path.to_s == "builtin"
    end

    # @!attribute [r] root
    #   @return [Namespace] The root namespace.
    attr_reader :root

    # Ensures that a namespace exists by creating it if it doesn't already.
    # It navigates or creates the hierarchical path of namespaces.
    #
    # @param path [String, nil] The full path of the namespace (e.g., "my.namespace").
    # @return [Namespace] The Namespace object corresponding to the path.
    def ensure_namespace(path)
      return @root if path.nil? || path.to_s.empty?

      names = path.to_s.split(".")
      names.reduce(@root) { |namespace, name| namespace.child(name) }
    end

    # Retrieves an existing namespace by its full path.
    #
    # @param path [String, nil] The full path of the namespace.
    # @return [Namespace] The Namespace object corresponding to the path.
    # @raise [Calc::NameError] If any part of the namespace path does not exist.
    def namespace(path)
      return @root if path.nil? || path.to_s.empty?

      names = path.to_s.split(".")
      names.reduce(@root) do |namespace, name|
        namespace.children[name] || raise(Calc::NameError, "unknown namespace: #{path}")
      end
    end

    # Defines a new variable within a specified namespace.
    #
    # @param namespace_path [String, nil] The path of the namespace where the variable is defined.
    # @param name [String] The name of the variable.
    # @param value [Object] The value of the variable.
    # @param local [Boolean] True if the variable is local to its defining scope, false otherwise.
    # @raise [Calc::NameError] If attempting to modify a reserved namespace.
    def define_variable(namespace_path, name, value, local: false)
      raise Calc::NameError, "cannot modify reserved namespace: builtin" if reserved_namespace?(namespace_path)

      namespace = ensure_namespace(namespace_path)
      namespace.variables[name] = { value: value, local: local || namespace.local_name?(name) }
    end

    # Defines a new function within a specified namespace.
    #
    # @param namespace_path [String, nil] The path of the namespace where the function is defined.
    # @param name [String] The name of the function.
    # @param value [Object] The value (e.g., LambdaValue) of the function.
    # @param local [Boolean] True if the function is local to its defining scope, false otherwise.
    # @raise [Calc::NameError] If attempting to modify a reserved namespace.
    def define_function(namespace_path, name, value, local: false)
      raise Calc::NameError, "cannot modify reserved namespace: builtin" if reserved_namespace?(namespace_path)

      namespace = ensure_namespace(namespace_path)
      namespace.functions[name] =
        { value: value, namespace: namespace.path, local: local || namespace.local_name?(name) }
    end

    # Resolves a variable's value given a namespace path and variable name.
    # Searches up the namespace hierarchy.
    #
    # @param namespace_path [String, nil] The starting namespace path for resolution.
    # @param name [String] The name of the variable to resolve.
    # @return [Hash, nil] A hash containing `:value` and `:local` if found, otherwise nil.
    def resolve_variable(namespace_path, name)
      resolve(namespace_path, name, :variables)
    end

    # Resolves a function's value given a namespace path and function name.
    # Searches up the namespace hierarchy.
    #
    # @param namespace_path [String, nil] The starting namespace path for resolution.
    # @param name [String] The name of the function to resolve.
    # @return [Hash, nil] A hash containing `:value`, `:namespace`, and `:local` if found, otherwise nil.
    def resolve_function(namespace_path, name)
      resolve(namespace_path, name, :functions)
    end

    # Returns the full path of the current effective namespace.
    #
    # @param namespace_path [String, nil] The current namespace path.
    # @return [String, nil] The full path string, or nil if no active namespace.
    def current_namespace_path(namespace_path)
      namespace = namespace_or_nil(namespace_path)
      namespace&.path
    end

    # Retrieves a list of all qualified (including namespace) function identifiers.
    #
    # @return [Array<String>] A unique list of function identifiers.
    def function_identifiers
      identifiers = @root.functions.keys.dup

      each_namespace do |namespace|
        namespace_path = namespace.path

        namespace.functions.each_key do |name|
          identifiers << "#{namespace_path}.#{name}" if namespace_path && namespace_path != "builtin"
        end
      end

      identifiers.uniq
    end

    # Retrieves a list of all qualified (including namespace) variable identifiers.
    #
    # @return [Array<String>] A unique list of variable identifiers.
    def variable_identifiers
      identifiers = @root.variables.keys.dup

      each_namespace do |namespace|
        namespace_path = namespace.path

        namespace.variables.each_key do |name|
          identifiers << "#{namespace_path}.#{name}" if namespace_path && namespace_path != "builtin"
        end
      end

      identifiers.uniq
    end

    # Retrieves a list of unqualified identifiers (functions and variables) accessible
    # from a given namespace, respecting local binding rules.
    #
    # @param namespace_path [String, nil] The namespace path to check accessibility from.
    # @return [Array<String>] A unique list of accessible unqualified identifiers.
    def accessible_unqualified_identifiers(namespace_path)
      namespace = nearest_existing_namespace(namespace_path)
      return [] unless namespace

      identifiers = []
      origin = namespace
      while namespace
        namespace.functions.each do |name, entry|
          identifiers << name if !entry[:local] || namespace.equal?(origin)
        end

        namespace.variables.each do |name, entry|
          identifiers << name if !entry[:local] || namespace.equal?(origin)
        end

        namespace = namespace.parent
      end

      identifiers.uniq
    end

    private

    # Recursively iterates through all child namespaces.
    #
    # @param namespace [Namespace] The starting namespace for iteration (defaults to root).
    # @yieldparam child [Namespace] Each child namespace.
    def each_namespace(namespace = @root, &block)
      namespace.children.each_value do |child|
        yield child
        each_namespace(child, &block)
      end
    end

    # Finds the nearest existing namespace by traversing up the parent chain
    # from a given path.
    #
    # @param namespace_path [String, nil] The starting namespace path.
    # @return [Namespace, nil] The nearest existing Namespace, or nil if none found.
    def nearest_existing_namespace(namespace_path)
      current = namespace_path

      while current && !current.empty?
        namespace = namespace_or_nil(current)
        return namespace if namespace

        current = parent_namespace_path(current)
      end

      nil
    end

    # Extracts the parent namespace path from a full namespace path string.
    #
    # @param namespace_path [String] The full namespace path.
    # @return [String, nil] The parent namespace path, or nil if already at the root.
    def parent_namespace_path(namespace_path)
      dot_index = namespace_path.rindex(".")
      return nil unless dot_index

      namespace_path[0...dot_index]
    end

    # Generic method to resolve either variables or functions within the namespace hierarchy.
    # Handles both fully qualified names (e.g., "my.namespace.var") and unqualified names.
    #
    # @param namespace_path [String, nil] The starting namespace path for resolution.
    # @param name [String] The name (potentially qualified) of the entity to resolve.
    # @param bucket [Symbol] The symbol representing the storage (e.g., `:variables`, `:functions`).
    # @return [Hash, nil] The resolved entry (value and metadata), or nil if not found.
    def resolve(namespace_path, name, bucket)
      if name.to_s.include?(".")
        name_string = name.to_s
        dot_index = name_string.rindex(".")
        namespace_path = name_string[0...dot_index]
        name = name_string[(dot_index + 1)..]
        return exact_namespace_lookup(namespace_path, name, bucket)
      end

      namespace = namespace_or_nil(namespace_path)
      origin = namespace
      while namespace
        entry = namespace.public_send(bucket)[name]
        return entry if entry && (!entry[:local] || namespace.equal?(origin))

        namespace = namespace.parent
      end

      builtin = @root.children["builtin"]
      return builtin.public_send(bucket)[name] if builtin&.public_send(bucket)&.key?(name)

      nil
    end

    # Performs an exact lookup for a variable or function within a specific, fully qualified namespace.
    # Does not search parent namespaces.
    #
    # @param namespace_path [String] The full path of the namespace to search.
    # @param name [String] The name of the entity to resolve.
    # @param bucket [Symbol] The symbol representing the storage (e.g., `:variables`, `:functions`).
    # @return [Hash, nil] The resolved entry, or nil if not found.
    def exact_namespace_lookup(namespace_path, name, bucket)
      namespace = namespace_or_nil(namespace_path)
      return nil unless namespace

      entry = namespace.public_send(bucket)[name]
      return entry if entry

      builtin = @root.children["builtin"]
      return builtin.public_send(bucket)[name] if namespace_path == "builtin" && builtin&.public_send(bucket)&.key?(name)

      nil
    end

    # Safely retrieves a namespace by path, returning nil if not found instead of raising an error.
    #
    # @param path [String, nil] The path of the namespace.
    # @return [Namespace, nil] The Namespace object, or nil if not found.
    def namespace_or_nil(path)
      namespace(path)
    rescue Calc::NameError
      nil
    end
  end
end
