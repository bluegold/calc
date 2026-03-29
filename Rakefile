require "rake/testtask"
require "rdoc/task"
require "fileutils"
require "webrick"

DOC_DIR = ENV.fetch('RDOC_DIR', 'dist/doc')

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"]
end

RDoc::Task.new do |rdoc|
  rdoc.main = 'README.md'
  rdoc.rdoc_dir = DOC_DIR
  rdoc.rdoc_files.include('lib/**/*.rb', 'README.md')
  rdoc.options << '--line-numbers' # Optional: Add line numbers to the generated HTML
  rdoc.options << '--webcvs=https://github.com/your-org/calc' # Optional: Link to GitHub
end

task :default => [:test, :doc]

desc "Generate RDoc documentation"
task :doc => :rdoc

desc "Serve RDoc with WEBrick"
task :doc_server do
  port = ENV.fetch("PORT", "8000").to_i

  server = WEBrick::HTTPServer.new(
    Port: port,
    DocumentRoot: File.expand_path(DOC_DIR)
  )

  trap("INT") { server.shutdown }

  puts "Serving doc at http://localhost:#{port}"
  server.start
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
  built_gem_file = FileList.new("*.gem").sort_by { |f| File.mtime(f) }.last

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
