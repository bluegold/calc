require "json"
require "reline"

module Calc
  module Cli
    module History
      module_function

      def load(path, history: Reline::HISTORY, warning_io: $stderr)
        if File.file?(path)
          append_entries(history_entries(File.read(path)), history)
        elsif File.exist?(path)
          warning_io.puts "ignoring non-regular history file: #{path}"
        end
      end

      def save(path, history: Reline::HISTORY, warning_io: $stderr)
        File.write(path, JSON.pretty_generate(history.to_a))
      rescue SystemCallError => e
        warning_io.puts "failed to write history: #{e.message}"
      end

      def history_entries(contents)
        parsed = parse_history_json(contents)
        return parsed if parsed

        contents.each_line(chomp: true).to_a
      end

      def parse_history_json(contents)
        entries = JSON.parse(contents)
        return entries if entries.is_a?(Array)

        nil
      rescue JSON::ParserError
        nil
      end

      def append_entries(entries, history)
        entries.each do |entry|
          next unless entry.is_a?(String)
          next if entry.strip.empty?

          history << entry
        end
      end
    end
  end
end
