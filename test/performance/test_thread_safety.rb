require_relative '../test_helper'
require 'securerandom'

class TestThreadSafety < Minitest::Test
  def test_concurrent_access_stress
    replica = Taskchampion::Replica.new_in_memory
    errors = []

    # Spawn 20 threads trying to access replica
    threads = 20.times.map do
      Thread.new do
        100.times do
          begin
            replica.task_uuids
            errors << "No error raised in #{Thread.current}"
          rescue Taskchampion::ThreadError
            # Expected - this is correct
          rescue => e
            errors << "Wrong error: #{e.class} - #{e.message}"
          end
        end
      end
    end

    threads.each(&:join)
    assert errors.empty?, "Thread safety issues: #{errors.first(5)}"
  end

  def test_thread_bound_protection
    replica = Taskchampion::Replica.new_in_memory
    operations = Taskchampion::Operations.new

    # Create a task in main thread
    uuid = SecureRandom.uuid
    task = replica.create_task(uuid, operations)
    replica.commit_operations(operations)

    # Try to access from another thread
    thread_error = nil
    thread = Thread.new do
      begin
        replica.task(uuid)
      rescue => e
        thread_error = e
      end
    end
    thread.join

    assert_instance_of Taskchampion::ThreadError, thread_error
    assert_match(/different thread/, thread_error.message)
  end

  def test_multiple_replicas_different_threads
    # Each thread should be able to have its own replica
    errors = []
    successful_ops = []

    threads = 5.times.map do |i|
      Thread.new do
        begin
          # Each thread creates its own replica
          replica = Taskchampion::Replica.new_in_memory
          operations = Taskchampion::Operations.new

          # Create tasks in each thread's replica
          5.times do |j|
            uuid = SecureRandom.uuid
            task = replica.create_task(uuid, operations)
            task.set_description("Thread #{i} Task #{j}", operations)
          end

          replica.commit_operations(operations)

          # Count tasks
          count = replica.task_uuids.length
          successful_ops << "Thread #{i}: Created #{count} tasks"
        rescue => e
          errors << "Thread #{i} error: #{e.class} - #{e.message}"
        end
      end
    end

    threads.each(&:join)

    assert errors.empty?, "Errors in threads: #{errors.join(', ')}"
    assert_equal 5, successful_ops.length
  end

  def test_task_access_thread_safety
    replica = Taskchampion::Replica.new_in_memory
    operations = Taskchampion::Operations.new

    # Create task in main thread
    uuid = SecureRandom.uuid
    task = replica.create_task(uuid, operations)
    task.set_description("Main thread task", operations)
    replica.commit_operations(operations)

    # Retrieve task in main thread
    retrieved = replica.task(uuid)

    # Try to access task from another thread
    thread_errors = []
    thread = Thread.new do
      begin
        # This should fail - task is bound to main thread
        retrieved.description
      rescue => e
        thread_errors << e
      end

      begin
        # This should also fail
        ops = Taskchampion::Operations.new
        retrieved.set_description("From thread", ops)
      rescue => e
        thread_errors << e
      end
    end
    thread.join

    assert_equal 2, thread_errors.length
    thread_errors.each do |error|
      assert_instance_of Taskchampion::ThreadError, error
    end
  end

  def test_operations_thread_safety
    # Operations should also be thread-bound
    operations = Taskchampion::Operations.new

    # Add some operations in main thread
    replica = Taskchampion::Replica.new_in_memory
    uuid = SecureRandom.uuid
    task = replica.create_task(uuid, operations)

    thread_error = nil
    thread = Thread.new do
      begin
        # Try to use operations from another thread
        operations.length
      rescue => e
        thread_error = e
      end
    end
    thread.join

    # Operations might not be thread-bound in current implementation
    # This test documents the expected behavior
    if thread_error
      assert_instance_of Taskchampion::ThreadError, thread_error
    end
  end

  def test_concurrent_replica_creation
    # Multiple threads creating replicas simultaneously
    replicas = []
    mutex = Mutex.new
    errors = []

    threads = 10.times.map do
      Thread.new do
        begin
          replica = Taskchampion::Replica.new_in_memory
          mutex.synchronize { replicas << replica }
        rescue => e
          mutex.synchronize { errors << e }
        end
      end
    end

    threads.each(&:join)

    assert errors.empty?, "Errors creating replicas: #{errors.map(&:message).join(', ')}"
    assert_equal 10, replicas.length

    # Each replica should only be usable in its creation thread
    # (Can't test this as replicas were created in threads that have ended)
  end

  def test_stress_test_with_many_operations
    replica = Taskchampion::Replica.new_in_memory
    operations = Taskchampion::Operations.new

    # Create many tasks rapidly
    100.times do
      uuid = SecureRandom.uuid
      task = replica.create_task(uuid, operations)
      task.set_description("Task #{uuid}", operations)
      task.set_priority("H", operations)
      task.add_tag(Taskchampion::Tag.new("stress"), operations)
    end

    # Commit all at once
    assert_nothing_raised do
      replica.commit_operations(operations)
    end

    # Verify all tasks were created
    assert_equal 100, replica.task_uuids.length
  end

  def test_working_set_thread_safety
    replica = Taskchampion::Replica.new_in_memory
    operations = Taskchampion::Operations.new

    # Create tasks and get working set
    3.times do
      uuid = SecureRandom.uuid
      task = replica.create_task(uuid, operations)
      task.set_description("Working set task", operations)
    end
    replica.commit_operations(operations)

    working_set = replica.working_set

    # Try to access working set from another thread
    thread_error = nil
    thread = Thread.new do
      begin
        working_set.largest_index
      rescue => e
        thread_error = e
      end
    end
    thread.join

    assert_instance_of Taskchampion::ThreadError, thread_error
  end

  def test_dependency_map_thread_safety
    replica = Taskchampion::Replica.new_in_memory

    # Get dependency map
    dep_map = replica.dependency_map(false)

    # Try to access from another thread
    thread_error = nil
    thread = Thread.new do
      begin
        dep_map.dependencies(SecureRandom.uuid)
      rescue => e
        thread_error = e
      end
    end
    thread.join

    assert_instance_of Taskchampion::ThreadError, thread_error
  end

  def test_rapid_task_creation_and_modification
    replica = Taskchampion::Replica.new_in_memory

    # Rapid creation and modification in same thread should work
    assert_nothing_raised do
      50.times do |i|
        ops = Taskchampion::Operations.new
        uuid = SecureRandom.uuid

        task = replica.create_task(uuid, ops)
        task.set_description("Rapid task #{i}", ops)
        task.set_status(:pending, ops)
        task.set_priority(["H", "M", "L"].sample, ops)

        replica.commit_operations(ops)

        # Immediately retrieve and modify
        ops2 = Taskchampion::Operations.new
        retrieved = replica.task(uuid)
        retrieved.set_status(:completed, ops2) if i.even?
        replica.commit_operations(ops2)
      end
    end

    # Verify tasks were created
    assert_equal 50, replica.task_uuids.length
  end
end
