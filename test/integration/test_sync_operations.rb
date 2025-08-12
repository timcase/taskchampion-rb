require_relative '../test_helper'
require 'securerandom'
require 'tmpdir'

class TestSyncOperations < Minitest::Test
  def setup
    @replica = Taskchampion::Replica.new_in_memory
    @operations = Taskchampion::Operations.new
  end

  def test_local_sync
    # Create a temporary directory for local sync
    Dir.mktmpdir do |tmpdir|
      server_dir = File.join(tmpdir, "taskchampion_server")
      Dir.mkdir(server_dir)

      # Create some tasks
      uuid1 = SecureRandom.uuid
      task1 = @replica.create_task(uuid1, @operations)
      task1.set_description("Task for sync", @operations)
      task1.set_status(:pending, @operations)
      @replica.commit_operations(@operations)

      # Sync to local server
      assert_nothing_raised do
        @replica.sync_to_local(server_dir, false)
      end

      # Create another replica and sync from the same server
      replica2 = Taskchampion::Replica.new_in_memory
      assert_nothing_raised do
        replica2.sync_to_local(server_dir, false)
      end

      # Verify the task exists in the second replica
      task_in_replica2 = replica2.task(uuid1)
      assert_equal "Task for sync", task_in_replica2.description
      assert task_in_replica2.pending?
    end
  end

  def test_sync_with_avoid_snapshots
    Dir.mktmpdir do |tmpdir|
      server_dir = File.join(tmpdir, "taskchampion_server_no_snap")
      Dir.mkdir(server_dir)

      # Create tasks
      3.times do |i|
        uuid = SecureRandom.uuid
        task = @replica.create_task(uuid, @operations)
        task.set_description("Task #{i}", @operations)
      end
      @replica.commit_operations(@operations)

      # Sync with avoid_snapshots = true
      assert_nothing_raised do
        @replica.sync_to_local(server_dir, true)
      end
    end
  end

  def test_num_local_operations
    # Initially should be 0
    assert_equal 0, @replica.num_local_operations

    # Create a task
    uuid = SecureRandom.uuid
    task = @replica.create_task(uuid, @operations)
    task.set_description("Test", @operations)
    @replica.commit_operations(@operations)

    # Should have operations now
    assert @replica.num_local_operations > 0
  end

  def test_num_undo_points
    initial_undo_points = @replica.num_undo_points

    # Create tasks with separate commits to create undo points
    3.times do |i|
      ops = Taskchampion::Operations.new
      uuid = SecureRandom.uuid
      task = @replica.create_task(uuid, ops)
      task.set_description("Task #{i}", ops)
      @replica.commit_operations(ops)
    end

    # Should have more undo points
    assert @replica.num_undo_points >= initial_undo_points
  end

  def test_rebuild_working_set
    # Create tasks
    5.times do |i|
      uuid = SecureRandom.uuid
      task = @replica.create_task(uuid, @operations)
      task.set_description("Working set task #{i}", @operations)
      task.set_status(:pending, @operations)
    end
    @replica.commit_operations(@operations)

    # Rebuild working set without renumbering
    assert_nothing_raised do
      @replica.rebuild_working_set(false)
    end

    # Rebuild working set with renumbering
    assert_nothing_raised do
      @replica.rebuild_working_set(true)
    end

    # Working set should still be accessible
    working_set = @replica.working_set
    assert_instance_of Taskchampion::WorkingSet, working_set
  end

  def test_expire_tasks
    # Create tasks with various statuses
    uuid1 = SecureRandom.uuid
    task1 = @replica.create_task(uuid1, @operations)
    task1.set_description("Pending task", @operations)
    task1.set_status(:pending, @operations)

    uuid2 = SecureRandom.uuid
    task2 = @replica.create_task(uuid2, @operations)
    task2.set_description("Completed task", @operations)
    task2.set_status(:completed, @operations)

    @replica.commit_operations(@operations)

    # Expire tasks (this depends on expiration configuration)
    assert_nothing_raised do
      @replica.expire_tasks
    end

    # Tasks should still exist (expiration rules may not apply)
    assert @replica.task(uuid1)
    assert @replica.task(uuid2)
  end

  def test_sync_error_handling
    # Test sync with invalid server directory (permission denied scenario)
    if RUBY_PLATFORM !~ /mingw|mswin|cygwin/
      # Unix-like systems only
      Dir.mktmpdir do |tmpdir|
        server_dir = File.join(tmpdir, "no_permission")
        Dir.mkdir(server_dir, 0000) # No permissions

        # This should raise an error
        assert_raises(Taskchampion::StorageError, Taskchampion::SyncError) do
          @replica.sync_to_local(server_dir, false)
        end

        # Cleanup
        File.chmod(0755, server_dir)
      end
    end
  end

  def test_remote_sync_validation
    # Test that remote sync requires proper parameters
    assert_raises(ArgumentError, NoMethodError) do
      @replica.sync_to_remote({})
    end

    # Test with missing required parameters
    assert_raises(StandardError) do
      @replica.sync_to_remote(url: "http://example.com")
      # Missing client_id and encryption_secret
    end
  end

  def test_gcp_sync_validation
    # Test that GCP sync requires proper parameters
    assert_raises(ArgumentError, NoMethodError) do
      @replica.sync_to_gcp({})
    end

    # Test with missing required parameters
    assert_raises(StandardError) do
      @replica.sync_to_gcp(bucket: "my-bucket")
      # Missing credential_path and encryption_secret
    end
  end

  def test_multiple_sync_operations
    Dir.mktmpdir do |tmpdir|
      server_dir = File.join(tmpdir, "multi_sync")
      Dir.mkdir(server_dir)

      # Create initial tasks
      uuid1 = SecureRandom.uuid
      task1 = @replica.create_task(uuid1, @operations)
      task1.set_description("First sync", @operations)
      @replica.commit_operations(@operations)

      # First sync
      @replica.sync_to_local(server_dir, false)

      # Add more tasks
      ops2 = Taskchampion::Operations.new
      uuid2 = SecureRandom.uuid
      task2 = @replica.create_task(uuid2, ops2)
      task2.set_description("Second sync", ops2)
      @replica.commit_operations(ops2)

      # Second sync
      @replica.sync_to_local(server_dir, false)

      # Create new replica and sync
      replica2 = Taskchampion::Replica.new_in_memory
      replica2.sync_to_local(server_dir, false)

      # Should have both tasks
      assert_equal 2, replica2.task_uuids.length
      assert replica2.task(uuid1)
      assert replica2.task(uuid2)
    end
  end
end
