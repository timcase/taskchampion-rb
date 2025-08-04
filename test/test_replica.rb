# frozen_string_literal: true

require "test_helper"

class TestReplica < TaskchampionTest
  def test_new_in_memory
    replica = Taskchampion::Replica.new_in_memory
    assert_instance_of Taskchampion::Replica, replica
  end

  def test_new_on_disk_creates_directory
    path = temp_path("taskdb")
    refute File.exist?(path)

    replica = Taskchampion::Replica.new_on_disk(path, true, nil)
    assert_instance_of Taskchampion::Replica, replica
    assert File.directory?(path)
  end

  def test_new_on_disk_with_access_mode
    path = temp_path("taskdb")

    # Test with read_write mode
    replica = Taskchampion::Replica.new_on_disk(path, true, :read_write)
    assert_instance_of Taskchampion::Replica, replica

    # Test with read_only mode
    replica2 = Taskchampion::Replica.new_on_disk(path, false, :read_only)
    assert_instance_of Taskchampion::Replica, replica2
  end

  def test_error_classes_exist
    assert_kind_of Class, Taskchampion::Error
    assert_kind_of Class, Taskchampion::ThreadError
    assert_kind_of Class, Taskchampion::StorageError
    assert_kind_of Class, Taskchampion::ValidationError
    assert_kind_of Class, Taskchampion::ConfigError
  end

  def test_access_mode_constants
    assert_equal :read_only, Taskchampion::READ_ONLY
    assert_equal :read_write, Taskchampion::READ_WRITE
  end
end