# frozen_string_literal: true

require "bundler/gem_tasks"
require "rubocop/rake_task"
require "rake/testtask"

RuboCop::RakeTask.new

require "rb_sys/extensiontask"

task build: :compile

GEMSPEC = Gem::Specification.load("taskchampion-rb.gemspec")

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

desc "Bump version, create tag, and release gem"
task :publish, [:version] do |t, args|
  version = args[:version] || "patch"

  puts "Bumping version (#{version})..."
  # Commit and tag here rather than with bump --tag: bump's "vX.Y.Z"
  # subject fails the commit-msg hook, and bump tags even when the
  # commit fails.
  sh "bump #{version} --no-commit"
  new_version = `bump current --value-only`.strip
  sh "git add lib/taskchampion/version.rb Gemfile.lock"
  sh "git commit -m 'Bump to v#{new_version}'"
  sh "git tag -a v#{new_version} -m v#{new_version}"

  puts "Pushing to git..."
  sh "git push && git push origin v#{new_version}"

  puts "Building and releasing gem..."
  Rake::Task["release"].invoke
end
