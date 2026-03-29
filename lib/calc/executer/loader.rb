require "pathname"

module Calc
  class Executer
    # Module responsible for loading external files and managing the environment
    # (namespace, current file path) during the loading process.
    # Contains the evaluation logic for the `load` special form.
    module Loader
      private

      # Evaluates the `load` special form. Reads the specified file and
      # evaluates it, optionally within a specific namespace.
      # Detects cyclic dependencies and skips already loaded files.
      #
      # @param children [Array<Calc::Node>] An array of child nodes of the `load` expression.
      # @return [Object, nil] The result of the last expression evaluated in the loaded file, or nil.
      # @raise [Calc::SyntaxError] If the syntax is invalid.
      # @raise [Calc::RuntimeError] If a cyclic dependency is detected or the file is not found.
      def evaluate_load(children)
        load_node = children[1]
        raise Calc::SyntaxError, "invalid load" unless load_node

        path = load_path_from_node(load_node)
        namespace = load_namespace_from_children(children)
        resolved_path = resolve_load_path(path)
        return nil if @loaded_files[resolved_path]

        raise Calc::RuntimeError, "cyclic load detected: #{resolved_path}" if @loading_stack.include?(resolved_path)

        source = File.read(resolved_path)
        @loading_stack << resolved_path

        result = if namespace
                   with_namespace(namespace_path(namespace)) { evaluate_source(source, source_path: resolved_path) }
                 else
                   evaluate_source(source, source_path: resolved_path)
                 end

        @loaded_files[resolved_path] = true
        result
      ensure
        @loading_stack.pop if @loading_stack.last == resolved_path
      end

      # Executes a block within a specified namespace and restores the original
      # namespace afterward.
      #
      # @param namespace [String] The namespace to execute within.
      # @yield The code block to execute.
      def with_namespace(namespace)
        previous_namespace = @current_namespace
        @current_namespace = namespace
        @namespace_stack << namespace
        @namespaces.ensure_namespace(namespace)
        yield
      ensure
        @namespace_stack.pop
        @current_namespace = previous_namespace
      end

      # Sets the current source file path for the duration of a block, then restores
      # the previous path. Used for error contextualization.
      #
      # @param path [String, nil] The source file path to set.
      # @yield The code block to execute.
      def with_source_path(path)
        previous_path = @current_file
        @current_file = path || @current_file
        yield
      ensure
        @current_file = previous_path
      end

      # Extracts the load path string from an AST node.
      #
      # @param node [Calc::Node] The AST node representing the load path.
      # @return [String] The load path.
      # @raise [Calc::SyntaxError] If the node is not a StringNode.
      def load_path_from_node(node)
        raise Calc::SyntaxError, "load path must be a string" unless node.is_a?(StringNode)

        node.value
      end

      # Extracts namespace information from the child nodes of a `load` expression.
      # Supports the form `(load "file" as namespace)`.
      #
      # @param children [Array<Calc::Node>] An array of child nodes of the `load` expression.
      # @return [String, nil] The specified namespace, or nil.
      # @raise [Calc::SyntaxError] If the syntax is invalid.
      def load_namespace_from_children(children)
        return nil if children.length == 2
        raise Calc::SyntaxError, "invalid load" unless children.length == 4

        marker = children[2]
        namespace_node = children[3]
        raise Calc::SyntaxError, "invalid load" unless marker.is_a?(KeywordNode) && marker.name == "as"

        case namespace_node
        when SymbolNode
          namespace_node.name
        when StringNode
          namespace_node.value
        else
          raise Calc::SyntaxError, "load namespace must be a symbol or string"
        end
      end

      # Resolves a file path to be loaded, considering relative paths and search paths.
      #
      # @param path [String] The path of the file to be loaded.
      # @return [String] The resolved absolute path.
      # @raise [Calc::RuntimeError] If the file is not found.
      def resolve_load_path(path)
        current_file = @current_file && normalize_path(@current_file)

        candidates_for(path).each do |candidate|
          absolute = normalize_path(candidate)
          next if current_file && absolute == current_file

          return absolute if File.file?(absolute)
        end

        raise Calc::RuntimeError, "load file not found: #{path}"
      end

      # Generates candidate paths for a given path, based on various search roots.
      #
      # @param path [String] The path to generate candidates for.
      # @return [Array<String>] An array of candidate file paths.
      def candidates_for(path)
        if File.extname(path).empty?
          search_roots.flat_map do |root|
            base = File.join(root, path)
            [base, "#{base}.calc"]
          end
        elsif Pathname.new(path).absolute?
          [path]
        else
          search_roots.map { |root| File.join(root, path) }
        end
      end

      # Generates a list of root directories for searching files.
      # Includes paths relative to the current source file, module directories,
      # user module directories, and bundled standard library roots.
      #
      # @return [Array<String>] An array of search root directories.
      def search_roots
        from_source = @current_file ? File.dirname(@current_file) : nil
        roots = [
          from_source,
          source_test_parent_root(from_source),
          File.join(Dir.pwd, "modules"),
          Dir.pwd,
          user_modules_root,
          bundled_stdlib_root
        ].compact
        roots.uniq
      end

      # Returns the path to the user's module directory.
      # Determined based on XDG_CONFIG_HOME or the user's home directory.
      #
      # @return [String, nil] The path to the user's module directory, or nil.
      def user_modules_root
        config_home = ENV.fetch("XDG_CONFIG_HOME", nil)
        base = if config_home && !config_home.empty?
                 File.expand_path(config_home)
               elsif (home = safe_home_directory) && !home.empty?
                 File.join(home, ".config")
               else
                 return nil
               end

        File.join(base, "calc", "modules")
      end

      # Returns the path to the root directory of the bundled standard library.
      #
      # @return [String] The path to the standard library root.
      def bundled_stdlib_root
        File.expand_path("../../../stdlib", __dir__)
      end

      # Returns the parent root directory if the source file is within a test directory.
      #
      # @param from_source [String, nil] The path of the current source file.
      # @return [String, nil] The parent root directory path, or nil.
      def source_test_parent_root(from_source)
        return nil unless from_source

        expanded = File.expand_path(from_source)
        return nil unless expanded.match?(%r{/((stdlib|modules|samples))/test(?:/|\z)})

        parent = expanded.sub(%r{/test(?:/[^/]+)*\z}, "")
        parent.empty? ? nil : parent
      end

      # Safely retrieves the user's home directory.
      #
      # @return [String, nil] The path to the home directory, or nil if an error occurs.
      def safe_home_directory
        Dir.home
      rescue StandardError
        nil
      end

      # Normalizes a path (resolves symlinks, converts to absolute path).
      #
      # @param path [String] The path to normalize.
      # @return [String] The normalized path.
      def normalize_path(path)
        File.realpath(path)
      rescue StandardError
        File.expand_path(path)
      end
    end
  end
end
