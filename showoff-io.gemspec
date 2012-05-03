# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{showoff-io}
  s.version = "0.3.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Medium"]
  s.date = %q{2011-05-16}
  s.default_executable = %q{show}
  s.description = %q{The easiest way to share localhost over the web.}
  s.email = ["support@showoff.io"]
  s.executables = ["show"]
  s.files = ["Rakefile", "Gemfile", "lib/showoff/client.rb", "lib/showoff/settings.rb", "lib/showoff/api.rb", "lib/showoff/helpers.rb", "lib/showoff/version.rb", "lib/showoff/setup.rb", "lib/showoff/session.rb", "lib/showoff.rb", "bin/show"]
  s.homepage = %q{http://showoff.io/}
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{showoff}
  s.rubygems_version = %q{1.5.3}
  s.summary = %q{The easiest way to share localhost over the web.}

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<json_pure>, [">= 0"])
      s.add_runtime_dependency(%q<rest-client>, ["= 1.6.1"])
      s.add_runtime_dependency(%q<net-ssh>, [">= 2.0.23"])
      s.add_runtime_dependency(%q<highline>, [">= 1.6.1"])
    else
      s.add_dependency(%q<json_pure>, [">= 0"])
      s.add_dependency(%q<rest-client>, ["= 1.6.1"])
      s.add_dependency(%q<net-ssh>, [">= 2.0.23"])
      s.add_dependency(%q<highline>, [">= 1.6.1"])
    end
  else
    s.add_dependency(%q<json_pure>, [">= 0"])
    s.add_dependency(%q<rest-client>, ["= 1.6.1"])
    s.add_dependency(%q<net-ssh>, [">= 2.0.23"])
    s.add_dependency(%q<highline>, [">= 1.6.1"])
  end
end
