require_relative "test_helper"
require "open3"
require "rbconfig"

class DebugRunnerTest < Minitest::Test
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

  def test_debug_subcommand_run_is_placeholder
    stdout = stderr = status = nil

    Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", "samples/basic.calc") do |i, o, e, t|
      i.puts "run"
      i.puts "quit"
      i.close
      stdout = o.read
      stderr = e.read
      status = t.value
    end

    assert_predicate status, :success?
    assert_includes stdout, "run is not implemented yet"
    assert_empty scrub_stderr(stderr)
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

  def test_debug_subcommand_break_with_target_is_placeholder
    stdout = stderr = status = nil

    Open3.popen3(RbConfig.ruby, "-Ilib", "bin/calc", "debug", "samples/basic.calc") do |i, o, e, t|
      i.puts "break foo"
      i.puts "quit"
      i.close
      stdout = o.read
      stderr = e.read
      status = t.value
    end

    assert_predicate status, :success?
    assert_includes stdout, "break foo is not implemented yet"
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
