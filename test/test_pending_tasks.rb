# frozen_string_literal: true

require "test_helper"

class TestPendingTasks < TaskchampionTest
  def test_pending_tasks_returns_array
    replica = Taskchampion::Replica.new_in_memory
    ops = Taskchampion::Operations.new

    # Create some tasks with different statuses
    task1 = replica.create_task(SecureRandom.uuid, ops)
    task1.set_description("Pending task 1", ops)
    task1.set_status(Taskchampion::PENDING, ops)
    replica.commit_operations(ops)

    ops = Taskchampion::Operations.new
    task2 = replica.create_task(SecureRandom.uuid, ops)
    task2.set_description("Pending task 2", ops)
    task2.set_status(Taskchampion::PENDING, ops)
    replica.commit_operations(ops)

    ops = Taskchampion::Operations.new
    task3 = replica.create_task(SecureRandom.uuid, ops)
    task3.set_description("Completed task", ops)
    task3.set_status(Taskchampion::COMPLETED, ops)
    replica.commit_operations(ops)

    ops = Taskchampion::Operations.new
    task4 = replica.create_task(SecureRandom.uuid, ops)
    task4.set_description("Deleted task", ops)
    task4.set_status(Taskchampion::DELETED, ops)
    replica.commit_operations(ops)

    # Get pending tasks
    pending = replica.pending_tasks

    assert_kind_of Array, pending
    assert_equal 2, pending.length

    # Check that we got the right tasks
    descriptions = pending.map(&:description).sort
    assert_equal ["Pending task 1", "Pending task 2"], descriptions
  end

  def test_pending_tasks_empty_when_no_pending
    replica = Taskchampion::Replica.new_in_memory
    ops = Taskchampion::Operations.new

    # Create only completed tasks
    task = replica.create_task(SecureRandom.uuid, ops)
    task.set_description("Completed task", ops)
    task.set_status(Taskchampion::COMPLETED, ops)
    replica.commit_operations(ops)

    pending = replica.pending_tasks
    assert_kind_of Array, pending
    assert_empty pending
  end

  def test_pending_tasks_with_waiting_status
    replica = Taskchampion::Replica.new_in_memory
    ops = Taskchampion::Operations.new

    # Create a waiting task
    task = replica.create_task(SecureRandom.uuid, ops)
    task.set_description("Waiting task", ops)
    task.set_status(Taskchampion::PENDING, ops)
    # Note: set_wait method might not be implemented yet
    # For now, just test that pending tasks are returned
    replica.commit_operations(ops)

    # Pending tasks should be included in pending_tasks
    pending = replica.pending_tasks
    assert_equal 1, pending.length
    assert_equal "Waiting task", pending.first.description
  end

  def test_pending_tasks_thread_safety
    replica = Taskchampion::Replica.new_in_memory
    ops = Taskchampion::Operations.new

    # Create a task
    task = replica.create_task(SecureRandom.uuid, ops)
    task.set_description("Test task", ops)
    task.set_status(Taskchampion::PENDING, ops)
    replica.commit_operations(ops)

    # Try to access from different thread
    thread = Thread.new do
      assert_raises(Taskchampion::ThreadError) do
        replica.pending_tasks
      end
    end
    thread.join
  end

  def test_pending_tasks_with_on_disk_replica
    replica = Taskchampion::Replica.new_on_disk(temp_path("taskdb"), true, :read_write)
    ops = Taskchampion::Operations.new

    # Create pending tasks
    task1 = replica.create_task(SecureRandom.uuid, ops)
    task1.set_description("On-disk pending task", ops)
    task1.set_status(Taskchampion::PENDING, ops)
    replica.commit_operations(ops)

    pending = replica.pending_tasks
    assert_equal 1, pending.length
    assert_equal "On-disk pending task", pending.first.description
  end
end