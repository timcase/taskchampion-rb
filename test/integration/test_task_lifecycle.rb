require_relative '../test_helper'
require 'securerandom'

class TestTaskLifecycle < Minitest::Test
  def setup
    @replica = Taskchampion::Replica.new_in_memory
    @operations = Taskchampion::Operations.new
  end

  def test_complete_task_workflow
    # Create task
    uuid = SecureRandom.uuid
    task = @replica.create_task(uuid, @operations)

    assert_instance_of Taskchampion::Task, task
    assert_equal uuid, task.uuid

    # Modify task
    task.set_description("Buy groceries", @operations)
    task.set_status(:pending, @operations)
    task.add_tag(Taskchampion::Tag.new("shopping"), @operations)
    task.set_priority("H", @operations)

    # Set due date
    due_date = Time.now + 86400 # Tomorrow
    task.set_due(due_date, @operations)

    # Add annotation
    task.add_annotation("Remember to buy milk", @operations)

    # Set UDA
    task.set_uda("project", "name", "home", @operations)

    # Commit changes
    @replica.commit_operations(@operations)

    # Retrieve and verify task
    retrieved = @replica.task(uuid)
    assert_equal "Buy groceries", retrieved.description
    assert retrieved.pending?
    assert_equal "H", retrieved.priority
    assert retrieved.has_tag?(Taskchampion::Tag.new("shopping"))

    # Verify UDA
    uda_value = retrieved.get_uda("project", "name")
    assert_equal "home", uda_value

    # Complete the task
    operations2 = Taskchampion::Operations.new
    retrieved.set_status(:completed, operations2)
    @replica.commit_operations(operations2)

    # Verify completion
    final_task = @replica.task(uuid)
    assert final_task.completed?
    refute final_task.pending?
  end

  def test_task_creation_and_retrieval
    uuid = SecureRandom.uuid
    task = @replica.create_task(uuid, @operations)
    @replica.commit_operations(@operations)

    # Retrieve by UUID
    retrieved = @replica.task(uuid)
    assert_equal uuid, retrieved.uuid

    # Check in all tasks
    all_tasks = @replica.all_tasks
    assert_instance_of Hash, all_tasks
    assert all_tasks.key?(uuid)

    # Check in UUID list
    uuids = @replica.task_uuids
    assert_includes uuids, uuid
  end

  def test_task_modification_workflow
    uuid = SecureRandom.uuid
    task = @replica.create_task(uuid, @operations)
    task.set_description("Initial description", @operations)
    @replica.commit_operations(@operations)

    # Modify the task
    ops2 = Taskchampion::Operations.new
    retrieved = @replica.task(uuid)
    retrieved.set_description("Updated description", ops2)
    retrieved.set_priority("L", ops2)
    @replica.commit_operations(ops2)

    # Verify modifications
    final = @replica.task(uuid)
    assert_equal "Updated description", final.description
    assert_equal "L", final.priority
  end

  def test_task_tags_management
    uuid = SecureRandom.uuid
    task = @replica.create_task(uuid, @operations)

    # Add multiple tags
    tag1 = Taskchampion::Tag.new("work")
    tag2 = Taskchampion::Tag.new("urgent")
    task.add_tag(tag1, @operations)
    task.add_tag(tag2, @operations)
    @replica.commit_operations(@operations)

    # Verify tags
    retrieved = @replica.task(uuid)
    assert retrieved.has_tag?(tag1)
    assert retrieved.has_tag?(tag2)
    tags = retrieved.tags
    user_tags = tags.select(&:user?)
    assert_equal 2, user_tags.length

    # Remove a tag
    ops2 = Taskchampion::Operations.new
    retrieved.remove_tag(tag1, ops2)
    @replica.commit_operations(ops2)

    # Verify tag removal
    final = @replica.task(uuid)
    refute final.has_tag?(tag1)
    assert final.has_tag?(tag2)
  end

  def test_task_annotations
    uuid = SecureRandom.uuid
    task = @replica.create_task(uuid, @operations)

    # Add annotations
    task.add_annotation("First note", @operations)
    task.add_annotation("Second note", @operations)
    @replica.commit_operations(@operations)

    # Verify annotations
    retrieved = @replica.task(uuid)
    annotations = retrieved.annotations
    assert_equal 2, annotations.length

    # Annotations should have descriptions
    descriptions = annotations.map(&:description)
    assert_includes descriptions, "First note"
    assert_includes descriptions, "Second note"
  end

  def test_task_status_transitions
    uuid = SecureRandom.uuid
    task = @replica.create_task(uuid, @operations)
    task.set_status(:pending, @operations)
    @replica.commit_operations(@operations)

    retrieved = @replica.task(uuid)
    assert retrieved.pending?
    refute retrieved.completed?
    refute retrieved.deleted?

    # Complete the task
    ops2 = Taskchampion::Operations.new
    retrieved.set_status(:completed, ops2)
    @replica.commit_operations(ops2)

    completed = @replica.task(uuid)
    assert completed.completed?
    refute completed.pending?

    # Delete the task
    ops3 = Taskchampion::Operations.new
    completed.set_status(:deleted, ops3)
    @replica.commit_operations(ops3)

    deleted = @replica.task(uuid)
    assert deleted.deleted?
    refute deleted.completed?
    refute deleted.pending?
  end

  def test_done_method
    uuid = SecureRandom.uuid
    task = @replica.create_task(uuid, @operations)
    task.set_description("Task to complete", @operations)
    task.set_status(:pending, @operations)
    @replica.commit_operations(@operations)

    # Verify task is pending
    retrieved = @replica.task(uuid)
    assert retrieved.pending?
    refute retrieved.completed?

    # Mark task as done using the done method
    ops2 = Taskchampion::Operations.new
    retrieved.done(ops2)
    @replica.commit_operations(ops2)

    # Verify task is completed
    completed_task = @replica.task(uuid)
    assert completed_task.completed?
    refute completed_task.pending?
    assert_equal :completed, completed_task.status
  end

  def test_task_with_dependencies
    # Create parent task
    parent_uuid = SecureRandom.uuid
    parent = @replica.create_task(parent_uuid, @operations)
    parent.set_description("Parent task", @operations)

    # Create child task
    child_uuid = SecureRandom.uuid
    child = @replica.create_task(child_uuid, @operations)
    child.set_description("Child task", @operations)

    @replica.commit_operations(@operations)

    # Dependencies would be set through task methods
    # This is a placeholder for when dependency methods are implemented
    assert_instance_of Taskchampion::Task, parent
    assert_instance_of Taskchampion::Task, child
  end

  def test_task_ruby_style_setters
    uuid = SecureRandom.uuid
    task = @replica.create_task(uuid, @operations)

    # Use standard setter methods (Ruby-style setters removed for API consistency)
    task.set_description("Ruby style description", @operations)
    task.set_status(:pending, @operations)
    task.set_priority("M", @operations)

    @replica.commit_operations(@operations)

    # Verify the setters worked
    retrieved = @replica.task(uuid)
    assert_equal "Ruby style description", retrieved.description
    assert retrieved.pending?
    assert_equal "M", retrieved.priority
  end

  def test_operations_collection_behavior
    ops = Taskchampion::Operations.new

    uuid = SecureRandom.uuid
    task = @replica.create_task(uuid, ops)
    task.set_description("Test", ops)

    # Operations should accumulate
    assert ops.length > 0
    refute ops.empty?

    # Can iterate operations
    count = 0
    ops.each { |op| count += 1 }
    assert count > 0

    # Can clear operations
    ops.clear
    assert_equal 0, ops.length
    assert ops.empty?
  end
end
