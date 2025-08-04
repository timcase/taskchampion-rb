# frozen_string_literal: true

require "bundler/gem_tasks"
require "rubocop/rake_task"
require "rake/testtask"

RuboCop::RakeTask.new

require "rb_sys/extensiontask"

task build: :compile

GEMSPEC = Gem::Specification.load("taskchampion.gemspec")

RbSys::ExtensionTask.new("taskchampion", GEMSPEC) do |ext|
  ext.lib_dir = "lib/taskchampion"
end

Rake::TestTask.new(:test) do |t|
  t.libs << "test"
  t.libs << "lib"
  t.test_files = FileList["test/**/test_*.rb"]
  t.verbose = true
end

task test: :compile

task default: %i[compile test]
