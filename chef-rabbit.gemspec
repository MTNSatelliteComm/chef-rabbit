# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "chef/rabbit/version"

Gem::Specification.new do |s|
  s.name        = "chef-rabbit"
  s.version     = Chef::RABBIT::VERSION
  s.authors     = ["MTN Satellite Communications"]
  s.email       = ["marat.garafutdinov@mtnsat.com"]
  s.homepage    = "https://github.com/MTNSatelliteComm/chef-rabbit"
  s.summary     = %q{Provides a Chef handler which reports run failures and changes to a Rabbit server.}
  s.description = File.read("README.rdoc")

  s.rubyforge_project = "chef-rabbit"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_dependency "bunny", "~> 1.6.3"
  s.add_dependency "chef", "~> 11.0"
end
