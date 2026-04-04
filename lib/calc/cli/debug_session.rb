module Calc
  module Cli
    # Represents the active debugging session, holding state and execution context.
    class DebugSession
      attr_reader :state, :breakpoint_manager, :script_path, :nodes, :code, :source, :cursor

      def initialize(context)
        @parser = context.parser
        @compiler = context.compiler
        @executer = context.executer
        @script_path = context.script_path
        @out = context.io.fetch(:out)
        @err = context.io.fetch(:err)
        
        @breakpoint_manager = Calc::Cli::DebugBreakpointManager.new
        @state = Calc::DebuggerState.new
        
        @source = nil
        @nodes = []
        @code = nil
        @cursor = 0
        @skip_breakpoint_once = false
      end

      def load!
        @source = File.read(@script_path)
        @nodes = @parser.parse(@source)
        @code = @compiler.compile_program(@nodes, name: @script_path)
        @state.start!
      end

      def terminated?
        @state.terminated?
      end

      def terminate!
        @state.terminate!
      end

      def running?
        @state.running?
      end

      def paused?
        @state.paused?
      end

      def pause_reason
        @state.pause_reason
      end

      def restart!
        @cursor = 0
        @skip_breakpoint_once = false
        @state.resume! if paused?
        @state.start! if @state.idle?
      end

      def resume!
        reason = @state.pause_reason
        @state.resume!
        @skip_breakpoint_once = true if reason == :breakpoint
      end

      def step!
        reason = @state.pause_reason
        @state.resume! if paused?
        @skip_breakpoint_once = true if reason == :breakpoint
        
        result = run_single_node(reason: :step_complete)
        @skip_breakpoint_once = false
        result
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

          execute_node(node)
          @cursor += 1
        end

        @state.pause!(reason: pause_reason || :run_complete)
      end

      def execute_remaining_nodes
        while @cursor < @nodes.length
          execute_node(@nodes[@cursor])
          @cursor += 1
        end
        @state.pause!(reason: :run_complete)
      end

      private

      def execute_node(node)
        result = @executer.evaluate_nodes([node], source_path: @script_path)
        @out.puts Calc.format_value(result) unless result.nil?
      end

      def run_single_node(reason:)
        if @cursor < @nodes.length
          execute_node(@nodes[@cursor])
          @cursor += 1
        end
        @state.pause!(reason: reason)
      rescue StandardError => e
        @err.puts e.message
        @state.pause!(reason: :run_failed)
      end
    end
  end
end
