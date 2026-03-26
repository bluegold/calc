Gem::Specification.new do |spec|
  require_relative "lib/calc/version"

  spec.name = "calc"
  spec.version = Calc::VERSION
  spec.summary = "A Ruby S-expression calculator"
  spec.description = "A Ruby-based S-expression calculator with namespaces, functions, and a REPL."
  spec.authors = ["kaneko"]
  spec.email = ["kaneko@example.com"]
  spec.homepage = "https://github.com/bluegold/calc"
  spec.license = "MIT"

  spec.required_ruby_version = ">= 3.1"

  spec.files = Dir.chdir(__dir__) do
    Dir["README.md", "LICENSE*", "bin/**/*", "lib/**/*", "docs/**/*"]
  end
  spec.bindir = "bin"
  spec.executables = ["calc"]
  spec.require_paths = ["lib"]

  spec.add_dependency "bigdecimal"
end
