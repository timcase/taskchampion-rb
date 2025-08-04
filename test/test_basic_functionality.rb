require 'test_helper'

class TestBasicFunctionality < Minitest::Test
  def test_replica_creation
    replica = Taskchampion::Replica.new_in_memory
    refute_nil replica
  end

  def test_thread_safety_enforcement
    replica = Taskchampion::Replica.new_in_memory

    thread_error_raised = false
    Thread.new do
      begin
        replica.task_uuids # Should raise ThreadError
      rescue Taskchampion::ThreadError
        thread_error_raised = true
      end
    end.join

    assert thread_error_raised, "ThreadError should be raised on cross-thread access"
  end

  def test_basic_task_operations
    replica = Taskchampion::Replica.new_in_memory
    operations = Taskchampion::Operations.new

    # Basic task creation and retrieval
    uuid = SecureRandom.uuid
    task = replica.create_task(uuid, operations)
    refute_nil task

    # Commit the operations to persist the task
    replica.commit_operations(operations)

    # Verify task can be retrieved
    retrieved = replica.task(uuid)
    refute_nil retrieved
  end
end