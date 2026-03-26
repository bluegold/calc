module Calc
  class NamespaceRegistry
    Namespace = Struct.new(:name, :parent, :children, :variables, :functions) do
      def initialize(name:, parent: nil)
        super
        self.children ||= {}
        self.variables ||= {}
        self.functions ||= {}
      end

      def local_name?(identifier)
        identifier.start_with?("_")
      end

      def child(name)
        children[name] ||= Namespace.new(name: name, parent: self)
      end

      def path
        return name unless parent
        return name if parent.parent.nil?

        [parent.path, name].join(".")
      end
    end

    def initialize
      @root = Namespace.new(name: nil)
      ensure_namespace("builtin")
    end

    def reserved_namespace?(path)
      path.to_s == "builtin"
    end

    attr_reader :root

    def ensure_namespace(path)
      return @root if path.nil? || path.to_s.empty?

      names = path.to_s.split(".")
      names.reduce(@root) { |namespace, name| namespace.child(name) }
    end

    def namespace(path)
      return @root if path.nil? || path.to_s.empty?

      names = path.to_s.split(".")
      names.reduce(@root) do |namespace, name|
        namespace.children[name] || raise(NameError, "unknown namespace: #{path}")
      end
    end

    def define_variable(namespace_path, name, value, local: false)
      raise NameError, "cannot modify reserved namespace: builtin" if reserved_namespace?(namespace_path)

      namespace = ensure_namespace(namespace_path)
      namespace.variables[name] = { value: value, local: local || namespace.local_name?(name) }
    end

    def define_function(namespace_path, name, value, local: false)
      raise NameError, "cannot modify reserved namespace: builtin" if reserved_namespace?(namespace_path)

      namespace = ensure_namespace(namespace_path)
      namespace.functions[name] =
        { value: value, namespace: namespace.path, local: local || namespace.local_name?(name) }
    end

    def resolve_variable(namespace_path, name)
      resolve(namespace_path, name, :variables)
    end

    def resolve_function(namespace_path, name)
      resolve(namespace_path, name, :functions)
    end

    def current_namespace_path(namespace_path)
      namespace = namespace_or_nil(namespace_path)
      namespace&.path
    end

    private

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

    def exact_namespace_lookup(namespace_path, name, bucket)
      namespace = namespace_or_nil(namespace_path)
      return nil unless namespace

      entry = namespace.public_send(bucket)[name]
      return entry if entry

      builtin = @root.children["builtin"]
      return builtin.public_send(bucket)[name] if namespace_path == "builtin" && builtin&.public_send(bucket)&.key?(name)

      nil
    end

    def namespace_or_nil(path)
      namespace(path)
    rescue NameError
      nil
    end
  end
end
