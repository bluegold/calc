require_relative "test_helper"

class NamespaceRegistryTest < Minitest::Test
  def setup
    @registry = Calc::NamespaceRegistry.new
  end

  def test_ensures_nested_namespace_paths
    namespace = @registry.ensure_namespace("crypto.cipher")

    assert_equal "cipher", namespace.name
    assert_equal "crypto.cipher", namespace.path
    assert_equal "crypto", namespace.parent.name
  end

  def test_marks_underscore_names_as_local
    namespace = @registry.ensure_namespace("crypto.cipher")

    @registry.define_function("crypto.cipher", "_helper", :secret)
    @registry.define_variable("crypto.cipher", "_tmp", 1)

    function_entry = namespace.functions["_helper"]
    variable_entry = namespace.variables["_tmp"]

    assert function_entry[:local]
    assert variable_entry[:local]
  end

  def test_falls_back_to_builtin_namespace
    builtin = @registry.ensure_namespace("builtin")
    builtin.functions["pow"] = { value: :builtin_pow, local: false }

    assert_equal :builtin_pow, @registry.resolve_function("crypto.cipher", "pow")[:value]
  end

  def test_marks_builtin_as_reserved_namespace
    assert @registry.reserved_namespace?("builtin")
    refute @registry.reserved_namespace?("crypto")
  end

  def test_rejects_definitions_in_builtin_namespace
    error = assert_raises(NameError) { @registry.define_variable("builtin", "x", 1) }

    assert_match "cannot modify reserved namespace", error.message
  end

  def test_resolves_public_definitions_from_parent_namespaces
    @registry.ensure_namespace("crypto.cipher")
    @registry.define_variable("crypto", "shared", 9)

    assert_equal 9, @registry.resolve_variable("crypto.cipher", "shared")[:value]
  end

  def test_hides_local_definitions_from_child_namespaces
    @registry.ensure_namespace("crypto.cipher")
    @registry.define_variable("crypto", "_secret", 7, local: true)

    assert_nil @registry.resolve_variable("crypto.cipher", "_secret")
  end

  def test_root_local_names_are_resolvable_in_root_namespace
    @registry.define_variable(nil, "_root_tmp", 11, local: true)

    assert_equal 11, @registry.resolve_variable(nil, "_root_tmp")[:value]
  end

  def test_qualified_lookup_stays_within_target_namespace
    @registry.ensure_namespace("crypto")
    @registry.ensure_namespace("crypto.cipher")
    @registry.define_function("crypto", "twice", :crypto_twice)

    assert_nil @registry.resolve_function("crypto.cipher", "crypto.cipher.twice")
  end
end
