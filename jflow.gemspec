# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'jflow/version'

Gem::Specification.new do |spec|
  spec.name          = "jflow"
  spec.version       = JFlow::VERSION
  spec.authors       = ["Christophe Verbinnen","Richard Vorp"]
  spec.email         = ["christophe.verbinnen@lookout.com","richard.vorp@lookout.com"]

  spec.summary       = %q{SWF Flow framework for jRuby}
  spec.description   = %q{you know, for flow}
  spec.homepage      = "https://github.com/djpate/jflow"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "bin"
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "aws-sdk", "~> 2"
  spec.add_runtime_dependency "hash_validator", "~> 0.4"
  spec.add_runtime_dependency "jflow_exceptions", "~> 0.1.1"

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "simplecov"

end
