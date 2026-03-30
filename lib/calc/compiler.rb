require_relative "bytecode"

module Calc
  # Translates a Calc AST into Bytecode::CodeObject instances.
  # Phase 1 only adds compilation and disassembly; runtime execution remains tree-walk.
  # rubocop:disable Metrics/ClassLength
  class Compiler
    include Bytecode

    def initialize(builtins)
      @builtins = builtins
    end

    def compile_program(nodes, name: "<program>")
      code = CodeObject.new(name: name)
      return code if nodes.empty?

      nodes.each_with_index do |node, index|
        compile_node(node, code)
        code.emit(:pop) if index < nodes.length - 1
      end
      code
    end

    def compile(node, name: "<expr>")
      code = CodeObject.new(name: name)
      compile_node(node, code)
      code
    end

    private

    def compile_node(node, code)
      case node
      when NumberNode, StringNode
        code.emit(:push_const, node.value, line: node.line, column: node.column)
      when KeywordNode
        code.emit(:push_keyword, node.name, line: node.line, column: node.column)
      when SymbolNode
        compile_symbol(node, code)
      when LambdaNode
        compile_lambda_node(node, code)
      when ListNode
        compile_list(node, code)
      else
        raise Calc::RuntimeError, "unknown node type: #{node.class}"
      end
    end

    def compile_symbol(node, code)
      case node.name
      when "true"
        code.emit(:push_const, true, line: node.line, column: node.column)
      when "false"
        code.emit(:push_const, false, line: node.line, column: node.column)
      when "nil"
        code.emit(:push_const, nil, line: node.line, column: node.column)
      else
        code.emit(:load, node.name, line: node.line, column: node.column)
      end
    end

    def compile_lambda_node(node, code)
      body_code = compile_body_node(node.body)
      code.emit(:make_closure, { params: node.params, ast_body: node.body, code: body_code },
                line: node.line, column: node.column)
    end

    def compile_list(node, code)
      head = node.children.first
      args = node.children.drop(1)

      if head.is_a?(SymbolNode)
        compile_named_list(node, code, head, args)
      else
        compile_node(head, code)
        args.each { |arg| compile_node(arg, code) }
        code.emit(:call, args.length, line: node.line, column: node.column)
      end
    end

    def compile_named_list(node, code, head, args)
      case head.name
      when "define"
        compile_define(node.children, code)
      when "if"
        compile_if(node.children, code)
      when "and"
        compile_and(node.children, code)
      when "or"
        compile_or(node.children, code)
      when "cond"
        compile_cond(node.children, code)
      when "namespace"
        compile_namespace(node.children, code)
      when "lambda"
        compile_lambda(node.children, code)
      when "do"
        compile_do(node.children, code)
      when "load"
        compile_load(node.children, code)
      else
        code.emit(:load_fn, head.name, line: head.line, column: head.column)
        args.each { |arg| compile_node(arg, code) }
        code.emit(:call, args.length, line: node.line, column: node.column)
      end
    end

    def compile_define(children, code)
      if children[1].is_a?(ListNode)
        compile_define_function(children, code)
      else
        compile_define_variable(children, code)
      end
    end

    def compile_define_variable(children, code)
      name_node = children[1]
      value_node = children[2]
      raise Calc::SyntaxError, "invalid define" unless name_node.is_a?(SymbolNode) && value_node

      compile_node(value_node, code)
      code.emit(:store, name_node.name, line: name_node.line, column: name_node.column)
    end

    def compile_define_function(children, code)
      signature = children[1]
      name_node = signature.children.first
      param_nodes = signature.children.drop(1)
      body_node = normalized_body_node(children, 2)
      raise Calc::SyntaxError, "invalid function definition" unless name_node.is_a?(SymbolNode) && body_node

      params = normalize_param_nodes(param_nodes)
      body_code = compile_body_node(body_node, name: name_node.name)

      code.emit(:make_closure, { params: params, ast_body: body_node, code: body_code },
                line: name_node.line, column: name_node.column)
      code.emit(:store_fn, name_node.name, line: name_node.line, column: name_node.column)
    end

    def compile_lambda(children, code)
      params_node = children[1]
      body_node = normalized_body_node(children, 2)
      raise Calc::SyntaxError, "invalid lambda" unless params_node.is_a?(ListNode) && body_node

      params = normalize_param_nodes(params_node.children)
      body_code = compile_body_node(body_node)
      code.emit(:make_closure, { params: params, ast_body: body_node, code: body_code },
                line: params_node.line, column: params_node.column)
    end

    def compile_if(children, code)
      condition_node = children[1]
      then_node = children[2]
      else_node = children[3]
      raise Calc::SyntaxError, "invalid if" unless children.length == 4 && condition_node && then_node && else_node

      compile_node(condition_node, code)
      jump_false_index = code.emit(:jump_false, nil)
      compile_node(then_node, code)
      jump_end_index = code.emit(:jump, nil)
      code.patch(jump_false_index, code.size)
      compile_node(else_node, code)
      code.patch(jump_end_index, code.size)
    end

    def compile_and(children, code)
      values = children.drop(1)
      if values.empty?
        code.emit(:push_const, true)
        return
      end

      jump_indices = []
      values[0..-2].each do |value_node|
        compile_node(value_node, code)
        code.emit(:dup)
        jump_indices << code.emit(:jump_false, nil)
        code.emit(:pop)
      end

      compile_node(values.last, code)

      end_index = code.size
      jump_indices.each { |index| code.patch(index, end_index) }
    end

    def compile_or(children, code)
      values = children.drop(1)
      if values.empty?
        code.emit(:push_const, false)
        return
      end

      end_jumps = []
      values[0..-2].each do |value_node|
        compile_node(value_node, code)
        code.emit(:dup)
        jump_false_index = code.emit(:jump_false, nil)
        end_jumps << code.emit(:jump, nil)
        code.patch(jump_false_index, code.size)
        code.emit(:pop)
      end

      compile_node(values.last, code)
      code.emit(:dup)
      jump_true_index = code.emit(:jump_true, nil)
      code.emit(:pop)
      code.emit(:push_const, false)

      end_index = code.size
      code.patch(jump_true_index, end_index)
      end_jumps.each { |index| code.patch(index, end_index) }
    end

    def compile_cond(children, code)
      clauses = children.drop(1)
      raise Calc::SyntaxError, "invalid cond" if clauses.empty?

      validate_cond_clauses!(clauses)

      has_else = false
      end_jumps = []

      clauses.each do |clause_node|
        test_node, body_node = clause_node.children
        if else_clause?(test_node)
          has_else = true
          compile_node(body_node, code)
          end_jumps << code.emit(:jump, nil)
        else
          compile_cond_test_clause(test_node, body_node, code, end_jumps)
        end
      end

      code.emit(:push_const, nil) unless has_else

      end_index = code.size
      end_jumps.each { |index| code.patch(index, end_index) }
    end

    def validate_cond_clauses!(clauses)
      clauses.each_with_index do |clause_node, index|
        raise Calc::SyntaxError, "invalid cond" unless clause_node.is_a?(ListNode) && clause_node.children.length == 2

        test_node, = clause_node.children
        next unless else_clause?(test_node)

        raise Calc::SyntaxError, "invalid cond" unless index == clauses.length - 1
      end
    end

    def else_clause?(test_node)
      test_node.is_a?(SymbolNode) && test_node.name == "else"
    end

    def compile_cond_test_clause(test_node, body_node, code, end_jumps)
      compile_node(test_node, code)
      jump_false_index = code.emit(:jump_false, nil)
      compile_node(body_node, code)
      end_jumps << code.emit(:jump, nil)
      code.patch(jump_false_index, code.size)
    end

    def compile_namespace(children, code)
      namespace_node = children[1]
      body_nodes = children.drop(2)
      raise Calc::SyntaxError, "invalid namespace" unless namespace_node.is_a?(SymbolNode)

      code.emit(:enter_ns, namespace_node.name, line: namespace_node.line, column: namespace_node.column)

      if body_nodes.empty?
        code.emit(:push_const, nil)
      else
        body_nodes.each_with_index do |body_node, index|
          compile_node(body_node, code)
          code.emit(:pop) if index < body_nodes.length - 1
        end
      end

      code.emit(:leave_ns)
    end

    def compile_do(children, code)
      nodes = children.drop(1)
      raise Calc::SyntaxError, "invalid do" if nodes.empty?

      nodes.each_with_index do |node, index|
        compile_node(node, code)
        code.emit(:pop) if index < nodes.length - 1
      end
    end

    def compile_load(children, code)
      path_node = children[1]
      raise Calc::SyntaxError, "invalid load" unless path_node
      raise Calc::SyntaxError, "load path must be a string" unless path_node.is_a?(StringNode)

      code.emit(:load_file, { path: path_node.value, namespace: extract_load_namespace(children) },
                line: path_node.line, column: path_node.column)
    end

    def extract_load_namespace(children)
      as_index = children.index { |child| child.is_a?(KeywordNode) && child.name == "as" }
      return nil unless as_index

      namespace_node = children[as_index + 1]
      case namespace_node
      when StringNode
        namespace_node.value
      when SymbolNode
        namespace_node.name
      else
        raise Calc::SyntaxError, "load namespace must be a symbol or string"
      end
    end

    def compile_body_node(node, name: nil)
      body_code = CodeObject.new(name: name)
      compile_node(node, body_code)
      body_code
    end

    def normalized_body_node(children, start_index)
      body_nodes = children.drop(start_index)
      return nil if body_nodes.empty?
      return body_nodes.first if body_nodes.length == 1

      first = body_nodes.first
      do_symbol = SymbolNode.new("do", first.line, first.column)
      ListNode.new([do_symbol, *body_nodes], first.line, first.column)
    end

    def normalize_param_nodes(param_nodes)
      param_nodes.map do |param_node|
        raise Calc::SyntaxError, "invalid function parameter" unless param_node.is_a?(SymbolNode)

        param_node.name
      end
    end
  end
  # rubocop:enable Metrics/ClassLength
end
