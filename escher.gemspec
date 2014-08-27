# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'escher/version'

Gem::Specification.new do |spec|
  spec.name          = "escher"
  spec.version       = Escher::VERSION
  spec.authors       = ["Andras Barthazi"]
  spec.email         = ["andras.barthazi@emarsys.com"]
  spec.summary       = %q{Escher - Emarsys request signing library}
  spec.description   = %q{For Emarsys API}
  spec.homepage      = "http://emarsys.com"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 2"

  spec.add_runtime_dependency 'addressable'
end
