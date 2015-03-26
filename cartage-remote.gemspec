# -*- encoding: utf-8 -*-
# stub: cartage-remote 1.1 ruby lib

Gem::Specification.new do |s|
  s.name = "cartage-remote"
  s.version = "1.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Austin Ziegler"]
  s.date = "2015-03-26"
  s.description = "cartage-remote is a plug-in for {cartage}[https://github.com/KineticCafe/cartage]\nto build a package on a remote machine with cartage.\n\nCartage provides a repeatable means to create a package for a Rails application\nthat can be used in deployment with a configuration tool like Ansible, Chef,\nPuppet, or Salt. The package is created with its dependencies bundled in\n`vendor/bundle`, so it can be deployed in environments with strict access\ncontrol rules and without requiring development tool access."
  s.email = ["aziegler@kineticcafe.com"]
  s.extra_rdoc_files = ["Contributing.rdoc", "History.rdoc", "Licence.rdoc", "Manifest.txt", "README.rdoc", "Contributing.rdoc", "History.rdoc", "Licence.rdoc", "README.rdoc"]
  s.files = [".autotest", ".gemtest", ".minitest.rb", "Contributing.rdoc", "Gemfile", "History.rdoc", "Licence.rdoc", "Manifest.txt", "README.rdoc", "Rakefile", "lib/cartage/remote.rb", "lib/cartage/remote/command.rb"]
  s.homepage = "https://github.com/KineticCafe/cartage-remote/"
  s.licenses = ["MIT"]
  s.rdoc_options = ["--main", "README.rdoc"]
  s.rubygems_version = "2.2.2"
  s.summary = "cartage-remote is a plug-in for {cartage}[https://github.com/KineticCafe/cartage] to build a package on a remote machine with cartage"

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<cartage>, ["~> 1.1"])
      s.add_runtime_dependency(%q<micromachine>, ["~> 1.2"])
      s.add_runtime_dependency(%q<fog>, ["~> 1.27"])
      s.add_development_dependency(%q<minitest>, ["~> 5.5"])
      s.add_development_dependency(%q<rdoc>, ["~> 4.0"])
      s.add_development_dependency(%q<rake>, ["~> 10.0"])
      s.add_development_dependency(%q<hoe-doofus>, ["~> 1.0"])
      s.add_development_dependency(%q<hoe-gemspec2>, ["~> 1.1"])
      s.add_development_dependency(%q<hoe-git>, ["~> 1.5"])
      s.add_development_dependency(%q<hoe-geminabox>, ["~> 0.3"])
      s.add_development_dependency(%q<minitest-autotest>, ["~> 1.0"])
      s.add_development_dependency(%q<minitest-bisect>, ["~> 1.2"])
      s.add_development_dependency(%q<minitest-focus>, ["~> 1.1"])
      s.add_development_dependency(%q<minitest-moar>, ["~> 0.0"])
      s.add_development_dependency(%q<minitest-pretty_diff>, ["~> 0.1"])
      s.add_development_dependency(%q<simplecov>, ["~> 0.7"])
      s.add_development_dependency(%q<hoe>, ["~> 3.13"])
    else
      s.add_dependency(%q<cartage>, ["~> 1.1"])
      s.add_dependency(%q<micromachine>, ["~> 1.2"])
      s.add_dependency(%q<fog>, ["~> 1.27"])
      s.add_dependency(%q<minitest>, ["~> 5.5"])
      s.add_dependency(%q<rdoc>, ["~> 4.0"])
      s.add_dependency(%q<rake>, ["~> 10.0"])
      s.add_dependency(%q<hoe-doofus>, ["~> 1.0"])
      s.add_dependency(%q<hoe-gemspec2>, ["~> 1.1"])
      s.add_dependency(%q<hoe-git>, ["~> 1.5"])
      s.add_dependency(%q<hoe-geminabox>, ["~> 0.3"])
      s.add_dependency(%q<minitest-autotest>, ["~> 1.0"])
      s.add_dependency(%q<minitest-bisect>, ["~> 1.2"])
      s.add_dependency(%q<minitest-focus>, ["~> 1.1"])
      s.add_dependency(%q<minitest-moar>, ["~> 0.0"])
      s.add_dependency(%q<minitest-pretty_diff>, ["~> 0.1"])
      s.add_dependency(%q<simplecov>, ["~> 0.7"])
      s.add_dependency(%q<hoe>, ["~> 3.13"])
    end
  else
    s.add_dependency(%q<cartage>, ["~> 1.1"])
    s.add_dependency(%q<micromachine>, ["~> 1.2"])
    s.add_dependency(%q<fog>, ["~> 1.27"])
    s.add_dependency(%q<minitest>, ["~> 5.5"])
    s.add_dependency(%q<rdoc>, ["~> 4.0"])
    s.add_dependency(%q<rake>, ["~> 10.0"])
    s.add_dependency(%q<hoe-doofus>, ["~> 1.0"])
    s.add_dependency(%q<hoe-gemspec2>, ["~> 1.1"])
    s.add_dependency(%q<hoe-git>, ["~> 1.5"])
    s.add_dependency(%q<hoe-geminabox>, ["~> 0.3"])
    s.add_dependency(%q<minitest-autotest>, ["~> 1.0"])
    s.add_dependency(%q<minitest-bisect>, ["~> 1.2"])
    s.add_dependency(%q<minitest-focus>, ["~> 1.1"])
    s.add_dependency(%q<minitest-moar>, ["~> 0.0"])
    s.add_dependency(%q<minitest-pretty_diff>, ["~> 0.1"])
    s.add_dependency(%q<simplecov>, ["~> 0.7"])
    s.add_dependency(%q<hoe>, ["~> 3.13"])
  end
end
