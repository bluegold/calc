module Calc
  module Cli
    # Entry point for the first VM debugger CLI flow.
    # This version establishes the debug command wiring and a minimal prompt loop.
    class DebugRunner
      PROMPT = "(calcdb) ".freeze

      def self.run(parser, compiler, executer, script_path, io:)
        new(parser, compiler, executer, script_path, io: io).run
      end

      def initialize(parser, compiler, executer, script_path, io:)
        @parser = parser
        @compiler = compiler
        @executer = executer
        @script_path = script_path
        @source = nil
        @nodes = []
        @cursor = 0
        @skip_breakpoint_once = false
        @breakpoints = []
        @breakpoint_seq = 0
        @state = Calc::DebuggerState.new
        @out = io.fetch(:out)
        @err = io.fetch(:err)
        @in = io.fetch(:in, $stdin)
      end

      def run
        @source = File.read(@script_path)
        @nodes = @parser.parse(@source)
        code = @compiler.compile_program(@nodes, name: @script_path)

        @state.start!
        @out.puts "debugger scaffold loaded for #{@script_path}"
        @out.puts code.disassemble
        run_prompt_loop
        @state.terminate! unless @state.terminated?
        0
      rescue StandardError => e
        @state.terminate! unless @state.terminated?
        @err.puts e.message
        1
      end

      private

      def run_prompt_loop
        loop do
          @out.print PROMPT
          @out.flush

          line = @in.gets
          break if line.nil?

          command = line.strip
          next if command.empty?

          command_name, payload = command.split(/\s+/, 2)

          case command_name
          when "quit"
            @state.terminate!
            return
          when "run"
            handle_run_command
            return if @state.terminated?
          when "continue", "step", "next", "finish", "break", "bt", "locals", "print", "list"
            handle_debugger_command(command_name, payload)
          when "help"
            print_help
          else
            @err.puts "unknown debugger command: #{command_name}"
          end
        end
      end

      def handle_run_command
        @cursor = 0
        @skip_breakpoint_once = false
        @state.resume! if @state.paused?
        @state.start! if @state.idle?
        execute_until_breakpoint
      rescue StandardError => e
        @err.puts e.message
        @state.pause!(reason: :run_failed)
      end

      def handle_debugger_command(command, payload)
        case command
        when "break"
          create_breakpoint(payload)
        when "continue"
          resume_execution
        when "step", "next"
          step_execution
        when "finish"
          finish_execution
        when "bt", "locals", "print", "list"
          print_not_implemented(command, payload)
        end
      end

      def create_breakpoint(payload)
        kind, target = parse_breakpoint_target(payload)
        @breakpoint_seq += 1
        breakpoint = Calc::Breakpoint.new(id: @breakpoint_seq, kind: kind, target: target)
        @breakpoints << breakpoint
        @out.puts "Breakpoint #{@breakpoint_seq} set"
      rescue ArgumentError => e
        @err.puts e.message
      end

      def parse_breakpoint_target(payload)
        raise ArgumentError, "usage: break <line>|<function>" if payload.to_s.strip.empty?

        text = payload.strip
        return [:line, Integer(text, 10)] if text.match?(/\A\d+\z/)

        [:function, text]
      end

      def execute_until_breakpoint
        pause_reason = nil

        while @cursor < @nodes.length
          node = @nodes[@cursor]
          if @skip_breakpoint_once
            @skip_breakpoint_once = false
          elsif breakpoint_hit?(node)
            pause_reason = :breakpoint
            @out.puts format_breakpoint_hit(node)
            break
          end

          result = @executer.evaluate_nodes([node], source_path: @script_path)
          @out.puts Calc.format_value(result) unless result.nil?
          @cursor += 1
        end

        @state.pause!(reason: pause_reason || :run_complete)
      end

      def resume_execution
        return print_not_implemented("continue", nil) unless @state.paused?

        pause_reason = @state.pause_reason
        @state.resume!
        @skip_breakpoint_once = true if pause_reason == :breakpoint
        execute_until_breakpoint
      end

      def step_execution
        return print_not_implemented("step", nil) unless @state.paused? || @state.running?

        pause_reason = @state.pause_reason
        @state.resume! if @state.paused?
        @skip_breakpoint_once = true if pause_reason == :breakpoint
        run_single_node(reason: :step_complete)
      end

      def finish_execution
        return print_not_implemented("finish", nil) unless @state.paused? || @state.running?

        pause_reason = @state.pause_reason
        @state.resume! if @state.paused?
        @skip_breakpoint_once = true if pause_reason == :breakpoint
        execute_remaining_nodes
      end

      def run_single_node(reason:)
        if @cursor < @nodes.length
          node = @nodes[@cursor]
          result = @executer.evaluate_nodes([node], source_path: @script_path)
          @out.puts Calc.format_value(result) unless result.nil?
          @cursor += 1
        end

        @state.pause!(reason: reason)
      rescue StandardError => e
        @err.puts e.message
        @state.pause!(reason: :run_failed)
      end

      def execute_remaining_nodes
        while @cursor < @nodes.length
          node = @nodes[@cursor]
          result = @executer.evaluate_nodes([node], source_path: @script_path)
          @out.puts Calc.format_value(result) unless result.nil?
          @cursor += 1
        end

        @state.pause!(reason: :run_complete)
      rescue StandardError => e
        @err.puts e.message
        @state.pause!(reason: :run_failed)
      end

      def breakpoint_hit?(node)
        @breakpoints.any? do |breakpoint|
          if breakpoint.line?
            breakpoint.target == node.line
          else
            function_breakpoint_hit?(breakpoint, node)
          end
        end
      end

      def function_breakpoint_hit?(breakpoint, node)
        return false unless node.is_a?(Calc::ListNode) && node.children.first.is_a?(Calc::SymbolNode)

        head = node.children.first
        head.name == breakpoint.target || define_function_breakpoint_hit?(breakpoint, node, head)
      end

      def define_function_breakpoint_hit?(breakpoint, node, head)
        return false unless head.name == "define" && node.children[1].is_a?(Calc::ListNode)

        signature = node.children[1]
        signature.children.first.is_a?(Calc::SymbolNode) && signature.children.first.name == breakpoint.target
      end

      def format_breakpoint_hit(node)
        line = node.line || 0
        "Breakpoint hit at L#{line}"
      end

      def print_not_implemented(command, payload)
        command_text = payload ? "#{command} #{payload}" : command
        @out.puts "#{command_text} is not implemented yet"
      end

      def print_help
        @out.puts "Commands:"
        @out.puts "  run              Start program execution"
        @out.puts "  continue         Resume execution after a pause"
        @out.puts "  step             Step into the next stoppable instruction"
        @out.puts "  next             Step over the current frame"
        @out.puts "  finish           Run until the current frame returns"
        @out.puts "  break <target>   Set a breakpoint by function or line"
        @out.puts "  bt               Show the current backtrace"
        @out.puts "  locals           Show locals for the selected frame"
        @out.puts "  print <expr>     Evaluate an expression in the paused context"
        @out.puts "  list [n] [bytecode]  Show nearby source lines, optionally with bytecode"
        @out.puts "  help             Show this help"
        @out.puts "  quit             Exit the debugger"
      end
    end
  end
end
