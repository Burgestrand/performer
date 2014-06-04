# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'performer/version'

Gem::Specification.new do |spec|
  spec.name          = "performer"
  spec.version       = Performer::VERSION
  spec.authors       = ["Kim Burgestrand"]
  spec.email         = ["kim@burgestrand.se"]
  spec.summary       = %q{Schedule blocks in a background thread.}
  spec.description   = %q{Performer is a tiny gem for scheduling blocks in a background thread,
and optionally waiting for the return value.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "yard", "~> 0.8"
end
