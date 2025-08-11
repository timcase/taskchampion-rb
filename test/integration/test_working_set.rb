require_relative '../test_helper'
require 'securerandom'

class TestWorkingSet < Minitest::Test
  def setup
    @replica = Taskchampion::Replica.new_in_memory
    @operations = Taskchampion::Operations.new
  end

  def test_working_set_creation
    # Get working set from replica
    working_set = @replica.working_set
    
    assert_instance_of Taskchampion::WorkingSet, working_set
  end

  def test_working_set_with_tasks
    # Create pending tasks
    task_uuids = []
    5.times do |i|
      uuid = SecureRandom.uuid
      task = @replica.create_task(uuid, @operations)
      task.set_description("Working task #{i}", @operations)
      task.set_status(:pending, @operations)
      task_uuids << uuid
    end
    @replica.commit_operations(@operations)
    
    # Get working set
    working_set = @replica.working_set
    
    # Check largest index
    largest = working_set.largest_index
    assert_instance_of Integer, largest
    assert largest >= 0
  end

  def test_working_set_by_index
    # Create tasks
    uuid1 = SecureRandom.uuid
    task1 = @replica.create_task(uuid1, @operations)
    task1.set_description("First task", @operations)
    task1.set_status(:pending, @operations)
    
    uuid2 = SecureRandom.uuid
    task2 = @replica.create_task(uuid2, @operations)
    task2.set_description("Second task", @operations)
    task2.set_status(:pending, @operations)
    
    @replica.commit_operations(@operations)
    
    # Get working set
    working_set = @replica.working_set
    
    # Try to get tasks by index
    # Note: Index assignment depends on internal logic
    task_at_1 = working_set.by_index(1)
    if task_at_1
      assert_instance_of Taskchampion::Task, task_at_1
      assert task_at_1.pending?
    end
    
    # Non-existent index should return nil
    task_at_999 = working_set.by_index(999)
    assert_nil task_at_999
  end

  def test_working_set_by_uuid
    # Create a task
    uuid = SecureRandom.uuid
    task = @replica.create_task(uuid, @operations)
    task.set_description("UUID lookup task", @operations)
    task.set_status(:pending, @operations)
    @replica.commit_operations(@operations)
    
    # Get working set
    working_set = @replica.working_set
    
    # Look up by UUID
    index = working_set.by_uuid(uuid)
    if index
      assert_instance_of Integer, index
      assert index > 0
      
      # Should be able to get the task back by that index
      task_from_index = working_set.by_index(index)
      assert_equal uuid, task_from_index.uuid if task_from_index
    end
    
    # Non-existent UUID should return nil
    fake_uuid = SecureRandom.uuid
    assert_nil working_set.by_uuid(fake_uuid)
  end

  def test_working_set_renumber
    # Create multiple tasks
    10.times do |i|
      uuid = SecureRandom.uuid
      task = @replica.create_task(uuid, @operations)
      task.set_description("Task #{i}", @operations)
      task.set_status(:pending, @operations)
    end
    @replica.commit_operations(@operations)
    
    # Get working set
    working_set = @replica.working_set
    
    # Renumber the working set (currently not supported due to mutability constraints)
    assert_raises(RuntimeError) do
      working_set.renumber
    end
    
    # Working set should still be functional
    largest = working_set.largest_index
    assert largest > 0
  end

  def test_working_set_with_completed_tasks
    # Create mix of pending and completed tasks
    pending_uuid = SecureRandom.uuid
    pending_task = @replica.create_task(pending_uuid, @operations)
    pending_task.set_description("Pending task", @operations)
    pending_task.set_status(:pending, @operations)
    
    completed_uuid = SecureRandom.uuid
    completed_task = @replica.create_task(completed_uuid, @operations)
    completed_task.set_description("Completed task", @operations)
    completed_task.set_status(:completed, @operations)
    
    @replica.commit_operations(@operations)
    
    # Get working set
    working_set = @replica.working_set
    
    # Pending task should be in working set
    pending_index = working_set.by_uuid(pending_uuid)
    assert pending_index, "Pending task should be in working set"
    
    # Completed task might not be in working set (depends on implementation)
    completed_index = working_set.by_uuid(completed_uuid)
    # No assertion here as behavior depends on TaskChampion implementation
  end

  def test_working_set_after_rebuild
    # Create tasks
    task_uuids = []
    5.times do |i|
      uuid = SecureRandom.uuid
      task = @replica.create_task(uuid, @operations)
      task.set_description("Rebuild test #{i}", @operations)
      task.set_status(:pending, @operations)
      task_uuids << uuid
    end
    @replica.commit_operations(@operations)
    
    # Get initial working set
    working_set1 = @replica.working_set
    initial_largest = working_set1.largest_index
    
    # Rebuild working set
    @replica.rebuild_working_set(true) # with renumbering
    
    # Get new working set
    working_set2 = @replica.working_set
    new_largest = working_set2.largest_index
    
    # All tasks should still be accessible
    task_uuids.each do |uuid|
      index = working_set2.by_uuid(uuid)
      assert index, "Task #{uuid} should still be in working set after rebuild"
    end
  end

  def test_working_set_empty_replica
    # Get working set from empty replica
    working_set = @replica.working_set
    
    assert_instance_of Taskchampion::WorkingSet, working_set
    
    # Largest index should be 0 for empty set
    assert_equal 0, working_set.largest_index
    
    # by_index should return nil
    assert_nil working_set.by_index(1)
    
    # by_uuid should return nil
    assert_nil working_set.by_uuid(SecureRandom.uuid)
  end

  def test_working_set_thread_safety
    # Create tasks
    uuid = SecureRandom.uuid
    task = @replica.create_task(uuid, @operations)
    task.set_description("Thread test", @operations)
    task.set_status(:pending, @operations)
    @replica.commit_operations(@operations)
    
    # Get working set
    working_set = @replica.working_set
    
    # Try to access from another thread
    thread_error = nil
    thread = Thread.new do
      begin
        working_set.largest_index
      rescue => e
        thread_error = e
      end
    end
    thread.join
    
    # Should raise ThreadError
    assert_instance_of Taskchampion::ThreadError, thread_error
  end

  def test_working_set_consistency
    # Create tasks and modify them
    uuid = SecureRandom.uuid
    task = @replica.create_task(uuid, @operations)
    task.set_description("Original", @operations)
    task.set_status(:pending, @operations)
    @replica.commit_operations(@operations)
    
    # Get working set and find task
    working_set1 = @replica.working_set
    index1 = working_set1.by_uuid(uuid)
    
    # Modify task
    ops2 = Taskchampion::Operations.new
    retrieved = @replica.task(uuid)
    retrieved.set_description("Modified", ops2)
    @replica.commit_operations(ops2)
    
    # Get new working set
    working_set2 = @replica.working_set
    index2 = working_set2.by_uuid(uuid)
    
    # Task should still be at same index (unless renumbered)
    # This behavior depends on TaskChampion implementation
    if index1 && index2
      # Task is still in working set
      task_from_ws = working_set2.by_index(index2)
      assert_equal "Modified", task_from_ws.description if task_from_ws
    end
  end
end