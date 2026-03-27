require_relative "test_helper"
require "open3"
require "rbconfig"

class FileExecutionTest < Minitest::Test
  SAMPLE_WITH_LAST_RESULT = {
    "samples/basic.calc" => "14\n",
    "samples/higher-order.calc" => "[3, 4, 5]\n",
    "samples/namespace.calc" => "16\n",
    "samples/recursion.calc" => "55\n"
  }.freeze

  SAMPLE_WITH_PRINT_OUTPUTS = {
    "samples/basic.calc" => <<~OUT,
      --- basic ---
      14
      6
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
    %w[samples/list-ops.calc samples/hash-ops.calc].each do |sample_path|
      stdout, stderr, status = run_calc("--print-last-result", sample_path)

      assert_predicate status, :success?
      assert_equal SAMPLE_WITH_PRINT_OUTPUTS.fetch(sample_path), stdout
      assert_empty scrub_stderr(stderr)
    end
  end

  private

  def run_calc(...)
    Open3.capture3(RbConfig.ruby, "-Ilib", "bin/calc", ...)
  end

  def scrub_stderr(stderr)
    stderr.lines.reject { |line| line.start_with?("Source locally installed gems is ignoring") }.join
  end
end
