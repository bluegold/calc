require_relative "test_helper"
require "open3"
require "rbconfig"

class FileExecutionTest < Minitest::Test
  SAMPLE_WITH_LAST_RESULT = {
    "samples/basic.calc" => "14\n",
    "samples/higher-order.calc" => "[3, 4, 5]\n",
    "samples/hanoi2.calc" => "{\"A\" => [], \"B\" => [], \"C\" => [1, 2, 3]}\n",
    "samples/namespace.calc" => "16\n",
    "samples/recursion.calc" => "55\n"
  }.freeze

  SAMPLE_WITH_PRINT_OUTPUTS = {
    "samples/basic.calc" => <<~OUT,
      --- basic ---
      14
      6
      true
      true
      true
      base>bonus
    OUT
    "samples/higher-order.calc" => <<~OUT,
      --- higher-order ---
      [2, 3, 4, 5, 6]
      15
    OUT
    "samples/namespace.calc" => <<~OUT,
      --- namespace ---
      8
    OUT
    "samples/recursion.calc" => <<~OUT,
      --- recursion ---
      21
    OUT
    "samples/hanoi2.calc" => <<~OUT,
      --- hanoi2 ---
      [:initial, :A, [1, 2, 3], :B, [], :C, []]
      [[:A, :C], [:A, :B], [:C, :B], [:A, :C], [:B, :A], [:B, :C], [:A, :C]]
      [:move, [:A, :C], :A, [2, 3], :B, [], :C, [1]]
      [:move, [:A, :B], :A, [3], :B, [2], :C, [1]]
      [:move, [:C, :B], :A, [3], :B, [1, 2], :C, []]
      [:move, [:A, :C], :A, [], :B, [1, 2], :C, [3]]
      [:move, [:B, :A], :A, [1], :B, [2], :C, [3]]
      [:move, [:B, :C], :A, [1], :B, [], :C, [2, 3]]
      [:move, [:A, :C], :A, [], :B, [], :C, [1, 2, 3]]
    OUT
    "samples/hanoi.calc" => <<~OUT,
      --- hanoi ---
      A -> C
      A -> B
      C -> B
      A -> C
      B -> A
      B -> C
      A -> C
    OUT
    "samples/list-ops.calc" => <<~OUT,
      --- list ops ---
      10
      10
      [20, 30, 40]
      30
      [10, 99, 30, 40]
      [11, 21, 31, 41]
      [30, 40]
      100
    OUT
    "samples/hash-ops.calc" => <<~OUT
      --- hash ops ---
      taro
      {"name" => hanako, "age" => 20, "active" => true}
      [:name, :age, :active]
      [taro, 20, true]
      [[:name, taro], [:age, 20], [:active, true]]
      true
      banana
      [:name, :age, :active]
      [[:b, 20], [:c, 30]]
      {"x" => 1, "y" => 2}
    OUT
  }.freeze

  def test_file_execution_keeps_print_outputs_without_print_last_result
    SAMPLE_WITH_PRINT_OUTPUTS.each do |sample_path, expected_output|
      stdout, stderr, status = run_calc(sample_path)

      assert_predicate status, :success?
      assert_equal expected_output, stdout
      assert_empty scrub_stderr(stderr)
    end
  end

  def test_file_execution_can_print_the_final_result_on_request
    SAMPLE_WITH_LAST_RESULT.each do |sample_path, expected_output|
      stdout, stderr, status = run_calc("--print-last-result", sample_path)

      assert_predicate status, :success?
      assert_equal SAMPLE_WITH_PRINT_OUTPUTS.fetch(sample_path) + expected_output, stdout
      assert_empty scrub_stderr(stderr)
    end
  end

  def test_file_execution_does_not_append_last_result_when_printing_nil
    %w[samples/hanoi.calc samples/list-ops.calc samples/hash-ops.calc].each do |sample_path|
      stdout, stderr, status = run_calc("--print-last-result", sample_path)

      assert_predicate status, :success?
      assert_equal SAMPLE_WITH_PRINT_OUTPUTS.fetch(sample_path), stdout
      assert_empty scrub_stderr(stderr)
    end
  end

  def test_file_execution_reports_while_evaluating_context
    Dir.mktmpdir do |dir|
      path = File.join(dir, "boom.calc")
      File.write(path, "(do (define x 1) (+ x nil))\n")

      stdout, stderr, status = run_calc(path)

      refute_predicate status, :success?
      assert_empty stdout
      assert_includes scrub_stderr(stderr), "while evaluating"
    end
  end

  def test_file_execution_reports_failing_expression
    Dir.mktmpdir do |dir|
      path = File.join(dir, "boom.calc")
      File.write(path, "(do (define x 1) (+ x nil))\n")

      stdout, stderr, status = run_calc(path)

      refute_predicate status, :success?
      assert_empty stdout
      assert_includes scrub_stderr(stderr), "(+ x nil)"
    end
  end

  def test_bytecode_subcommand_disassembles_file_successfully
    _stdout, stderr, status = run_calc("bytecode", "samples/hanoi.calc")

    assert_predicate status, :success?
    assert_empty scrub_stderr(stderr)
  end

  def test_bytecode_subcommand_disassembles_file_with_header
    stdout, _stderr, _status = run_calc("bytecode", "samples/hanoi.calc")

    assert_includes stdout, "=== "
    assert_includes stdout, "samples/hanoi.calc"
  end

  def test_bytecode_subcommand_disassembles_file_with_instructions
    stdout, _stderr, _status = run_calc("bytecode", "samples/hanoi.calc")

    assert_includes stdout, "load_fn"
  end

  def test_bytecode_subcommand_requires_script_path
    stdout, stderr, status = run_calc("bytecode")

    refute_predicate status, :success?
    assert_empty stdout
    assert_includes scrub_stderr(stderr), "bytecode requires a script path"
  end

  def test_debug_subcommand_requires_script_path
    stdout, stderr, status = run_calc("debug")

    refute_predicate status, :success?
    assert_empty stdout
    assert_includes scrub_stderr(stderr), "missing script path for debug"
  end

  def test_debug_subcommand_loads_script_and_disassembles_it
    stdout, stderr, status = run_calc("debug", "samples/basic.calc")

    assert_predicate status, :success?
    assert_includes stdout, "debugger scaffold loaded for samples/basic.calc"
    assert_empty scrub_stderr(stderr)
  end

  def test_debug_subcommand_disassembles_with_header
    stdout, _stderr, status = run_calc("debug", "samples/basic.calc")

    assert_predicate status, :success?
    assert_includes stdout, "=== samples/basic.calc ==="
  end

  def test_debug_subcommand_disassembles_with_instructions
    stdout, _stderr, status = run_calc("debug", "samples/basic.calc")

    assert_predicate status, :success?
    assert_includes stdout, "load_fn"
  end

  def test_debug_subcommand_reports_parse_errors
    Dir.mktmpdir do |dir|
      path = File.join(dir, "broken.calc")
      File.write(path, "(")

      stdout, stderr, status = run_calc("debug", path)

      refute_predicate status, :success?
      assert_empty stdout
      assert_includes scrub_stderr(stderr), "missing ')'"
    end
  end

  # rubocop:disable Minitest/MultipleAssertions
  def test_compile_subcommand_saves_bytecode_file
    Dir.mktmpdir do |dir|
      source_path = File.join(dir, "math.calc")
      File.write(source_path, "(+ 1 2)\n")

      stdout, stderr, status = run_calc("compile", source_path)
      output_path = stdout.strip

      assert_predicate status, :success?
      assert_empty scrub_stderr(stderr)
      assert_equal ".calcbc", File.extname(output_path)
      assert_path_exists output_path
    end
  end

  def test_compile_subcommand_can_set_output_path
    Dir.mktmpdir do |dir|
      source_path = File.join(dir, "math.calc")
      output_path = File.join(dir, "math.bc")
      File.write(source_path, "(+ 1 2)\n")

      stdout, stderr, status = run_calc("compile", source_path, "--output", output_path)

      assert_predicate status, :success?
      assert_empty scrub_stderr(stderr)
      assert_equal "#{output_path}\n", stdout
      assert_path_exists output_path
    end
  end

  def test_compile_subcommand_requires_script_path
    stdout, stderr, status = run_calc("compile")

    refute_predicate status, :success?
    assert_empty stdout
    assert_includes scrub_stderr(stderr), "compile requires a script path"
  end

  def test_file_execution_can_run_saved_bytecode
    Dir.mktmpdir do |dir|
      source_path = File.join(dir, "calc.calc")
      bytecode_path = File.join(dir, "calc.calcbc")
      File.write(source_path, "(+ 1 2 3)\n")

      _compile_stdout, compile_stderr, compile_status = run_calc("compile", source_path, "--output", bytecode_path)
      stdout, stderr, status = run_calc("--print-last-result", bytecode_path)

      assert_predicate compile_status, :success?, compile_stderr
      assert_predicate status, :success?
      assert_equal "6\n", stdout
      assert_empty scrub_stderr(stderr)
    end
  end
  # rubocop:enable Minitest/MultipleAssertions

  def test_file_execution_can_trace_vm_to_stderr
    stdout, stderr, status = run_calc_with_env(
      { "CALC_EXECUTER_MODE" => "vm" },
      "--trace-vm",
      "--print-last-result",
      "samples/recursion.calc"
    )
    expected_stdout = SAMPLE_WITH_PRINT_OUTPUTS.fetch("samples/recursion.calc") +
                      SAMPLE_WITH_LAST_RESULT.fetch("samples/recursion.calc")

    assert_predicate status, :success?
    assert_equal expected_stdout, stdout
    assert_includes scrub_stderr(stderr), "=== VM trace"
  end

  def test_file_execution_trace_includes_call_instruction
    _stdout, stderr, status = run_calc_with_env(
      { "CALC_EXECUTER_MODE" => "vm" },
      "--trace-vm",
      "--print-last-result",
      "samples/recursion.calc"
    )

    assert_predicate status, :success?
    assert_includes scrub_stderr(stderr), "call arg="
  end

  private

  def run_calc(...)
    Open3.capture3(RbConfig.ruby, "-Ilib", "bin/calc", ...)
  end

  def run_calc_with_env(env, ...)
    Open3.capture3(env, RbConfig.ruby, "-Ilib", "bin/calc", ...)
  end

  def scrub_stderr(stderr)
    stderr.lines.reject { |line| line.start_with?("Source locally installed gems is ignoring") }.join
  end
end
