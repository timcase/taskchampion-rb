# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in taskchampion-rb.gemspec
gemspec

group :development do
  gem "rake", "~> 13.0"
  gem "rake-compiler", "~> 1.2"
  gem "rb_sys", "~> 0.9"
  gem "minitest", "~> 5.0"
  gem "mocha", "~> 2.0"
  gem "yard", "~> 0.9"
  gem "erb", "< 5.0" # Keep compatible with Ruby 3.1
  gem "irb"
end

group :rubocop do
  gem "activesupport", "< 8.0" # Keep compatible with Ruby 3.0+
  gem "rubocop-rails-omakase", require: false
end
