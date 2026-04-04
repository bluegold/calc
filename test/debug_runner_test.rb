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

  def test_debug_subcommand_list_with_count_is_placeholder
    stdout = stderr = status = nil

    Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", "samples/basic.calc") do |i, o, e, t|
      i.puts "list 5"
      i.puts "quit"
      i.close
      stdout = o.read
      stderr = e.read
      status = t.value
    end

    assert_predicate status, :success?
    assert_includes stdout, "list 5 is not implemented yet"
    assert_empty scrub_stderr(stderr)
  end

  def test_debug_subcommand_list_with_bytecode_is_placeholder
    stdout = stderr = status = nil

    Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", "samples/basic.calc") do |i, o, e, t|
      i.puts "list 5 bytecode"
      i.puts "quit"
      i.close
      stdout = o.read
      stderr = e.read
      status = t.value
    end

    assert_predicate status, :success?
    assert_includes stdout, "list 5 bytecode is not implemented yet"
    assert_empty scrub_stderr(stderr)
  end

  private

  def run_calc(...)
    Open3.capture3(RbConfig.ruby, "-Ilib", "bin/calc", ...)
  end

  def scrub_stderr(stderr)
    stderr.gsub(/\e\[[\d;]*m/, "")
  end
end
