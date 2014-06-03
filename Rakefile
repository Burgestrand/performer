require "bundler/gem_tasks"

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new

desc "Start a console with the code loaded."
task :console do
  exec "irb", "-Ilib", "-rperformer"
end

task default: :spec
