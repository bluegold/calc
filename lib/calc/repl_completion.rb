module Calc
  class ReplCompletion
    COMMANDS = [":ast", ":help"].freeze
    TOKEN_DELIMITERS = /[\s(){}\[\]]/

    def initialize(builtins, commands: COMMANDS, symbol_candidates_provider: nil)
      @commands = commands.sort
      @builtins = builtins
      @symbol_candidates_provider = symbol_candidates_provider
    end

    def candidates(fragment, line_buffer, cursor)
      return [] if fragment.to_s.empty?

      if command_context?(line_buffer.to_s, cursor.to_i)
        prefix_matches(@commands, fragment)
      else
        prefix_matches(symbol_candidates(line_buffer.to_s, cursor.to_i), fragment)
      end
    end

    private

    def prefix_matches(candidates, fragment)
      escaped = Regexp.escape(fragment)
      candidates.grep(/^#{escaped}/)
    end

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

    def command_context?(line_buffer, cursor)
      return false if line_buffer.empty?

      fragment_start = token_start(line_buffer, cursor)
      command_start = line_buffer.index(/\S/)
      command_start == fragment_start && line_buffer[command_start] == ":"
    end

    def active_namespace_path(line_buffer, cursor)
      source = line_buffer[0...cursor]
      frames = []

      tokenize(source).each do |token|
        case token[:type]
        when :lparen
          frames << { head: nil, namespace_name: nil, namespace_path: nil }
        when :rparen
          frames.pop
        when :symbol
          frame = frames.last
          next unless frame

          if frame[:head].nil?
            frame[:head] = token[:value]
          elsif frame[:head] == "namespace" && frame[:namespace_name].nil?
            frame[:namespace_name] = token[:value]
            parent_path = frames[0...-1].reverse.find { |candidate| candidate[:namespace_path] }&.dig(:namespace_path)
            frame[:namespace_path] = resolve_namespace_path(parent_path, frame[:namespace_name])
          end
        end
      end

      frames.reverse.find { |frame| frame[:namespace_path] }&.dig(:namespace_path)
    end

    def resolve_namespace_path(parent_path, name)
      return name if name.include?(".")

      parent_path ? "#{parent_path}.#{name}" : name
    end

    def tokenize(source)
      tokens = []
      index = 0

      while index < source.length
        char = source[index]

        case char
        when ";"
          newline = source.index("\n", index)
          break unless newline

          index = newline + 1
        when '"'
          index += 1
          while index < source.length
            if source[index] == "\\"
              index += 2
            elsif source[index] == '"'
              index += 1
              break
            else
              index += 1
            end
          end
        when "("
          tokens << { type: :lparen }
          index += 1
        when ")"
          tokens << { type: :rparen }
          index += 1
        when /\s/
          index += 1
        else
          start = index
          index += 1
          while index < source.length && source[index] !~ /[\s()]/
            index += 1
          end

          tokens << { type: :symbol, value: source[start...index] }
        end
      end

      tokens
    end

    def token_start(line_buffer, cursor)
      head = line_buffer[0...cursor]
      delimiter_index = head.rindex(TOKEN_DELIMITERS)

      delimiter_index ? delimiter_index + 1 : 0
    end
  end
end
