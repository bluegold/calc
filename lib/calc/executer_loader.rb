require "pathname"

module Calc
  class Executer
    private

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

    def with_source_path(path)
      previous_path = @current_file
      @current_file = path || @current_file
      yield
    ensure
      @current_file = previous_path
    end

    def load_path_from_node(node)
      raise Calc::SyntaxError, "load path must be a string" unless node.is_a?(StringNode)

      node.value
    end

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

    def resolve_load_path(path)
      candidates_for(path).each do |candidate|
        absolute = normalize_path(candidate)
        return absolute if File.file?(absolute)
      end

      raise Calc::RuntimeError, "load file not found: #{path}"
    end

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

    def search_roots
      from_source = @current_file ? File.dirname(@current_file) : nil
      roots = [from_source, Dir.pwd, File.join(Dir.pwd, "stdlib")].compact
      roots.uniq
    end

    def normalize_path(path)
      File.realpath(path)
    rescue StandardError
      File.expand_path(path)
    end
  end
end
