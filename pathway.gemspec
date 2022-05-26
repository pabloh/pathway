# frozen_string_literal: true

lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "pathway/version"

Gem::Specification.new do |spec|
  spec.name          = "pathway"
  spec.version       = Pathway::VERSION
  spec.authors       = ["Pablo Herrero"]
  spec.email         = ["pablodherrero@gmail.com"]

  spec.summary       = %q{Define your business logic in simple steps.}
  spec.description   = %q{Define your business logic in simple steps.}
  spec.homepage      = "https://github.com/pabloh/pathway"
  spec.license       = "MIT"

  spec.metadata      = {
    "bug_tracker_uri" => "https://github.com/pabloh/pathway/issues",
    "source_code_uri" => "https://github.com/pabloh/pathway",
  }

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.4.0"

  spec.add_dependency "dry-inflector", ">= 0.1.0"
  spec.add_dependency "contextualizer", "~> 0.0.4"
  spec.add_dependency "ruby2_keywords"

  spec.add_development_dependency "dry-validation", ">= 0.11"
  spec.add_development_dependency "bundler", "~> 2.3.7"
  spec.add_development_dependency "sequel", "~> 5.0"
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.11"
  spec.add_development_dependency "simplecov-lcov", '~> 0.8.0'
  spec.add_development_dependency "simplecov"
  spec.add_development_dependency "pry"
  spec.add_development_dependency "pry-byebug"
  spec.add_development_dependency "pry-doc"
end
