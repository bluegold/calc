require_relative "functions/metadata"

Dir.glob(File.join(__dir__, "functions", "*.rb")).each do |path|
  next if path.end_with?("/metadata.rb")

  require_relative path.delete_prefix("#{__dir__}/")
end

module Calc
  module Functions
    def self.register(builtins, name, min_arity: 0, max_arity: nil, **metadata, &)
      builtin_metadata = begin
        Metadata.fetch(name)
      rescue KeyError
        {}
      end

      builtins.register(
        name,
        min_arity: min_arity,
        max_arity: max_arity,
        type: metadata.fetch(:type, builtin_metadata[:type]),
        description: metadata.fetch(:description, builtin_metadata[:description]),
        example: metadata.fetch(:example, builtin_metadata[:example]),
        &
      )
    end

    def self.registrars
      constants(false)
        .map { |name| const_get(name) }
        .select { |constant| constant.respond_to?(:register) }
        .sort_by(&:name)
    end

    def self.register_all(builtins)
      registrars.each { |registrar| registrar.register(builtins) }
    end
  end
end
