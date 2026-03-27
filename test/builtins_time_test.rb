require_relative "test_helper"
require "bigdecimal"
require "time"

class BuiltinsTimeTest < Minitest::Test
  def setup
    @builtins = Calc::Builtins.new
  end

  def test_parse_time_returns_epoch_microseconds
    result = @builtins.call("parse-time", ["2026-03-27T12:34:56.123456Z"])

    assert_equal BigDecimal("1774614896123456"), result
  end

  def test_parse_time_without_timezone_treated_as_utc
    with_timezone("Asia/Tokyo") do
      result = @builtins.call("parse-time", ["2026-03-27 12:34:56"])

      assert_equal "2026-03-27T12:34:56.000000Z", @builtins.call("format-time", [result])
    end
  end

  def test_format_time_without_format_uses_iso8601
    input = BigDecimal("1774614896123456")

    assert_equal "2026-03-27T12:34:56.123456Z", @builtins.call("format-time", [input])
  end

  def test_format_time_with_strftime_format
    input = BigDecimal("1774614896123456")

    assert_equal "2026/03/27 12:34", @builtins.call("format-time", [input, "%Y/%m/%d %H:%M"])
  end

  # rubocop:disable Minitest/MultipleAssertions
  def test_next_prev_and_month_boundaries
    jan31 = @builtins.call("parse-time", ["2026-01-31T10:20:30.400500Z"])
    next_month = @builtins.call("next-month", [jan31])
    prev_month = @builtins.call("prev-month", [next_month])
    beginning = @builtins.call("beggining-of-month", [jan31])
    ending = @builtins.call("end-of-month", [jan31])

    assert_equal "2026-02-28T10:20:30.400500Z", @builtins.call("format-time", [next_month])
    assert_equal "2026-01-28T10:20:30.400500Z", @builtins.call("format-time", [prev_month])
    assert_equal "2026-01-01T00:00:00.000000Z", @builtins.call("format-time", [beginning])
    assert_equal "2026-01-31T23:59:59.999999Z", @builtins.call("format-time", [ending])
  end
  # rubocop:enable Minitest/MultipleAssertions

  def test_current_time_returns_integer_microseconds
    value = @builtins.call("current-time", [])

    assert_instance_of BigDecimal, value
    assert_predicate value.frac, :zero?
  end

  def test_rejects_non_integer_epoch_value
    error = assert_raises(Calc::RuntimeError) { @builtins.call("format-time", [BigDecimal("1.5")]) }

    assert_equal "time value must be an integer microsecond epoch", error.message
  end

  def test_parse_time_requires_string
    error = assert_raises(Calc::RuntimeError) { @builtins.call("parse-time", [123]) }

    assert_equal "parse-time expects a string", error.message
  end

  private

  def with_timezone(tz)
    original = ENV.fetch("TZ", nil)
    ENV["TZ"] = tz
    yield
  ensure
    original.nil? ? ENV.delete("TZ") : ENV["TZ"] = original
  end
end
