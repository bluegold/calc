Dir.glob(File.join(__dir__, "functions", "*.rb")).each do |path|
  require_relative path.delete_prefix("#{__dir__}/")
end

module Calc
  module Functions
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
