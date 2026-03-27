require_relative "test_helper"
require "bigdecimal"
require "json"

class BuiltinsDictionaryTest < Minitest::Test
  def setup
    @builtins = Calc::Builtins.new
  end

  def test_builds_hashes_with_last_key_wins
    result = @builtins.call("hash", [":name", "taro", ":name", "hanako", ":age", BigDecimal("20")])

    assert_equal({ "name" => "hanako", "age" => BigDecimal("20") }, result)
  end

  def test_rejects_non_keyword_hash_keys
    error = assert_raises(Calc::RuntimeError) { @builtins.call("hash", %w[name taro]) }

    assert_equal "hash keys must be keywords", error.message
  end

  def test_get_reads_from_hashes_and_lists
    hash = { "name" => "taro" }
    list = [BigDecimal("1"), BigDecimal("2")]

    assert_equal "taro", @builtins.call("get", [hash, ":name"])
    assert_equal BigDecimal("2"), @builtins.call("get", [list, BigDecimal("1")])
    assert_nil @builtins.call("get", [hash, ":missing"])
  end

  def test_set_returns_new_hashes_and_lists
    hash = { "name" => "taro" }
    list = [BigDecimal("1"), BigDecimal("2")]

    assert_equal({ "name" => "hanako" }, @builtins.call("set", [hash, ":name", "hanako"]))
    assert_equal({ "0" => "hello" }, @builtins.call("set", [{}, ":0", "hello"]))
    assert_equal([BigDecimal("1"), BigDecimal("9")], @builtins.call("set", [list, BigDecimal("1"), BigDecimal("9")]))
  end

  # rubocop:disable Minitest/MultipleAssertions
  def test_set_rejects_invalid_key_types_and_indices
    key_error = assert_raises(Calc::RuntimeError) { @builtins.call("set", [{}, BigDecimal("0"), "value"]) }
    index_error = assert_raises(Calc::RuntimeError) { @builtins.call("set", [[1, 2], BigDecimal("9"), "value"]) }

    assert_equal "hash keys must be keywords", key_error.message
    assert_equal "set expects a valid list index", index_error.message
  end
  # rubocop:enable Minitest/MultipleAssertions

  # rubocop:disable Minitest/MultipleAssertions
  def test_entries_keys_values_and_has_helpers
    hash = { "name" => "taro", "age" => BigDecimal("20") }

    assert_equal [[":name", "taro"], [":age", BigDecimal("20")]], @builtins.call("entries", [hash])
    assert_equal [":name", ":age"], @builtins.call("keys", [hash])
    assert_equal ["taro", BigDecimal("20")], @builtins.call("values", [hash])
    assert @builtins.call("has?", [hash, ":name"])
    refute @builtins.call("has?", [hash, ":missing"])
    assert @builtins.call("has?", [[1, 2], BigDecimal("1")])
    refute @builtins.call("has?", [[1, 2], BigDecimal("9")])
  end
  # rubocop:enable Minitest/MultipleAssertions

  def test_dig_reads_nested_hashes_and_lists
    payload = { "items" => [{ "name" => "taro" }] }

    assert_equal "taro", @builtins.call("dig", [payload, ":items", BigDecimal("0"), ":name"])
    assert_nil @builtins.call("dig", [payload, ":items", BigDecimal("1"), ":name"])
  end

  def test_hash_from_pairs_builds_hash
    pairs = [[":name", "taro"], [":age", BigDecimal("20")], [":name", "hanako"]]

    assert_equal({ "name" => "hanako", "age" => BigDecimal("20") }, @builtins.call("hash-from-pairs", [pairs]))
  end

  # rubocop:disable Minitest/MultipleAssertions
  def test_list_access_helpers
    list = [BigDecimal("1"), BigDecimal("2"), BigDecimal("3")]

    assert_equal [BigDecimal("0"), BigDecimal("1"), BigDecimal("2"), BigDecimal("3")],
                 @builtins.call("cons", [BigDecimal("0"), list])
    assert_equal [BigDecimal("1"), BigDecimal("2"), BigDecimal("3"), BigDecimal("4")],
                 @builtins.call("append", [list, BigDecimal("4")])
    assert_equal [BigDecimal("1"), BigDecimal("2"), BigDecimal("3"), BigDecimal("4"), BigDecimal("5")],
                 @builtins.call("concat-list", [list, [BigDecimal("4"), BigDecimal("5")]])
    assert_equal BigDecimal("2"), @builtins.call("nth", [BigDecimal("1"), list])
    assert_nil @builtins.call("nth", [BigDecimal("9"), list])
    assert_equal BigDecimal("1"), @builtins.call("first", [list])
    assert_equal [BigDecimal("2"), BigDecimal("3")], @builtins.call("rest", [list])
  end
  # rubocop:enable Minitest/MultipleAssertions

  def test_parses_json_into_calc_values
    input = '{"name":"taro","scores":[1,2.5],"meta":{"active":true}}'

    result = @builtins.call("parse-json", [input])

    assert_equal "taro", result["name"]
    assert_equal [BigDecimal("1"), BigDecimal("2.5")], result["scores"]
    assert_equal({ "active" => true }, result["meta"])
  end

  def test_parse_json_requires_string
    error = assert_raises(Calc::RuntimeError) { @builtins.call("parse-json", [123]) }

    assert_equal "parse-json expects a string", error.message
  end

  def test_stringifies_calc_values_into_json
    value = { "name" => "taro", "scores" => [BigDecimal("1"), BigDecimal("2.5")], "meta" => { "active" => true } }

    assert_equal '{"name":"taro","scores":[1,2.5],"meta":{"active":true}}', @builtins.call("stringify-json", [value])
  end

  def test_stringify_json_keeps_unrepresentable_bigdecimals_as_strings
    huge = BigDecimal("1e1000")
    value = { "huge" => huge, "tiny" => BigDecimal("0.1") }
    expected = { "huge" => huge.to_s("F"), "tiny" => 0.1 }

    assert_equal JSON.generate(expected), @builtins.call("stringify-json", [value])
  end
end
