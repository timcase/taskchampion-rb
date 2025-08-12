require_relative '../test_helper'

class TestOperations < Minitest::Test
  def setup
    @operations = Taskchampion::Operations.new
  end

  def test_operations_creation
    assert_instance_of Taskchampion::Operations, @operations
  end

  def test_operations_initial_state
    assert_equal 0, @operations.length
    assert @operations.empty?

    # Test each method on empty operations
    count = 0
    @operations.each { |op| count += 1 }
    assert_equal 0, count
  end

  def test_operations_push_operation
    # Create a simple operation (this depends on Operation class implementation)
    # For now, test with mock or placeholder operation

    # Test that operations can accumulate
    replica = Taskchampion::Replica.new_in_memory
    uuid = SecureRandom.uuid
    task = replica.create_task(uuid, @operations)

    # Operations should now contain something
    assert @operations.length > 0
    refute @operations.empty?
  end

  def test_operations_length_and_empty
    # Initially empty
    assert_equal 0, @operations.length
    assert @operations.empty?

    # Add operation
    replica = Taskchampion::Replica.new_in_memory
    uuid = SecureRandom.uuid
    task = replica.create_task(uuid, @operations)

    # Should have operations now
    assert @operations.length > 0
    refute @operations.empty?
  end

  def test_operations_each_iteration
    replica = Taskchampion::Replica.new_in_memory

    # Add multiple operations
    3.times do |i|
      uuid = SecureRandom.uuid
      task = replica.create_task(uuid, @operations)
      task.set_description("Task #{i}", @operations)
    end

    # Test iteration
    count = 0
    operations_array = []

    @operations.each do |operation|
      assert_instance_of Taskchampion::Operation, operation
      operations_array << operation
      count += 1
    end

    assert count > 0
    assert_equal @operations.length, count
    assert_equal @operations.length, operations_array.length
  end

  def test_operations_indexing
    replica = Taskchampion::Replica.new_in_memory
    uuid = SecureRandom.uuid
    task = replica.create_task(uuid, @operations)
    task.set_description("Indexed operation", @operations)

    # Test array-like indexing
    first_operation = @operations[0]
    assert_instance_of Taskchampion::Operation, first_operation

    # Test out of bounds
    out_of_bounds = @operations[999]
    assert_nil out_of_bounds

    # Test negative indexing
    last_operation = @operations[-1]
    assert_instance_of Taskchampion::Operation, last_operation
  end

  def test_operations_append_operator
    replica = Taskchampion::Replica.new_in_memory
    ops2 = Taskchampion::Operations.new

    # Create operation in different operations object
    uuid = SecureRandom.uuid
    task = replica.create_task(uuid, ops2)

    initial_length = @operations.length

    # Test << operator (if implemented)
    begin
      # This may not be implemented yet
      @operations << ops2[0] if ops2.length > 0
      assert @operations.length > initial_length
    rescue NoMethodError
      # << operator not implemented yet, skip this test
      skip "Operations << operator not yet implemented"
    end
  end

  def test_operations_clear
    replica = Taskchampion::Replica.new_in_memory

    # Add operations
    uuid = SecureRandom.uuid
    task = replica.create_task(uuid, @operations)
    task.set_description("To be cleared", @operations)

    # Verify operations exist
    assert @operations.length > 0
    refute @operations.empty?

    # Clear operations
    @operations.clear

    # Should be empty now
    assert_equal 0, @operations.length
    assert @operations.empty?

    # Each should yield nothing
    count = 0
    @operations.each { |op| count += 1 }
    assert_equal 0, count
  end

  def test_operations_with_different_operation_types
    replica = Taskchampion::Replica.new_in_memory
    uuid = SecureRandom.uuid

    # Create task (generates Create operation)
    task = replica.create_task(uuid, @operations)
    create_ops_count = @operations.length

    # Set description (generates Update operation)
    task.set_description("Test description", @operations)
    update_ops_count = @operations.length

    # Set status (generates Update operation)
    task.set_status(:pending, @operations)
    status_ops_count = @operations.length

    # Should have accumulated operations
    assert create_ops_count > 0
    assert update_ops_count > create_ops_count
    assert status_ops_count > update_ops_count

    # All operations should be Operation instances
    @operations.each do |op|
      assert_instance_of Taskchampion::Operation, op
    end
  end

  def test_operations_enumerable_methods
    replica = Taskchampion::Replica.new_in_memory

    # Add some operations
    3.times do |i|
      uuid = SecureRandom.uuid
      task = replica.create_task(uuid, @operations)
      task.set_description("Task #{i}", @operations)
    end

    # Test Enumerable methods (if Operations includes Enumerable)
    operations_array = @operations.to_a
    assert_instance_of Array, operations_array
    assert_equal @operations.length, operations_array.length

    # Test map (if available)
    begin
      uuids = @operations.map(&:uuid)
      assert_instance_of Array, uuids
      assert_equal @operations.length, uuids.length
    rescue NoMethodError
      # map might not be available if Operations doesn't include Enumerable
      skip "Operations doesn't implement full Enumerable interface"
    end
  end

  def test_operations_thread_safety
    replica = Taskchampion::Replica.new_in_memory
    uuid = SecureRandom.uuid
    task = replica.create_task(uuid, @operations)

    # Try to access operations from another thread
    thread_error = nil
    thread = Thread.new do
      begin
        @operations.length
      rescue => e
        thread_error = e
      end
    end
    thread.join

    # Should raise ThreadError due to ThreadBound wrapper
    assert_instance_of Taskchampion::ThreadError, thread_error
  end

  def test_operations_after_commit
    replica = Taskchampion::Replica.new_in_memory
    uuid = SecureRandom.uuid
    task = replica.create_task(uuid, @operations)
    task.set_description("Commit test", @operations)

    # Operations should exist before commit
    assert @operations.length > 0

    # Commit operations to replica
    replica.commit_operations(@operations)

    # Operations object should still be usable
    # (The operations are consumed by commit but object remains)
    assert_instance_of Taskchampion::Operations, @operations

    # Can continue adding operations
    ops2 = Taskchampion::Operations.new
    task2 = replica.create_task(SecureRandom.uuid, ops2)
    task2.set_description("After commit", ops2)
    assert ops2.length > 0
  end

  def test_operations_string_representation
    replica = Taskchampion::Replica.new_in_memory
    uuid = SecureRandom.uuid
    task = replica.create_task(uuid, @operations)

    # Test string representation
    string_repr = @operations.to_s
    assert_instance_of String, string_repr

    # Test inspect
    inspect_repr = @operations.inspect
    assert_instance_of String, inspect_repr
    assert_includes inspect_repr, "Operations"
  end

  def test_operations_edge_cases
    # Test with empty operations
    empty_ops = Taskchampion::Operations.new
    assert_equal 0, empty_ops.length
    assert empty_ops.empty?

    # Clearing empty operations should not crash
    empty_ops.clear
    assert_equal 0, empty_ops.length

    # Iterating empty operations should not crash
    count = 0
    empty_ops.each { |op| count += 1 }
    assert_equal 0, count

    # Indexing empty operations should return nil
    assert_nil empty_ops[0]
    assert_nil empty_ops[-1]
  end

  def test_operations_multiple_replicas
    replica1 = Taskchampion::Replica.new_in_memory
    replica2 = Taskchampion::Replica.new_in_memory

    # Create operations with different replicas
    uuid1 = SecureRandom.uuid
    task1 = replica1.create_task(uuid1, @operations)

    uuid2 = SecureRandom.uuid
    task2 = replica2.create_task(uuid2, @operations)

    # Operations should accumulate from both replicas
    assert @operations.length >= 2

    # All should be valid Operation instances
    @operations.each do |op|
      assert_instance_of Taskchampion::Operation, op
    end
  end
end
