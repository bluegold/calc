module Calc
  class Executer
    def initialize(environment = Environment.new)
      @environment = environment
    end

    def evaluate(node)
      case node
      when NumberNode
        node.value
      when SymbolNode
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

      value = evaluate(value_node)
      @environment.set(name_node.name, value)
      value
    end

    def call_function(name, args)
      values = args.map { |arg| evaluate(arg) }

      case name
      when "+" then values.sum
      when "-" then values.length == 1 ? -values.first : values.reduce { |memo, v| memo - v }
      when "*" then values.reduce(1, :*)
      when "/" then values.reduce { |memo, v| memo / v }
      else
        raise NameError, "unknown function: #{name}"
      end
    end
  end
end
