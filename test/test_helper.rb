# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "taskchampion"

require "minitest/autorun"
require "mocha/minitest"
require "tmpdir"
require "fileutils"
require "securerandom"

class TaskchampionTest < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir("taskchampion-test")
  end

  def teardown
    FileUtils.remove_entry @temp_dir if @temp_dir && File.exist?(@temp_dir)
  end

  protected

  def temp_path(filename = nil)
    filename ? File.join(@temp_dir, filename) : @temp_dir
  end
end