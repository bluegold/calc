module Calc
  module Cli
    # Dispatches debugger commands to the appropriate session or UI logic.
    class DebugCommandDispatcher
      def initialize(session, out, err)
        @session = session
        @out = out
        @err = err
      end

      def dispatch(command_name, payload)
        case command_name
        when "run"
          handle_run
        when "continue"
          handle_continue
        when "step", "next"
          handle_step
        when "finish"
          handle_finish
        when "break"
          handle_break(payload)
        when "delete"
          handle_delete(payload)
        when "info"
          handle_info(payload)
        when "list"
          handle_list(payload)
        when "bt", "locals", "print"
          print_not_implemented(command_name, payload)
        when "help"
          print_help
        else
          @err.puts "unknown debugger command: #{command_name}"
        end
      end

      private

      def handle_run
        @session.restart!
        @session.execute_until_breakpoint
      rescue StandardError => e
        @err.puts e.message
        @session.state.pause!(reason: :run_failed)
      end

      def handle_continue
        unless @session.paused?
          @out.puts "continue is only available when paused"
          return
        end

        @session.resume!
        @session.execute_until_breakpoint
      rescue StandardError => e
        @err.puts e.message
        @session.state.pause!(reason: :run_failed)
      end

      def handle_step
        unless @session.paused? || @session.running?
          @out.puts "step is only available when running or paused"
          return
        end

        @session.step!
        @out.puts "Reached end of program" if @session.cursor >= @session.nodes.length
      end

      def handle_finish
        unless @session.paused? || @session.running?
          @out.puts "finish is only available when running or paused"
          return
        end

        @session.resume!
        @session.execute_remaining_nodes
      rescue StandardError => e
        @err.puts e.message
        @session.state.pause!(reason: :run_failed)
      end

      def handle_break(payload)
        breakpoint = @session.breakpoint_manager.create(payload, valid_lines: @session.nodes.map(&:line))
        @out.puts "Breakpoint #{breakpoint.id} set"
      rescue ArgumentError => e
        @err.puts e.message
      end

      def handle_delete(payload)
        if @session.breakpoint_manager.delete(payload)
          @out.puts "Deleted breakpoint #{payload}"
        else
          @err.puts "no such breakpoint: #{payload}"
        end
      end

      def handle_info(payload)
        case payload.to_s.strip
        when "break", "breaks", "breakpoints", ""
          print_breakpoints
        else
          @err.puts "usage: info break"
        end
      end

      def print_breakpoints
        if @session.breakpoint_manager.breakpoints.empty?
          @out.puts "No breakpoints set"
          return
        end

        @out.puts "Breakpoints:"
        @session.breakpoint_manager.lines.each { |line| @out.puts line }
      end

      def handle_list(payload)
        DebugListCommand.new(
          context: DebugListCommand::Context.new(
            @session.source,
            @session.code,
            @session.nodes,
            @session.cursor,
            @session.breakpoint_manager.line_breakpoint_targets,
            DebugSourceLineMapper.new(@session.source, @session.nodes)
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
