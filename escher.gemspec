lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'escher'

Gem::Specification.new do |s|
  s.name        = 'escher'
  s.version     = Escher::VERSION
  s.date        = '2014-08-06'
  s.summary     = "Escher - Emarsys request signing library"
  s.description = "For Emarsys API"
  s.authors     = ["Andras Barthazi"]
  s.email       = 'andras.barthazi@emarsys.com'
  s.files       = Dir.glob("{lib}/**/*")
  s.homepage    = 'http://emarsys.com'
  s.license     = 'MIT'

  s.add_development_dependency('rspec', '~> 0')
  s.add_development_dependency('rake', '~> 0')
  s.add_development_dependency('codeclimate-test-reporter', '~> 0')
end