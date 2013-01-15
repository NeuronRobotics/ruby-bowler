# -*- encoding: utf-8 -*-
require File.expand_path('../lib/dyio/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Solly Ross"]
  gem.email         = ["directxman12+gh@gmail.com"]
  gem.description   = %q{The official ruby library for communicating with Bowler devices (see http://bowler.io), such as the (Neuron Robotics) DyIO}
  gem.summary       = %q{Easy communication with the DyIO coprocessor}
  gem.homepage      = "https://github.com/directxman12/ruby-dyio"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "ruby-dyio"
  gem.require_paths = ["lib"]
  gem.version       = Bowler::Gem::VERSION

  gem.add_runtime_dependency 'activesupport'
  gem.add_runtime_dependency 'em-synchrony'
  gem.add_runtime_dependency 'eventmachine'
  gem.add_runtime_dependency 'serialport'

  gem.add_development_dependency 'yard'
end
