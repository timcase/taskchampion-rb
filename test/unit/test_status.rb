require_relative '../test_helper'

class TestStatus < Minitest::Test
  def test_status_constants
    # Test that Status class exists and has the expected constants
    assert defined?(Taskchampion::Status)
    
    # Test status creation methods
    pending_status = Taskchampion::Status.pending
    assert_instance_of Taskchampion::Status, pending_status
    
    completed_status = Taskchampion::Status.completed
    assert_instance_of Taskchampion::Status, completed_status
    
    deleted_status = Taskchampion::Status.deleted
    assert_instance_of Taskchampion::Status, deleted_status
  end

  def test_status_predicate_methods
    # Test pending status
    pending = Taskchampion::Status.pending
    assert pending.pending?
    refute pending.completed?
    refute pending.deleted?
    
    # Test completed status
    completed = Taskchampion::Status.completed
    refute completed.pending?
    assert completed.completed?
    refute completed.deleted?
    
    # Test deleted status
    deleted = Taskchampion::Status.deleted
    refute deleted.pending?
    refute deleted.completed?
    assert deleted.deleted?
  end

  def test_status_string_conversion
    # Test to_s method
    assert_equal "pending", Taskchampion::Status.pending.to_s
    assert_equal "completed", Taskchampion::Status.completed.to_s
    assert_equal "deleted", Taskchampion::Status.deleted.to_s
  end

  def test_status_inspect
    # Test inspect method
    pending_inspect = Taskchampion::Status.pending.inspect
    assert_instance_of String, pending_inspect
    assert_includes pending_inspect, "Status"
    assert_includes pending_inspect, "pending"
    
    completed_inspect = Taskchampion::Status.completed.inspect
    assert_includes completed_inspect, "completed"
    
    deleted_inspect = Taskchampion::Status.deleted.inspect
    assert_includes deleted_inspect, "deleted"
  end

  def test_status_equality
    # Test equality between same status types
    pending1 = Taskchampion::Status.pending
    pending2 = Taskchampion::Status.pending
    assert_equal pending1, pending2
    
    completed1 = Taskchampion::Status.completed
    completed2 = Taskchampion::Status.completed
    assert_equal completed1, completed2
    
    # Test inequality between different status types
    pending = Taskchampion::Status.pending
    completed = Taskchampion::Status.completed
    refute_equal pending, completed
    
    deleted = Taskchampion::Status.deleted
    refute_equal pending, deleted
    refute_equal completed, deleted
  end

  def test_status_hash
    # Test that status objects can be used as hash keys
    status_hash = {}
    
    pending = Taskchampion::Status.pending
    completed = Taskchampion::Status.completed
    deleted = Taskchampion::Status.deleted
    
    status_hash[pending] = "pending tasks"
    status_hash[completed] = "completed tasks"
    status_hash[deleted] = "deleted tasks"
    
    assert_equal "pending tasks", status_hash[Taskchampion::Status.pending]
    assert_equal "completed tasks", status_hash[Taskchampion::Status.completed]
    assert_equal "deleted tasks", status_hash[Taskchampion::Status.deleted]
  end

  def test_status_with_tasks
    # Test status usage with actual tasks
    replica = Taskchampion::Replica.new_in_memory
    operations = Taskchampion::Operations.new
    
    uuid = SecureRandom.uuid
    task = replica.create_task(uuid, operations)
    
    # Set task to pending status
    task.set_status(Taskchampion::Status.pending, operations)
    replica.commit_operations(operations)
    
    # Retrieve and verify status
    retrieved_task = replica.task(uuid)
    assert retrieved_task.pending?
    
    # Change to completed
    operations2 = Taskchampion::Operations.new
    retrieved_task.set_status(Taskchampion::Status.completed, operations2)
    replica.commit_operations(operations2)
    
    # Verify completion
    completed_task = replica.task(uuid)
    assert completed_task.completed?
    refute completed_task.pending?
  end

  def test_status_symbol_compatibility
    # Test that status can work with symbols (Ruby-idiomatic)
    replica = Taskchampion::Replica.new_in_memory
    operations = Taskchampion::Operations.new
    
    uuid = SecureRandom.uuid
    task = replica.create_task(uuid, operations)
    
    # Should be able to use symbols
    task.set_status(:pending, operations)
    replica.commit_operations(operations)
    
    retrieved_task = replica.task(uuid)
    assert retrieved_task.pending?
    
    # Test other symbols
    operations2 = Taskchampion::Operations.new
    retrieved_task.set_status(:completed, operations2)
    replica.commit_operations(operations2)
    
    completed_task = replica.task(uuid)
    assert completed_task.completed?
  end

  def test_status_thread_safety
    pending_status = Taskchampion::Status.pending
    
    # Try to access from another thread
    thread_error = nil
    thread = Thread.new do
      begin
        pending_status.pending?
      rescue => e
        thread_error = e
      end
    end
    thread.join
    
    # Status objects should be thread-safe (they're immutable)
    # This should NOT raise a ThreadError unlike other ThreadBound objects
    assert_nil thread_error
  end

  def test_status_immutability
    pending = Taskchampion::Status.pending
    
    # Status objects should be immutable - they don't expose setter methods
    # Test that we can't call non-existent setter methods
    assert_raises(NoMethodError) do
      pending.status = "modified"
    end
    
    # Test that predicate methods are consistent (immutable behavior)
    assert pending.pending?
    assert pending.pending? # Should always return the same
    refute pending.completed?
    refute pending.completed? # Should always return the same
    refute pending.deleted?
    refute pending.deleted? # Should always return the same
  end

  def test_status_recurring
    # Test recurring status if it exists
    begin
      recurring = Taskchampion::Status.recurring
      assert_instance_of Taskchampion::Status, recurring
      assert recurring.recurring?
      refute recurring.pending?
      refute recurring.completed?
      refute recurring.deleted?
      assert_equal "recurring", recurring.to_s
    rescue NoMethodError
      # Recurring status might not be implemented yet
      skip "Recurring status not yet implemented"
    end
  end

  def test_status_edge_cases
    # Test that status methods handle edge cases gracefully
    pending = Taskchampion::Status.pending
    
    # Multiple calls should return same result
    assert pending.pending?
    assert pending.pending?
    refute pending.completed?
    refute pending.completed?
    
    # String conversion should be consistent
    str1 = pending.to_s
    str2 = pending.to_s
    assert_equal str1, str2
    
    # Inspect should be consistent
    inspect1 = pending.inspect
    inspect2 = pending.inspect
    assert_equal inspect1, inspect2
  end

  def test_status_comparison_with_nil
    pending = Taskchampion::Status.pending
    
    # Should not equal nil
    refute_equal pending, nil
    refute_nil pending
    
    # Should handle nil comparison gracefully
    refute_equal nil, pending
  end

  def test_status_comparison_with_other_types
    pending = Taskchampion::Status.pending
    
    # Should not equal strings
    refute_equal pending, "pending"
    refute_equal "pending", pending
    
    # Should not equal symbols
    refute_equal pending, :pending
    refute_equal :pending, pending
    
    # Should not equal other objects
    refute_equal pending, Object.new
    refute_equal pending, 42
  end

  def test_all_status_types_exist
    # Verify all expected status types are available
    status_types = [:pending, :completed, :deleted]
    
    status_types.each do |type|
      # Class method should exist
      status = Taskchampion::Status.send(type)
      assert_instance_of Taskchampion::Status, status
      
      # Predicate method should exist and return true for itself
      predicate_method = "#{type}?"
      assert status.respond_to?(predicate_method)
      assert status.send(predicate_method)
      
      # Should return false for other predicates
      other_types = status_types - [type]
      other_types.each do |other_type|
        other_predicate = "#{other_type}?"
        if status.respond_to?(other_predicate)
          refute status.send(other_predicate)
        end
      end
    end
  end
end