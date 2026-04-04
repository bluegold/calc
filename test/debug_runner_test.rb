require_relative "test_helper"
require "open3"
require "rbconfig"
require "tmpdir"

class DebugRunnerTest < Minitest::Test # rubocop:disable Metrics/ClassLength
  def test_debug_subcommand_loads_script_and_shows_prompt
    stdout, _stderr, status = run_calc("debug", "samples/basic.calc")

    assert_predicate status, :success?
    assert_includes stdout, "debugger scaffold loaded for samples/basic.calc"
    assert_includes stdout, "=== samples/basic.calc ==="
  end

  def test_debug_subcommand_reports_no_stderr_on_startup
    _stdout, stderr, status = run_calc("debug", "samples/basic.calc")

    assert_predicate status, :success?
    assert_empty scrub_stderr(stderr)
  end

  def test_debug_subcommand_disassembles_with_instructions
    stdout, _stderr, status = run_calc("debug", "samples/basic.calc")

    assert_predicate status, :success?
    assert_includes stdout, "load_fn"
  end

  def test_debug_subcommand_shows_prompt
    stdout, _stderr, status = run_calc("debug", "samples/basic.calc")

    assert_predicate status, :success?
    assert_includes stdout, "(calcdb)"
  end

  def test_debug_subcommand_quit_exits_cleanly
    stdout = stderr = status = nil

    Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", "samples/basic.calc") do |i, o, e, t|
      i.puts "quit"
      i.close
      stdout = o.read
      stderr = e.read
      status = t.value
    end

    assert_predicate status, :success?
    assert_includes stdout, "(calcdb)"
    assert_empty scrub_stderr(stderr)
  end

  def test_debug_subcommand_reports_unknown_command
    stdout = stderr = status = nil

    Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", "samples/basic.calc") do |i, o, e, t|
      i.puts "bogus"
      i.puts "quit"
      i.close
      stdout = o.read
      stderr = e.read
      status = t.value
    end

    assert_predicate status, :success?
    assert_includes stderr, "unknown debugger command: bogus"
    assert_includes stdout, "(calcdb)"
  end

  def test_debug_subcommand_help_shows_command_summary
    stdout = stderr = status = nil

    Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", "samples/basic.calc") do |i, o, e, t|
      i.puts "help"
      i.puts "quit"
      i.close
      stdout = o.read
      stderr = e.read
      status = t.value
    end

    assert_predicate status, :success?
    assert_includes stdout, "Commands:"
    assert_empty scrub_stderr(stderr)
  end

  def test_debug_subcommand_help_includes_run_command
    stdout = stderr = status = nil

    Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", "samples/basic.calc") do |i, o, e, t|
      i.puts "help"
      i.puts "quit"
      i.close
      stdout = o.read
      stderr = e.read
      status = t.value
    end

    assert_predicate status, :success?
    assert_includes stdout, "run              Start program execution"
    assert_empty scrub_stderr(stderr)
  end

  def test_debug_subcommand_help_includes_continue_command
    stdout = stderr = status = nil

    Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", "samples/basic.calc") do |i, o, e, t|
      i.puts "help"
      i.puts "quit"
      i.close
      stdout = o.read
      stderr = e.read
      status = t.value
    end

    assert_predicate status, :success?
    assert_includes stdout, "continue         Resume execution after a pause"
    assert_empty scrub_stderr(stderr)
  end

  def test_debug_subcommand_run_executes_program
    stdout = stderr = status = nil

    Dir.mktmpdir do |dir|
      path = File.join(dir, "run.calc")
      File.write(path, "(+ 1 2)\n")

      Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", path) do |i, o, e, t|
        i.puts "run"
        i.puts "help"
        i.puts "quit"
        i.close
        stdout = o.read
        stderr = e.read
        status = t.value
      end
    end

    assert_predicate status, :success?
    assert_includes stdout, "3"
    assert_empty scrub_stderr(stderr)
  end

  def test_debug_subcommand_run_keeps_prompt_alive
    stdout = stderr = status = nil

    Dir.mktmpdir do |dir|
      path = File.join(dir, "run.calc")
      File.write(path, "(+ 1 2)\n")

      Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", path) do |i, o, e, t|
        i.puts "run"
        i.puts "help"
        i.puts "quit"
        i.close
        stdout = o.read
        stderr = e.read
        status = t.value
      end
    end

    assert_predicate status, :success?
    assert_includes stdout, "Commands:"
    assert_empty scrub_stderr(stderr)
  end

  def test_debug_subcommand_run_runtime_error_keeps_prompt_alive
    _stdout = stderr = status = nil

    Dir.mktmpdir do |dir|
      path = File.join(dir, "run_error.calc")
      File.write(path, "(+ 1 nil)\n")

      Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", path) do |i, o, e, t|
        i.puts "run"
        i.puts "quit"
        i.close
        _stdout = o.read
        stderr = e.read
        status = t.value
      end
    end

    assert_predicate status, :success?
    assert_includes stderr, "while evaluating"
    refute_includes stderr, "TypeError: TypeError"
  end

  def test_debug_subcommand_run_runtime_error_keeps_prompt_alive_after_error
    stdout = stderr = status = nil

    Dir.mktmpdir do |dir|
      path = File.join(dir, "run_error.calc")
      File.write(path, "(+ 1 nil)\n")

      Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", path) do |i, o, e, t|
        i.puts "run"
        i.puts "quit"
        i.close
        stdout = o.read
        stderr = e.read
        status = t.value
      end
    end

    assert_predicate status, :success?
    assert_includes stdout, "(calcdb)"
  end

  def test_debug_subcommand_line_breakpoint_stops_run
    stdout = stderr = status = nil

    Dir.mktmpdir do |dir|
      path = File.join(dir, "break_line.calc")
      File.write(path, "(+ 1 2)\n(+ 3 4)\n")

      Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", path) do |i, o, e, t|
        i.puts "break 3"
        i.puts "run"
        i.puts "quit"
        i.close
        stdout = o.read
        stderr = e.read
        status = t.value
      end
    end

    assert_predicate status, :success?
    assert_includes stdout, "Breakpoint 1 set"
    assert_includes stdout, "Breakpoint hit at L3"
  end

  def test_debug_subcommand_break_uses_source_line_start
    stdout = stderr = status = nil

    Dir.mktmpdir do |dir|
      path = File.join(dir, "break_source_line.calc")
      File.write(path, "(define base 10)\n(define bonus 4)\n\n(do\n  (println (+ base bonus)))\n")

      Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", path) do |i, o, e, t|
        i.puts "break 7"
        i.puts "run"
        i.puts "quit"
        i.close
        stdout = o.read
        stderr = e.read
        status = t.value
      end
    end

    assert_predicate status, :success?
    assert_includes stdout, "Breakpoint 1 set"
    assert_includes stdout, "Breakpoint hit"
  end

  def test_debug_subcommand_break_maps_top_level_literal_form
    stdout = stderr = status = nil

    Dir.mktmpdir do |dir|
      path = File.join(dir, "literal.calc")
      File.write(path, "base\n(define bonus 4)\n")

      Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", path) do |i, o, e, t|
        i.puts "break 1"
        i.puts "run"
        i.puts "quit"
        i.close
        stdout = o.read
        stderr = e.read
        status = t.value
      end
    end

    assert_predicate status, :success?
    assert_includes stdout, "Breakpoint 1 set"
    assert_includes stdout, "Breakpoint hit"
  end

  def test_debug_subcommand_break_rejects_unresolved_source_line
    stdout = stderr = status = nil

    Dir.mktmpdir do |dir|
      path = File.join(dir, "literal.calc")
      File.write(path, "base\n(define bonus 4)\n")

      Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", path) do |i, o, e, t|
        i.puts "break 99"
        i.puts "quit"
        i.close
        stdout = o.read
        stderr = e.read
        status = t.value
      end
    end

    assert_predicate status, :success?
    assert_includes stderr, "unable to resolve breakpoint line"
    refute_includes stdout, "Breakpoint 1 set"
  end

  def test_debug_subcommand_continue_after_breakpoint_resumes_execution
    _stdout = stderr = status = nil

    Dir.mktmpdir do |dir|
      path = File.join(dir, "break_line.calc")
      File.write(path, "(+ 1 2)\n(+ 3 4)\n")

      Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", path) do |i, o, e, t|
        i.puts "break 3"
        i.puts "run"
        i.puts "continue"
        i.puts "quit"
        i.close
        _stdout = o.read
        stderr = e.read
        status = t.value
      end
    end

    assert_predicate status, :success?
    assert_empty scrub_stderr(stderr)
  end

  def test_debug_subcommand_continue_after_breakpoint_prints_final_result
    stdout = stderr = status = nil

    Dir.mktmpdir do |dir|
      path = File.join(dir, "break_line.calc")
      File.write(path, "(+ 1 2)\n(+ 3 4)\n")

      Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", path) do |i, o, e, t|
        i.puts "break 3"
        i.puts "run"
        i.puts "continue"
        i.puts "quit"
        i.close
        stdout = o.read
        stderr = e.read
        status = t.value
      end
    end

    assert_predicate status, :success?
    assert_includes stdout, "7"
    assert_empty scrub_stderr(stderr)
  end

  def test_debug_subcommand_continue_runtime_error_keeps_prompt_alive
    stdout = stderr = status = nil

    Dir.mktmpdir do |dir|
      path = File.join(dir, "continue_error.calc")
      File.write(path, "(+ 1 2)\n(+ 3 nil)\n")

      Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", path) do |i, o, e, t|
        i.puts "break 3"
        i.puts "run"
        i.puts "continue"
        i.puts "quit"
        i.close
        stdout = o.read
        stderr = e.read
        status = t.value
      end
    end

    assert_predicate status, :success?
    assert_includes stderr, "while evaluating"
    assert_includes stdout, "(calcdb)"
  end

  def test_debug_subcommand_step_does_not_skip_next_breakpoint
    stdout = stderr = status = nil

    Dir.mktmpdir do |dir|
      path = File.join(dir, "step_break.calc")
      File.write(path, "(+ 1 2)\n(+ 3 4)\n(+ 5 6)\n(+ 7 8)\n")

      Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", path) do |i, o, e, t|
        i.puts "break 1"
        i.puts "break 3"
        i.puts "run"
        i.puts "step"
        i.puts "continue"
        i.puts "quit"
        i.close
        stdout = o.read
        stderr = e.read
        status = t.value
      end
    end

    assert_predicate status, :success?
    assert_includes stdout, "Breakpoint hit at L1"
    assert_includes stdout, "Breakpoint hit at L3"
  end

  def test_debug_subcommand_step_reports_end_of_program
    stdout = stderr = status = nil

    Dir.mktmpdir do |dir|
      path = File.join(dir, "step_end.calc")
      File.write(path, "(+ 1 2)\n")

      Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", path) do |i, o, e, t|
        i.puts "run"
        i.puts "step"
        i.puts "quit"
        i.close
        stdout = o.read
        stderr = e.read
        status = t.value
      end
    end

    assert_predicate status, :success?
    assert_includes stdout, "Reached end of program"
    assert_empty scrub_stderr(stderr)
  end

  def test_debug_subcommand_run_can_restart_after_continue_prints_first_result
    stdout = stderr = status = nil

    Dir.mktmpdir do |dir|
      path = File.join(dir, "break_line.calc")
      File.write(path, "(+ 1 2)\n(+ 3 4)\n")

      Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", path) do |i, o, e, t|
        i.puts "break 3"
        i.puts "run"
        i.puts "continue"
        i.puts "run"
        i.puts "quit"
        i.close
        stdout = o.read
        stderr = e.read
        status = t.value
      end
    end

    assert_predicate status, :success?
    assert_includes stdout, "3"
    assert_empty scrub_stderr(stderr)
  end

  def test_debug_subcommand_run_can_restart_after_continue_prints_second_result
    stdout = stderr = status = nil

    Dir.mktmpdir do |dir|
      path = File.join(dir, "break_line.calc")
      File.write(path, "(+ 1 2)\n(+ 3 4)\n")

      Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", path) do |i, o, e, t|
        i.puts "break 3"
        i.puts "run"
        i.puts "continue"
        i.puts "run"
        i.puts "quit"
        i.close
        stdout = o.read
        stderr = e.read
        status = t.value
      end
    end

    assert_predicate status, :success?
    assert_includes stdout, "7"
    assert_empty scrub_stderr(stderr)
  end

  def test_debug_subcommand_list_shows_current_source_window
    stdout = stderr = status = nil

    Dir.mktmpdir do |dir|
      path = File.join(dir, "list.calc")
      File.write(path, "(+ 1 2)\n(+ 3 4)\n")

      Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", path) do |i, o, e, t|
        i.puts "break 3"
        i.puts "run"
        i.puts "list 1"
        i.puts "quit"
        i.close
        stdout = o.read
        stderr = e.read
        status = t.value
      end
    end

    assert_predicate status, :success?
    assert_includes stdout, "B"
    assert_empty scrub_stderr(stderr)
  end

  def test_debug_subcommand_list_shows_current_source_line
    stdout = stderr = status = nil

    Dir.mktmpdir do |dir|
      path = File.join(dir, "list.calc")
      File.write(path, "(+ 1 2)\n(+ 3 4)\n")

      Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", path) do |i, o, e, t|
        i.puts "break 3"
        i.puts "run"
        i.puts "list 1"
        i.puts "quit"
        i.close
        stdout = o.read
        stderr = e.read
        status = t.value
      end
    end

    assert_predicate status, :success?
    assert_includes stdout, "src    2 | ast    3 | (+ 3 4)"
    assert_empty scrub_stderr(stderr)
  end

  def test_debug_subcommand_list_does_not_mark_blank_lines
    stdout = stderr = status = nil

    Dir.mktmpdir do |dir|
      path = File.join(dir, "blank.calc")
      File.write(path, "(+ 1 2)\n\n(+ 3 4)\n")

      Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", path) do |i, o, e, t|
        i.puts "break 5"
        i.puts "run"
        i.puts "list 1"
        i.puts "quit"
        i.close
        stdout = o.read
        stderr = e.read
        status = t.value
      end
    end

    assert_predicate status, :success?
    refute_includes stdout, "B src    2"
    assert_empty scrub_stderr(stderr)
  end

  def test_debug_subcommand_list_handles_multiple_forms_on_same_line
    stdout = stderr = status = nil

    Dir.mktmpdir do |dir|
      path = File.join(dir, "multi.calc")
      File.write(path, "(+ 1 2) (+ 3 4)\n")

      Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", path) do |i, o, e, t|
        i.puts "run"
        i.puts "list 1"
        i.puts "quit"
        i.close
        stdout = o.read
        stderr = e.read
        status = t.value
      end
    end

    assert_predicate status, :success?
    assert_includes stdout, "ast    1"
    assert_includes stdout, "ast    1 | (+ 1 2) (+ 3 4)"
  end

  def test_debug_subcommand_list_shows_bytecode_section
    stdout = stderr = status = nil

    Dir.mktmpdir do |dir|
      path = File.join(dir, "list.calc")
      File.write(path, "(+ 1 2)\n(+ 3 4)\n")

      Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", path) do |i, o, e, t|
        i.puts "break 3"
        i.puts "run"
        i.puts "list 1 bytecode"
        i.puts "quit"
        i.close
        stdout = o.read
        stderr = e.read
        status = t.value
      end
    end

    assert_predicate status, :success?
    assert_includes stdout, "bytecode:"
    assert_empty scrub_stderr(stderr)
  end

  def test_debug_subcommand_list_shows_bytecode_line_header
    stdout = stderr = status = nil

    Dir.mktmpdir do |dir|
      path = File.join(dir, "list.calc")
      File.write(path, "(+ 1 2)\n(+ 3 4)\n")

      Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", path) do |i, o, e, t|
        i.puts "break 3"
        i.puts "run"
        i.puts "list 1 bytecode"
        i.puts "quit"
        i.close
        stdout = o.read
        stderr = e.read
        status = t.value
      end
    end

    assert_predicate status, :success?
    assert_includes stdout, "L3"
    assert_empty scrub_stderr(stderr)
  end

  def test_debug_subcommand_list_shows_bytecode_instructions
    stdout = stderr = status = nil

    Dir.mktmpdir do |dir|
      path = File.join(dir, "list.calc")
      File.write(path, "(+ 1 2)\n(+ 3 4)\n")

      Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", path) do |i, o, e, t|
        i.puts "break 3"
        i.puts "run"
        i.puts "list 1 bytecode"
        i.puts "quit"
        i.close
        stdout = o.read
        stderr = e.read
        status = t.value
      end
    end

    assert_predicate status, :success?
    assert_includes stdout, "load_fn"
    assert_empty scrub_stderr(stderr)
  end

  def test_debug_subcommand_list_shows_closure_body_bytecode_section
    stdout = stderr = status = nil

    Dir.mktmpdir do |dir|
      path = File.join(dir, "closure.calc")
      File.write(path, "(lambda (x) (+ x 1))\n")

      Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", path) do |i, o, e, t|
        i.puts "run"
        i.puts "list 1 bytecode"
        i.puts "quit"
        i.close
        stdout = o.read
        stderr = e.read
        status = t.value
      end
    end

    assert_predicate status, :success?
    assert_includes stdout, "closure body"
    assert_empty scrub_stderr(stderr)
  end

  def test_debug_subcommand_list_shows_closure_body_bytecode_instruction
    stdout = stderr = status = nil

    Dir.mktmpdir do |dir|
      path = File.join(dir, "closure.calc")
      File.write(path, "(lambda (x) (+ x 1))\n")

      Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", path) do |i, o, e, t|
        i.puts "run"
        i.puts "list 1 bytecode"
        i.puts "quit"
        i.close
        stdout = o.read
        stderr = e.read
        status = t.value
      end
    end

    assert_predicate status, :success?
    assert_includes stdout, "load_fn"
    assert_empty scrub_stderr(stderr)
  end

  def test_debug_subcommand_list_shows_make_closure_signature
    stdout = stderr = status = nil

    Dir.mktmpdir do |dir|
      path = File.join(dir, "closure.calc")
      File.write(path, "(lambda (n) (+ n 1))\n")

      Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", path) do |i, o, e, t|
        i.puts "run"
        i.puts "list 1 bytecode"
        i.puts "quit"
        i.close
        stdout = o.read
        stderr = e.read
        status = t.value
      end
    end

    assert_predicate status, :success?
    assert_includes stdout, 'make_closure params=["n"]'
    assert_empty scrub_stderr(stderr)
  end

  def test_debug_subcommand_list_shows_nested_outer_make_closure_signature
    stdout = stderr = status = nil

    Dir.mktmpdir do |dir|
      path = File.join(dir, "nested.cla")
      File.write(
        path,
        <<~CALC
          (define (outer xs)
            (lambda (memo)
              (fold xs (lambda (memo _x) (+ memo 1)) memo)))
        CALC
      )

      Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", path) do |i, o, e, t|
        i.puts "run"
        i.puts "list 2 bytecode"
        i.puts "quit"
        i.close
        stdout = o.read
        stderr = e.read
        status = t.value
      end
    end

    assert_predicate status, :success?
    assert_includes stdout, 'make_closure params=["xs"]'
    assert_empty scrub_stderr(stderr)
  end

  def test_debug_subcommand_list_shows_nested_inner_make_closure_signature
    stdout = stderr = status = nil

    Dir.mktmpdir do |dir|
      path = File.join(dir, "nested.cla")
      File.write(
        path,
        <<~CALC
          (define (outer xs)
            (lambda (memo)
              (fold xs (lambda (memo _x) (+ memo 1)) memo)))
        CALC
      )

      Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", path) do |i, o, e, t|
        i.puts "run"
        i.puts "list 2 bytecode"
        i.puts "quit"
        i.close
        stdout = o.read
        stderr = e.read
        status = t.value
      end
    end

    assert_predicate status, :success?
    assert_includes stdout, 'make_closure params=["memo", "_x"]'
    assert_empty scrub_stderr(stderr)
  end

  def test_debug_subcommand_function_breakpoint_stops_run
    stdout = stderr = status = nil

    Dir.mktmpdir do |dir|
      path = File.join(dir, "break_function.calc")
      File.write(path, "(define (inc x) (+ x 1))\n(inc 2)\n")

      Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", path) do |i, o, e, t|
        i.puts "break inc"
        i.puts "run"
        i.puts "quit"
        i.close
        stdout = o.read
        stderr = e.read
        status = t.value
      end
    end

    assert_predicate status, :success?
    assert_includes stdout, "Breakpoint 1 set"
    assert_includes stdout, "Breakpoint hit"
  end

  def test_debug_subcommand_continue_is_placeholder
    stdout = stderr = status = nil

    Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", "samples/basic.calc") do |i, o, e, t|
      i.puts "continue"
      i.puts "quit"
      i.close
      stdout = o.read
      stderr = e.read
      status = t.value
    end

    assert_predicate status, :success?
    assert_includes stdout, "continue is not implemented yet"
    assert_empty scrub_stderr(stderr)
  end

  def test_debug_subcommand_unknown_function_breakpoint_sets_breakpoint
    stdout = stderr = status = nil

    Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", "samples/basic.calc") do |i, o, e, t|
      i.puts "break foo"
      i.puts "run"
      i.puts "quit"
      i.close
      stdout = o.read
      stderr = e.read
      status = t.value
    end

    assert_predicate status, :success?
    assert_includes stdout, "Breakpoint 1 set"
    refute_includes stdout, "Breakpoint hit"
  end

  def test_debug_subcommand_info_break_lists_breakpoints
    stdout = stderr = status = nil

    Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", "samples/basic.calc") do |i, o, e, t|
      i.puts "break 1"
      i.puts "break foo"
      i.puts "info break"
      i.puts "quit"
      i.close
      stdout = o.read
      stderr = e.read
      status = t.value
    end

    assert_predicate status, :success?
    assert_includes stdout, "Breakpoints:"
    assert_includes stdout, "1: line 1"
  end

  def test_debug_subcommand_delete_breakpoint_removes_it
    stdout = stderr = status = nil

    Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", "samples/basic.calc") do |i, o, e, t|
      i.puts "break 1"
      i.puts "delete 1"
      i.puts "info break"
      i.puts "quit"
      i.close
      stdout = o.read
      stderr = e.read
      status = t.value
    end

    assert_predicate status, :success?
    assert_includes stdout, "Deleted breakpoint 1"
    refute_includes stdout, "1: line 1"
  end

  private

  def run_calc(...)
    Open3.capture3(RbConfig.ruby, "-Ilib", "bin/calc", ...)
  end

  def scrub_stderr(stderr)
    stderr.gsub(/\e\[[\d;]*m/, "")
  end
end
