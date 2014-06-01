require "bundler/gem_tasks"

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new

desc "Start a console with Puddle loaded."
task :console do
  exec "irb", "-Ilib", "-rpuddle"
end

task default: :spec
