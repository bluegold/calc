require_relative "test_helper"
require "stringio"

class ReplRunnerTest < Minitest::Test
  def test_interrupt_exits_repl_gracefully
    out = StringIO.new
    err = StringIO.new
    runner = Calc::Cli::ReplRunner.new(
      parser: Object.new,
      executer: Object.new,
      command_handler: Object.new,
      history: [],
      io: { out: out, err: err }
    )

    reline_singleton = Reline.singleton_class
    original_readline = reline_singleton.instance_method(:readline)

    reline_singleton.send(:remove_method, :readline)
    reline_singleton.define_method(:readline) do |*_args|
      raise Interrupt
    end

    runner.run

    assert_equal "\n", out.string
    assert_empty err.string
  ensure
    reline_singleton.send(:remove_method, :readline) if reline_singleton.method_defined?(:readline)
    reline_singleton.define_method(:readline, original_readline)
  end
end
