require "reline"

module Calc
  module Cli
    # Entry point for the first VM debugger CLI flow.
    # This version establishes the debug command wiring and a minimal prompt loop.
    class DebugRunner
      PROMPT = "(calcdb) ".freeze
      Context = Struct.new(:parser, :compiler, :executer, :script_path, :io, :history)

      def self.run(context)
        new(context).run
      end

      def initialize(context)
        @parser = context.parser
        @compiler = context.compiler
        @executer = context.executer
        @script_path = context.script_path
        @source = nil
        @code = nil
        @nodes = []
        @cursor = 0
        @skip_breakpoint_once = false
        @breakpoint_manager = Calc::Cli::DebugBreakpointManager.new
        @state = Calc::DebuggerState.new
        @out = context.io.fetch(:out)
        @err = context.io.fetch(:err)
        @in = context.io.fetch(:in, $stdin)
        @history = context.history || Reline::HISTORY
        @last_command = nil
      end

      def run
        @source = File.read(@script_path)
        @nodes = @parser.parse(@source)
        @code = @compiler.compile_program(@nodes, name: @script_path)

        @state.start!
        @out.puts "debugger scaffold loaded for #{@script_path}"
        @out.puts @code.disassemble
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
          line = read_command
          break if line.nil?

          command = line.strip
          next if command.empty?

          @history << command if command != @last_command
          @last_command = command

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

      def read_command
        if @in.tty?
          Reline.readline(PROMPT, true)
        else
          @out.print PROMPT
          @out.flush
          @in.gets&.chomp
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
        when "list"
          render_list(payload)
        when "bt", "locals", "print"
          print_not_implemented(command, payload)
        end
      end

      def create_breakpoint(payload)
        breakpoint = @breakpoint_manager.create(payload, valid_lines: @nodes.map(&:line))
        @out.puts "Breakpoint #{breakpoint.id} set"
      rescue ArgumentError => e
        @err.puts e.message
      end

      def execute_until_breakpoint
        pause_reason = nil

        while @cursor < @nodes.length
          node = @nodes[@cursor]
          if @skip_breakpoint_once
            @skip_breakpoint_once = false
          elsif @breakpoint_manager.hit?(node)
            pause_reason = :breakpoint
            @out.puts @breakpoint_manager.hit_message(node)
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
      rescue StandardError => e
        @err.puts e.message
        @state.pause!(reason: :run_failed)
      end

      def step_execution
        return print_not_implemented("step", nil) unless @state.paused? || @state.running?

        pause_reason = @state.pause_reason
        @state.resume! if @state.paused?
        @skip_breakpoint_once = true if pause_reason == :breakpoint
        run_single_node(reason: :step_complete)
        @skip_breakpoint_once = false
        @out.puts "Reached end of program" if @cursor >= @nodes.length
      end

      def finish_execution
        return print_not_implemented("finish", nil) unless @state.paused? || @state.running?

        pause_reason = @state.pause_reason
        @state.resume! if @state.paused?
        @skip_breakpoint_once = true if pause_reason == :breakpoint
        execute_remaining_nodes
        @skip_breakpoint_once = false
      rescue StandardError => e
        @err.puts e.message
        @state.pause!(reason: :run_failed)
        @skip_breakpoint_once = false
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

      def render_list(payload)
        DebugListCommand.new(
          context: DebugListCommand::Context.new(
            @source,
            @code,
            @nodes,
            @cursor,
            @breakpoint_manager.line_breakpoint_targets,
            DebugSourceLineMapper.new(@source, @nodes)
          ),
          out: @out
        ).call(payload)
      rescue ArgumentError => e
        @err.puts e.message
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
