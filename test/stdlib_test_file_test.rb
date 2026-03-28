require_relative "test_helper"
require "find"
require "tmpdir"

class StdlibTestFileTest < Minitest::Test
  def setup
    @executer = Calc::Executer.new
  end

  def test_all_stdlib_test_files_pass
    Find.find(File.expand_path("../stdlib/test", __dir__)) do |path|
      next unless path.end_with?(".calc")

      source = File.read(path)

      assert_predicate @executer.evaluate_source(source, source_path: path), :itself, path
    end
  end
end
