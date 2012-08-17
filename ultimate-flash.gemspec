# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "ultimate-flash/version"

Gem::Specification.new do |s|
  s.name        = "ultimate-flash"
  s.version     = Ultimate::Flash::VERSION
  s.authors     = ["Dmitry KODer Karpunin"]
  s.email       = ["koderfunk@gmail.com"]
  s.homepage    = "http://github.com/KODerFunk/ultimate-flash"
  s.summary     = %q{Ruby on Rails oriented jQuery plugin for smart notifications}
  s.description = %q{Ruby on Rails oriented jQuery plugin for smart notifications}

  s.rubyforge_project = "ultimate-flash"

  s.add_dependency "ultimate-base", "~> 0.2"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

end
