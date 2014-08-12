lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'rspec/core/rake_task'
# require 'escher'

namespace :gem do
  task :build do
    system "gem build escher.gemspec"
  end

  task :release => :build do
    system "gem push escher-#{Escher::VERSION}.gem"
  end
end

namespace :test do

  desc 'Run RSpec code examples (options: RSPEC_SEED=seed)'
  RSpec::Core::RakeTask.new :spec do |task|
    task.pattern = './spec{,/*/**}/*_spec.rb'
    task.verbose = false
    task.rspec_opts = '--order random'
    task.rspec_opts = '--color'
    task.rspec_opts = '--format documentation'
    task.rspec_opts << " --seed #{ENV['RSPEC_SEED']}" if ENV['RSPEC_SEED']
  end

end
