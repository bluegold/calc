require_relative "test_helper"
require "bigdecimal"
require "fileutils"
require "tmpdir"

class ExecuterLoaderTest < Minitest::Test
  def setup
    @executer = Calc::Executer.new
  end

  def test_load_finds_bundled_stdlib_outside_project_directory
    Dir.mktmpdir do |dir|
      result = Dir.chdir(dir) do
        @executer.evaluate_source('(do (load "collections/list") (std.collections.list.sum (list 1 2 3)))')
      end

      assert_equal BigDecimal("6"), result
    end
  end

  def test_load_finds_user_modules_under_xdg_config_home
    Dir.mktmpdir do |dir|
      module_root = File.join(dir, "calc", "modules")
      FileUtils.mkdir_p(module_root)
      File.write(File.join(module_root, "math.calc"), "(namespace math (define (inc x) (+ x 1)))\n")

      original = ENV.fetch("XDG_CONFIG_HOME", nil)
      ENV["XDG_CONFIG_HOME"] = dir
      result = @executer.evaluate_source('(do (load "math") (math.inc 2))')

      assert_equal BigDecimal("3"), result
    ensure
      ENV["XDG_CONFIG_HOME"] = original
    end
  end

  def test_load_prefers_source_directory_before_test_parent_root
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "stdlib", "test"))
      File.write(File.join(dir, "stdlib", "test", "sample.calc"), "(define answer 1)\n")
      File.write(File.join(dir, "stdlib", "sample.calc"), "(define answer 2)\n")

      source = '(do (load "sample") answer)'
      result = @executer.evaluate_source(source, source_path: File.join(dir, "stdlib", "test", "runner.calc"))

      assert_equal BigDecimal("1"), result
    end
  end

  def test_user_modules_root_is_nil_without_home_or_xdg_config_home
    original_xdg = ENV.fetch("XDG_CONFIG_HOME", nil)
    ENV.delete("XDG_CONFIG_HOME")

    dir_singleton = class << Dir; self; end
    original_home_method = Dir.method(:home)
    dir_singleton.undef_method(:home)
    dir_singleton.define_method(:home) { raise ArgumentError, "no home directory" }

    assert_nil @executer.send(:user_modules_root)
  ensure
    dir_singleton.undef_method(:home)
    dir_singleton.define_method(:home, original_home_method)
    ENV["XDG_CONFIG_HOME"] = original_xdg
  end
end
