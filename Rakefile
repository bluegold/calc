require "rake/testtask"
require "yard"
require "yard/rake/yardoc_task"
require "fileutils"

DOC_DIR = ENV.fetch("YARD_DIR", "dist/doc")

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"]
end

YARD::Rake::YardocTask.new do |yard|
  yard.files = ["lib/**/*.rb"]
  yard.options = ["--output-dir", DOC_DIR, "--readme", "README.md"]
end

task default: %i[test doc]

namespace :spec do
  desc "Update docs/spec.md builtin list from runtime type map"
  task :update_builtins do
    sh "ruby script/update_spec_builtins.rb"
  end
end

desc "Generate YARD documentation"
task doc: :yard

desc "Serve documentation with YARD server"
task :doc_server do
  port = ENV.fetch("PORT", "8000").to_i
  bind = ENV.fetch("HOST", "127.0.0.1")

  sh "yard server --bind #{bind} --port #{port}"
end

desc "Build the gem and move it to the dist directory"
task :build_gem do
  gem_name = Dir.glob("*.gemspec").first
  unless gem_name
    puts "Error: No .gemspec file found in the current directory."
    exit 1
  end

  # Build the gem in the current directory
  sh "gem build #{gem_name}"

  # Get the name of the built gem file (e.g., calc-0.1.0.gem)
  # This assumes there's only one .gem file built, or we take the newest one.
  built_gem_file = FileList.new("*.gem").max_by { |f| File.mtime(f) }

  unless built_gem_file
    puts "Error: Gem file not found after building."
    exit 1
  end

  # Ensure the dist directory exists
  FileUtils.mkdir_p("dist")

  # Move the gem to the dist directory
  FileUtils.mv(built_gem_file, "dist/#{built_gem_file}")
  puts "Moved #{built_gem_file} to dist/"
end
