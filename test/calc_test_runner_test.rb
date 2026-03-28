require_relative "test_helper"
require "open3"
require "fileutils"
require "tmpdir"

class CalcTestRunnerTest < Minitest::Test
  def test_calc_test_runs_modules_test_files
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "modules", "test"))
      File.write(File.join(dir, "modules", "sample.calc"), "(namespace sample (define (inc x) (+ x 1)))\n")
      File.write(
        File.join(dir, "modules", "test", "sample_test.calc"),
        <<~CALC
          (do
            (load "sample")
            (assert-equal 3 (sample.inc 2))
            true)
        CALC
      )

      stdout, stderr, status = Open3.capture3(
        { "BUNDLE_GEMFILE" => File.expand_path("../Gemfile", __dir__) },
        "bundle",
        "exec",
        "ruby",
        File.expand_path("../bin/calc", __dir__),
        "test",
        chdir: dir
      )

      assert_predicate status, :success?, stderr
      assert_includes stdout, "PASS modules/test/sample_test.calc"
    end
  end

  def test_calc_test_fails_when_no_files_are_found
    Dir.mktmpdir do |dir|
      stdout, stderr, status = Open3.capture3(
        { "BUNDLE_GEMFILE" => File.expand_path("../Gemfile", __dir__) },
        "bundle",
        "exec",
        "ruby",
        File.expand_path("../bin/calc", __dir__),
        "test",
        chdir: dir
      )

      refute_predicate status, :success?
      assert_includes stderr, "no .calc test files found"
      assert_empty stdout
    end
  end

  def test_calc_test_prints_summary_for_found_tests
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "samples", "test"))
      File.write(File.join(dir, "samples", "stdlib-list.calc"), "(namespace std.collections.list (define (sum xs) 1))\n")
      File.write(
        File.join(dir, "samples", "test", "stdlib-list.calc"),
        <<~CALC
          (do
            (load "stdlib-list")
            (assert-equal 1 (std.collections.list.sum (list 1 2 3)))
            true)
        CALC
      )

      stdout, stderr, status = Open3.capture3(
        { "BUNDLE_GEMFILE" => File.expand_path("../Gemfile", __dir__) },
        "bundle",
        "exec",
        "ruby",
        File.expand_path("../bin/calc", __dir__),
        "test",
        "samples/test",
        chdir: dir
      )

      assert_predicate status, :success?, stderr
      assert_includes stdout, "Running 1 calc tests"
      assert_includes stdout, "1 passed, 0 failed"
    end
  end

  def test_calc_test_writes_failures_to_stderr_without_color_when_not_tty
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "samples", "test"))
      File.write(File.join(dir, "samples", "boom.calc"), "(define answer 1)\n")
      File.write(
        File.join(dir, "samples", "test", "boom.calc"),
        <<~CALC
          (do
            (load "boom")
            (assert-equal 2 answer)
            true)
        CALC
      )

      _stdout, stderr, status = Open3.capture3(
        { "BUNDLE_GEMFILE" => File.expand_path("../Gemfile", __dir__) },
        "bundle",
        "exec",
        "ruby",
        File.expand_path("../bin/calc", __dir__),
        "test",
        "samples/test",
        chdir: dir
      )

      refute_predicate status, :success?
      assert_includes stderr, "FAIL samples/test/boom.calc"
      refute_includes stderr, "\e["
    end
  end
end
