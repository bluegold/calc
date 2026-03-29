# frozen_string_literal: true

require_relative "../lib/calc/functions/types"

SPEC_PATH = File.expand_path("../docs/spec.md", __dir__)
BEGIN_MARKER = "<!-- BUILTINS:BEGIN -->"
END_MARKER = "<!-- BUILTINS:END -->"

CATEGORY_ORDER = %w[
  arithmetic
  comparison
  math
  higher-order
  list
  hash
  string
  io
  json
  time
].freeze

CATEGORY_LABELS = {
  "arithmetic" => "Arithmetic",
  "comparison" => "Comparison",
  "math" => "Math",
  "higher-order" => "Higher-order",
  "list" => "List",
  "hash" => "Hash",
  "string" => "String",
  "io" => "IO",
  "json" => "JSON",
  "time" => "Time"
}.freeze

def grouped_builtins
  groups = Hash.new { |h, k| h[k] = [] }

  Calc::Functions::Types::MAP.each do |name, category|
    groups[category] << name
  end

  groups.each_value(&:sort!)
  groups
end

def render_generated_lines
  groups = grouped_builtins

  CATEGORY_ORDER.filter_map do |category|
    names = groups[category]
    next if names.nil? || names.empty?

    formatted_names = names.map { |name| "`#{name}`" }.join(", ")
    "- #{CATEGORY_LABELS.fetch(category)}: #{formatted_names}"
  end
end

def replace_generated_block(source)
  start_idx = source.index(BEGIN_MARKER)
  end_idx = source.index(END_MARKER)

  raise "missing #{BEGIN_MARKER} in #{SPEC_PATH}" unless start_idx
  raise "missing #{END_MARKER} in #{SPEC_PATH}" unless end_idx
  raise "marker order is invalid in #{SPEC_PATH}" unless start_idx < end_idx

  generated = ([BEGIN_MARKER] + render_generated_lines + [END_MARKER]).join("\n")

  head = source[0...start_idx]
  tail = source[(end_idx + END_MARKER.length)..]
  [head, generated, tail].join
end

source = File.read(SPEC_PATH)
updated = replace_generated_block(source)

if updated == source
  puts "No changes in #{SPEC_PATH}"
else
  File.write(SPEC_PATH, updated)
  puts "Updated #{SPEC_PATH}"
end
