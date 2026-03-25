Dir.glob(File.join(__dir__, "functions", "*.rb")).sort.each do |path|
  require_relative path.delete_prefix("#{__dir__}/")
end

