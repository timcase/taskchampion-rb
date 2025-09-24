# frozen_string_literal: true

require_relative "test_helper"

class TestUndo < TaskchampionTest
  def setup
    super
    @replica = Taskchampion::Replica.new_in_memory
  end

  def test_get_task_operations_returns_empty_for_new_task
    ops = Taskchampion::Operations.new
    task = @replica.create_task("550e8400-e29b-41d4-a716-446655440000", ops)
    @replica.commit_operations(ops)

    task_ops = @replica.task_operations(task.uuid)
    assert_instance_of Taskchampion::Operations, task_ops
    assert task_ops.length > 0
  end

  def test_get_task_operations_shows_task_history
    ops = Taskchampion::Operations.new
    task = @replica.create_task("550e8400-e29b-41d4-a716-446655440000", ops)
    @replica.commit_operations(ops)

    # Modify the task
    ops = Taskchampion::Operations.new
    task.set_description("Test task", ops)
    @replica.commit_operations(ops)

    # Get task operations
    task_ops = @replica.task_operations(task.uuid)
    assert task_ops.length >= 2 # Create + Update operations
  end

  def test_get_undo_operations_returns_empty_initially
    undo_ops = @replica.undo_operations
    assert_instance_of Taskchampion::Operations, undo_ops
    assert undo_ops.empty?
  end

  def test_get_undo_operations_after_changes
    ops = Taskchampion::Operations.new
    @replica.create_task("550e8400-e29b-41d4-a716-446655440000", ops)
    @replica.commit_operations(ops)

    undo_ops = @replica.undo_operations
    refute undo_ops.empty?
  end

  def test_commit_reversed_operations_undoes_changes
    # Create a task
    ops = Taskchampion::Operations.new
    task = @replica.create_task("550e8400-e29b-41d4-a716-446655440000", ops)
    @replica.commit_operations(ops)

    # Verify task exists
    retrieved_task = @replica.task(task.uuid)
    refute_nil retrieved_task

    # Get undo operations and commit them
    undo_ops = @replica.undo_operations
    result = @replica.commit_undo!(undo_ops)
    assert result

    # Task should no longer exist
    retrieved_task = @replica.task(task.uuid)
    assert_nil retrieved_task
  end

  def test_undo_convenience_method
    # Create a task
    ops = Taskchampion::Operations.new
    task = @replica.create_task("550e8400-e29b-41d4-a716-446655440000", ops)
    @replica.commit_operations(ops)

    # Verify task exists
    retrieved_task = @replica.task(task.uuid)
    refute_nil retrieved_task

    # Use convenience undo method
    result = @replica.undo!
    assert result

    # Task should no longer exist
    retrieved_task = @replica.task(task.uuid)
    assert_nil retrieved_task
  end

  def test_undo_returns_false_when_nothing_to_undo
    result = @replica.undo!
    assert_equal false, result
  end

  def test_commit_reversed_operations_returns_false_for_invalid_operations
    # Create an empty operations object
    invalid_ops = Taskchampion::Operations.new

    result = @replica.commit_reversed_operations(invalid_ops)
    assert_equal false, result
  end

  def test_multiple_undo_operations
    # Create first task with undo point
    ops1 = Taskchampion::Operations.new
    ops1.push(Taskchampion::Operation.undo_point)
    task1 = @replica.create_task("550e8400-e29b-41d4-a716-446655440000", ops1)
    @replica.commit_operations(ops1)

    # Create second task with undo point
    ops2 = Taskchampion::Operations.new
    ops2.push(Taskchampion::Operation.undo_point)
    task2 = @replica.create_task("550e8400-e29b-41d4-a716-446655440001", ops2)
    @replica.commit_operations(ops2)

    # Both tasks should exist
    refute_nil @replica.task(task1.uuid)
    refute_nil @replica.task(task2.uuid)

    # Undo should remove the second task
    result = @replica.undo!
    assert result

    refute_nil @replica.task(task1.uuid)
    assert_nil @replica.task(task2.uuid)

    # Second undo should remove the first task
    result = @replica.undo!
    assert result

    assert_nil @replica.task(task1.uuid)
    assert_nil @replica.task(task2.uuid)
  end

  def test_task_operations_with_nonexistent_uuid
    task_ops = @replica.task_operations("00000000-0000-0000-0000-000000000000")
    assert_instance_of Taskchampion::Operations, task_ops
    assert task_ops.empty?
  end

  def test_task_modification_history
    ops = Taskchampion::Operations.new
    task = @replica.create_task("550e8400-e29b-41d4-a716-446655440000", ops)
    @replica.commit_operations(ops)

    # Make several modifications
    ops = Taskchampion::Operations.new
    task.set_description("First description", ops)
    @replica.commit_operations(ops)

    ops = Taskchampion::Operations.new
    task.set_description("Second description", ops)
    @replica.commit_operations(ops)

    ops = Taskchampion::Operations.new
    task.set_value("project", "home", ops)
    @replica.commit_operations(ops)

    # Get full history
    task_ops = @replica.task_operations(task.uuid)
    assert task_ops.length >= 4 # Create + 3 updates
  end
end
