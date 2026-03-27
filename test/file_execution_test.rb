require_relative "test_helper"
require "open3"
require "rbconfig"

class FileExecutionTest < Minitest::Test
  SAMPLE_OUTPUTS = {
    "samples/basic.calc" => "14\n",
    "samples/higher-order.calc" => "[3, 4, 5]\n",
    "samples/namespace.calc" => "16\n",
    "samples/recursion.calc" => "55\n"
  }.freeze

  def test_file_execution_can_skip_printing_the_final_result_by_default
    SAMPLE_OUTPUTS.each_key do |sample_path|
      stdout, stderr, status = run_calc(sample_path)

      assert_predicate status, :success?
      assert_empty stdout
      assert_empty scrub_stderr(stderr)
    end
  end

  def test_file_execution_can_print_the_final_result_on_request
    SAMPLE_OUTPUTS.each do |sample_path, expected_output|
      stdout, stderr, status = run_calc("--print-last-result", sample_path)

      assert_predicate status, :success?
      assert_equal expected_output, stdout
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
