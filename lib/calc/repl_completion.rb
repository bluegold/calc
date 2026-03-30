module Calc
  # Provides auto-completion functionality for the Calc REPL (Read-Eval-Print Loop).
  # It generates suggestions for commands, built-in functions, and user-defined symbols
  # based on the current input buffer and cursor position.
  class ReplCompletion
    # List of built-in REPL commands that can be completed.
    COMMANDS = [":ast", ":bytecode", ":help"].freeze
    # Regular expression for token delimiters, used to identify the start of a completion fragment.
    TOKEN_DELIMITERS = /[\s(){}\[\]]/

    # Initializes the ReplCompletion instance.
    #
    # @param builtins [Builtins] An instance of the Builtins registry.
    # @param commands [Array<String>] A list of available REPL commands.
    # @param symbol_candidates_provider [Proc, nil] A callable object (Proc) that provides symbol candidates.
    def initialize(builtins, commands: COMMANDS, symbol_candidates_provider: nil)
      @commands = commands.sort
      @builtins = builtins
      @symbol_candidates_provider = symbol_candidates_provider
    end

    # Generates a list of completion candidates based on the current fragment,
    # line buffer, and cursor position.
    #
    # @param fragment [String] The partial string being typed.
    # @param line_buffer [String] The entire line buffer content.
    # @param cursor [Integer] The current cursor position in the line buffer.
    # @return [Array<String>] A sorted list of matching completion candidates.
    def candidates(fragment, line_buffer, cursor)
      return [] if fragment.to_s.empty?

      if command_context?(line_buffer.to_s, cursor.to_i)
        prefix_matches(@commands, fragment)
      else
        prefix_matches(symbol_candidates(line_buffer.to_s, cursor.to_i), fragment)
      end
    end

    private

    # Filters a list of candidates to those that start with the given fragment.
    #
    # @param candidates [Array<String>] The list of possible completion strings.
    # @param fragment [String] The partial string to match.
    # @return [Array<String>] A filtered list of candidates.
    def prefix_matches(candidates, fragment)
      escaped = Regexp.escape(fragment)
      candidates.grep(/^#{escaped}/)
    end

    # Retrieves symbol candidates, either from the provider or default built-ins/literals.
    #
    # @param line_buffer [String] The entire line buffer content.
    # @param cursor [Integer] The current cursor position.
    # @return [Array<String>] A sorted list of symbol candidates.
    def symbol_candidates(line_buffer, cursor)
      source = if @symbol_candidates_provider
                 namespace_path = active_namespace_path(line_buffer, cursor)
                 if @symbol_candidates_provider.arity == 1
                   @symbol_candidates_provider.call(namespace_path)
                 else
                   @symbol_candidates_provider.call
                 end
               end
      candidates = source || (@builtins.each_builtin.map(&:name) + Builtins::LITERALS.keys)
      candidates.uniq.sort
    end

    # Determines if the current input context suggests a REPL command completion.
    #
    # @param line_buffer [String] The entire line buffer content.
    # @param cursor [Integer] The current cursor position.
    # @return [Boolean] True if in command context, false otherwise.
    def command_context?(line_buffer, cursor)
      return false if line_buffer.empty?

      fragment_start = token_start(line_buffer, cursor)
      command_start = line_buffer.index(/\S/)
      command_start == fragment_start && line_buffer[command_start] == ":"
    end

    # Analyzes the line buffer up to the cursor to determine the active namespace path.
    # This is rudimentary parsing to infer namespace context.
    #
    # @param line_buffer [String] The entire line buffer content.
    # @param cursor [Integer] The current cursor position.
    # @return [String, nil] The active namespace path, or nil if none inferred.
    def active_namespace_path(line_buffer, cursor)
      source = line_buffer[0...cursor]
      frames = []

      tokenize(source).each { |token| process_namespace_token(frames, token) }

      frames.reverse.find { |frame| frame[:namespace_path] }&.dig(:namespace_path)
    end

    # Processes a token to update the namespace stack (frames) for context inference.
    #
    # @param frames [Array<Hash>] The stack of namespace frames.
    # @param token [Hash] The token to process (e.g., {type: :lparen}).
    def process_namespace_token(frames, token)
      case token[:type]
      when :lparen
        frames << { head: nil, namespace_name: nil, namespace_path: nil }
      when :rparen
        frames.pop
      when :symbol
        apply_symbol_to_frame(frames, token[:value])
      end
    end

    # Applies a symbol token to the current namespace frame to infer head and namespace name.
    #
    # @param frames [Array<Hash>] The stack of namespace frames.
    # @param value [String] The value of the symbol token.
    def apply_symbol_to_frame(frames, value)
      frame = frames.last
      return unless frame

      if frame[:head].nil?
        frame[:head] = value
        return
      end

      return unless frame[:head] == "namespace" && frame[:namespace_name].nil?

      frame[:namespace_name] = value
      frame[:namespace_path] = resolve_namespace_path(parent_namespace_path(frames), value)
    end

    # Determines the parent namespace path from the current stack of frames.
    #
    # @param frames [Array<Hash>] The stack of namespace frames.
    # @return [String, nil] The parent namespace path, or nil.
    def parent_namespace_path(frames)
      frames[0...-1].reverse.find { |candidate| candidate[:namespace_path] }&.dig(:namespace_path)
    end

    # Resolves a namespace name relative to a parent path.
    #
    # @param parent_path [String, nil] The parent namespace path.
    # @param name [String] The name of the namespace.
    # @return [String] The resolved full namespace path.
    def resolve_namespace_path(parent_path, name)
      return name if name.include?(".")

      parent_path ? "#{parent_path}.#{name}" : name
    end

    # Basic tokenizer for parsing namespace context in the REPL input.
    # This is a simplified version of the main parser's tokenizer.
    #
    # @param source [String] The source string to tokenize.
    # @return [Array<Hash>] An array of token hashes (e.g., {type: :lparen, value: "("}).
    def tokenize(source)
      tokens = []
      index = 0

      while index < source.length
        char = source[index]

        case char
        when ";"
          index = skip_comment(source, index)
          break unless index
        when '"'
          index = skip_quoted_string(source, index)
        when "("
          tokens << { type: :lparen }
          index += 1
        when ")"
          tokens << { type: :rparen }
          index += 1
        when /\s/
          index += 1
        else
          token, index = read_symbol(source, index)
          tokens << token
        end
      end

      tokens
    end

    # Skips a comment in the source string.
    #
    # @param source [String] The source string.
    # @param index [Integer] The current position.
    # @return [Integer, nil] The new position after the comment, or nil if no newline found.
    def skip_comment(source, index)
      newline = source.index("\n", index)
      return nil unless newline

      newline + 1
    end

    # Skips a quoted string in the source string, handling escape sequences.
    #
    # @param source [String] The source string.
    # @param index [Integer] The current position (should be at the opening quote).
    # @return [Integer] The new position after the closing quote.
    def skip_quoted_string(source, index)
      index += 1
      while index < source.length
        if source[index] == "\\"
          index += 2
          next
        end

        return index + 1 if source[index] == '"'

        index += 1
      end

      index
    end

    # Reads a symbol from the source string.
    #
    # @param source [String] The source string.
    # @param index [Integer] The current position.
    # @return [Array<Hash, Integer>] A pair of [token_hash, new_index].
    def read_symbol(source, index)
      start = index
      index += 1
      index += 1 while index < source.length && source[index] !~ /[\s()]/

      [{ type: :symbol, value: source[start...index] }, index]
    end

    # Determines the starting position of the current token fragment for completion.
    #
    # @param line_buffer [String] The entire line buffer content.
    # @param cursor [Integer] The current cursor position.
    # @return [Integer] The starting index of the token fragment.
    def token_start(line_buffer, cursor)
      head = line_buffer[0...cursor]
      delimiter_index = head.rindex(TOKEN_DELIMITERS)

      delimiter_index ? delimiter_index + 1 : 0
    end
  end
end
