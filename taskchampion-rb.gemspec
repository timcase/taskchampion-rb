# frozen_string_literal: true

require_relative "lib/taskchampion/version"

Gem::Specification.new do |spec|
  spec.name = "taskchampion-rb"
  spec.version = Taskchampion::VERSION
  spec.authors = ["Tim Case"]
  spec.email = ["tim@wingtask.com"]

  spec.summary = "Ruby bindings for TaskChampion"
  spec.description = "TaskChampion is the task database that powers Taskwarrior. This gem provides Ruby bindings to the Rust implementation."
  spec.homepage = "https://github.com/timcase/taskchampion-rb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"
  spec.required_rubygems_version = ">= 3.3.11"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/timcase/taskchampion-rb"
  spec.metadata["changelog_uri"] = "https://github.com/timcase/taskchampion-rb/blob/main/CHANGELOG.md"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git .github appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]
  spec.extensions = ["ext/taskchampion/extconf.rb"]

  spec.add_dependency "rb_sys", "~> 0.9.91"
end
