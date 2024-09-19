require "bundler/gem_tasks"
require "rspec/core/rake_task"

desc "Run RSpec code examples (options: RSPEC_SEED=seed)"
RSpec::Core::RakeTask.new :spec do |task|
  task.verbose = false
  task.rspec_opts = "--format progress --order random"
  task.rspec_opts << " --seed #{ENV['RSPEC_SEED']}" if ENV['RSPEC_SEED']
end

task :default => :spec

