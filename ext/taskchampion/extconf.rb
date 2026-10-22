# frozen_string_literal: true

require "mkmf"
require "rb_sys/mkmf"

# Opt in to compiling SQLite into the extension with either
#   TASKCHAMPION_BUNDLED_SQLITE=1
# or
#   gem install taskchampion-rb -- --with-bundled-sqlite
#   bundle config build.taskchampion-rb --with-bundled-sqlite
bundled_sqlite = with_config("bundled-sqlite") ||
                 %w[1 true yes].include?(ENV["TASKCHAMPION_BUNDLED_SQLITE"])

create_rust_makefile("taskchampion/taskchampion") do |r|
  r.features = ["bundled-sqlite"] if bundled_sqlite
end
