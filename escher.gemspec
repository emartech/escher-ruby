# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'escher/version'

Gem::Specification.new do |spec|
  spec.name          = "escher"
  spec.version       = Escher::VERSION
  spec.authors       = ["Andras Barthazi"]
  spec.email         = ["andras.barthazi@emarsys.com"]
  spec.summary       = %q{Library for HTTP request signing (Ruby implementation)}
  spec.description   = %q{Escher helps you creating secure HTTP requests (for APIs) by signing HTTP(s) requests.}
  spec.homepage      = "http://escherauth.io/"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 1.9'

  spec.add_development_dependency "bundler", "~> 2.4.10"
  spec.add_development_dependency "rails", "~> 7.0.4"

  spec.add_development_dependency "rake", "~> 13.0.6"
  spec.add_development_dependency "rspec", "~> 3"

  spec.add_development_dependency "rack"
  spec.add_development_dependency "plissken"

  spec.add_runtime_dependency "addressable", "~> 2.8.0"
end
