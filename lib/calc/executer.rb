module Calc
  class Executer
    def initialize(environment = Environment.new, builtins = Builtins.new)
      @environment = environment
      @builtins = builtins
    end

    def evaluate(node)
      case node
      when NumberNode
        node.value
      when SymbolNode
        found, builtin = @builtins.resolve(node.name)
        return builtin if found

        @environment.get(node.name)
      when ListNode
        evaluate_list(node)
      else
        raise ArgumentError, "unknown node: #{node.class}"
      end
    end

    private

    def evaluate_list(node)
      head = node.children.first
      case head
      when SymbolNode
        if head.name == "define"
          define_variable(node.children)
        elsif head.name == "if"
          evaluate_if(node.children)
        else
          call_function(head.name, node.children.drop(1))
        end
      else
        raise ArgumentError, "invalid expression"
      end
    end

    def define_variable(children)
      name_node = children[1]
      value_node = children[2]
      raise ArgumentError, "invalid define" unless name_node.is_a?(SymbolNode) && value_node
      raise NameError, "cannot redefine reserved literal: #{name_node.name}" if @builtins.reserved?(name_node.name)

      value = evaluate(value_node)
      @environment.set(name_node.name, value)
      value
    end

    def evaluate_if(children)
      condition_node = children[1]
      then_node = children[2]
      else_node = children[3]
      raise ArgumentError, "invalid if" unless children.length == 4 && condition_node && then_node && else_node

      condition = evaluate(condition_node)
      truthy?(condition) ? evaluate(then_node) : evaluate(else_node)
    end

    def truthy?(value)
      value != false && !value.nil?
    end

    def call_function(name, args)
      values = args.map { |arg| evaluate(arg) }

      @builtins.call(name, values)
    end
  end
end
