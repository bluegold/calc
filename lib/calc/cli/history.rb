require "json"
require "reline"

module Calc
  module Cli
    module History
      module_function

      # Loads history before a block and saves it after the block finishes.
      def with_session(path, history: Reline::HISTORY, warning_io: $stderr)
        return enum_for(:with_session, path, history: history, warning_io: warning_io) unless block_given?

        load(path, history: history, warning_io: warning_io)
        yield
      ensure
        save(path, history: history, warning_io: warning_io)
      end

      # Loads command history from disk when the path points to a regular file.
      def load(path, history: Reline::HISTORY, warning_io: $stderr)
        if File.file?(path)
          append_entries(history_entries(File.read(path)), history)
        elsif File.exist?(path)
          warning_io.puts "ignoring non-regular history file: #{path}"
        end
      end

      # Persists in-memory history as JSON while tolerating filesystem errors.
      def save(path, history: Reline::HISTORY, warning_io: $stderr)
        File.write(path, JSON.pretty_generate(history.to_a))
      rescue SystemCallError => e
        warning_io.puts "failed to write history: #{e.message}"
      end

      # Parses known history formats and returns a normalized entry array.
      def history_entries(contents)
        parsed = parse_history_json(contents)
        return parsed if parsed

        contents.each_line(chomp: true).to_a
      end

      # Attempts to parse JSON history and ignores non-array payloads.
      def parse_history_json(contents)
        entries = JSON.parse(contents)
        return entries if entries.is_a?(Array)

        nil
      rescue JSON::ParserError
        nil
      end

      # Appends valid, non-empty string entries to the active history object.
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
