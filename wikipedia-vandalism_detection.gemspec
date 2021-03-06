# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'wikipedia/vandalism_detection/version'

Gem::Specification.new do |spec|
  spec.name          = "wikipedia-vandalism_detection"
  spec.version       = Wikipedia::VandalismDetection::VERSION
  spec.authors       = ["Paul Götze"]
  spec.email         = ["paul.christoph.goetze@gmail.com"]
  spec.summary       = %q{Wikipedia vandalism detection with JRuby.}
  spec.description   = %q{Wikipedia vandalism detection with JRuby.}
  spec.homepage      = ""
  spec.license       = "GPL v3"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.extensions    = ["Rakefile"]
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "ruby-band", "~> 0.1"
  spec.add_runtime_dependency "nokogiri"
  spec.add_runtime_dependency "activesupport"

  spec.add_development_dependency "bundler", "~> 1.5"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "factory_girl"
end
