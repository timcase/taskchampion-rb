# frozen_string_literal: true

require "test_helper"

class TestTaskData < TaskchampionTest
  def test_task_data_create
    replica = Taskchampion::Replica.new_in_memory
    operations = Taskchampion::Operations.new
    uuid = SecureRandom.uuid

    task_data = Taskchampion::TaskData.create(uuid, operations)

    assert_instance_of Taskchampion::TaskData, task_data
    assert_equal uuid, task_data.uuid
  end

  def test_task_data_update
    replica = Taskchampion::Replica.new_in_memory
    operations = Taskchampion::Operations.new
    uuid = SecureRandom.uuid

    task_data = Taskchampion::TaskData.create(uuid, operations)

    # Update a property
    task_data.update("description", "Test task", operations)

    # Commit operations and retrieve from replica
    replica.commit_operations(operations)
    retrieved_task_data = replica.task_data(uuid)

    refute_nil retrieved_task_data
    assert_equal "Test task", retrieved_task_data.get("description")
  end

  def test_task_data_delete
    replica = Taskchampion::Replica.new_in_memory
    operations = Taskchampion::Operations.new
    uuid = SecureRandom.uuid

    # Create a task
    task_data = Taskchampion::TaskData.create(uuid, operations)
    task_data.update("description", "Task to delete", operations)
    replica.commit_operations(operations)

    # Verify task exists
    retrieved = replica.task_data(uuid)
    refute_nil retrieved
    assert_equal "Task to delete", retrieved.get("description")

    # Delete the task
    delete_operations = Taskchampion::Operations.new
    retrieved.delete(delete_operations)
    replica.commit_operations(delete_operations)

    # Verify task no longer exists
    deleted_task = replica.task_data(uuid)
    assert_nil deleted_task
  end

  def test_task_data_properties
    replica = Taskchampion::Replica.new_in_memory
    operations = Taskchampion::Operations.new
    uuid = SecureRandom.uuid

    task_data = Taskchampion::TaskData.create(uuid, operations)
    task_data.update("description", "Test task", operations)
    task_data.update("status", "pending", operations)
    task_data.update("priority", "high", operations)

    replica.commit_operations(operations)
    retrieved = replica.task_data(uuid)

    # Test properties method
    properties = retrieved.properties
    assert_instance_of Array, properties
    assert_includes properties, "description"
    assert_includes properties, "status"
    assert_includes properties, "priority"

    # Test has? method
    assert retrieved.has?("description")
    assert retrieved.has?("status")
    assert retrieved.has?("priority")
    refute retrieved.has?("nonexistent")

    # Test to_hash method
    hash = retrieved.to_hash
    assert_instance_of Hash, hash
    assert_equal "Test task", hash["description"]
    assert_equal "pending", hash["status"]
    assert_equal "high", hash["priority"]
  end

  def test_task_data_get_with_nonexistent_property
    replica = Taskchampion::Replica.new_in_memory
    operations = Taskchampion::Operations.new
    uuid = SecureRandom.uuid

    task_data = Taskchampion::TaskData.create(uuid, operations)
    replica.commit_operations(operations)
    retrieved = replica.task_data(uuid)

    # Getting nonexistent property should return nil
    assert_nil retrieved.get("nonexistent")
  end

  def test_task_data_update_with_nil_removes_property
    replica = Taskchampion::Replica.new_in_memory
    operations = Taskchampion::Operations.new
    uuid = SecureRandom.uuid

    task_data = Taskchampion::TaskData.create(uuid, operations)
    task_data.update("description", "Initial value", operations)
    replica.commit_operations(operations)

    # Verify property exists
    retrieved = replica.task_data(uuid)
    assert_equal "Initial value", retrieved.get("description")
    assert retrieved.has?("description")

    # Remove property by setting to nil
    remove_operations = Taskchampion::Operations.new
    retrieved.update("description", nil, remove_operations)
    replica.commit_operations(remove_operations)

    # Verify property is removed
    updated = replica.task_data(uuid)
    assert_nil updated.get("description")
    refute updated.has?("description")
  end

  def test_task_data_inspect
    replica = Taskchampion::Replica.new_in_memory
    operations = Taskchampion::Operations.new
    uuid = SecureRandom.uuid

    task_data = Taskchampion::TaskData.create(uuid, operations)

    inspect_string = task_data.inspect
    assert_match(/Taskchampion::TaskData/, inspect_string)
    assert_match(/#{uuid}/, inspect_string)
  end
end
