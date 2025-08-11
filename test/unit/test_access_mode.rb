require_relative '../test_helper'

class TestAccessMode < Minitest::Test
  def test_access_mode_constants
    # Test that AccessMode class exists and has the expected constants
    assert defined?(Taskchampion::AccessMode)
    
    # Test access mode creation methods
    read_only = Taskchampion::AccessMode.read_only
    assert_instance_of Taskchampion::AccessMode, read_only
    
    read_write = Taskchampion::AccessMode.read_write
    assert_instance_of Taskchampion::AccessMode, read_write
  end

  def test_access_mode_predicate_methods
    # Test read_only mode
    read_only = Taskchampion::AccessMode.read_only
    assert read_only.read_only?
    refute read_only.read_write?
    
    # Test read_write mode
    read_write = Taskchampion::AccessMode.read_write
    refute read_write.read_only?
    assert read_write.read_write?
  end

  def test_access_mode_string_conversion
    # Test to_s method
    assert_equal "read_only", Taskchampion::AccessMode.read_only.to_s
    assert_equal "read_write", Taskchampion::AccessMode.read_write.to_s
  end

  def test_access_mode_inspect
    # Test inspect method
    read_only_inspect = Taskchampion::AccessMode.read_only.inspect
    assert_instance_of String, read_only_inspect
    assert_includes read_only_inspect, "AccessMode"
    assert_includes read_only_inspect, "read_only"
    
    read_write_inspect = Taskchampion::AccessMode.read_write.inspect
    assert_includes read_write_inspect, "AccessMode"
    assert_includes read_write_inspect, "read_write"
  end

  def test_access_mode_equality
    # Test equality between same access mode types
    read_only1 = Taskchampion::AccessMode.read_only
    read_only2 = Taskchampion::AccessMode.read_only
    assert_equal read_only1, read_only2
    
    read_write1 = Taskchampion::AccessMode.read_write
    read_write2 = Taskchampion::AccessMode.read_write
    assert_equal read_write1, read_write2
    
    # Test inequality between different access mode types
    read_only = Taskchampion::AccessMode.read_only
    read_write = Taskchampion::AccessMode.read_write
    refute_equal read_only, read_write
  end

  def test_access_mode_hash
    # Test that access mode objects can be used as hash keys
    mode_hash = {}
    
    read_only = Taskchampion::AccessMode.read_only
    read_write = Taskchampion::AccessMode.read_write
    
    mode_hash[read_only] = "read only replica"
    mode_hash[read_write] = "read write replica"
    
    assert_equal "read only replica", mode_hash[Taskchampion::AccessMode.read_only]
    assert_equal "read write replica", mode_hash[Taskchampion::AccessMode.read_write]
  end

  def test_access_mode_with_replica_creation
    # Test access mode usage with replica creation
    require 'tmpdir'
    
    Dir.mktmpdir do |tmpdir|
      replica_path = File.join(tmpdir, "test_replica")
      
      # Create replica with read_write access (default)
      replica_rw = Taskchampion::Replica.new_on_disk(
        replica_path, 
        true,  # create_if_missing
        :read_write  # access_mode as symbol
      )
      assert_instance_of Taskchampion::Replica, replica_rw
      
      # Create operations and task to ensure write access works
      operations = Taskchampion::Operations.new
      uuid = SecureRandom.uuid
      task = replica_rw.create_task(uuid, operations)
      task.set_description("Test write access", operations)
      replica_rw.commit_operations(operations)
      
      # Verify task was created
      retrieved_task = replica_rw.task(uuid)
      assert_equal "Test write access", retrieved_task.description
      
      # Create read-only replica on same path
      begin
        replica_ro = Taskchampion::Replica.new_on_disk(
          replica_path,
          false,  # create_if_missing
          :read_only  # access_mode as symbol
        )
        
        # Should be able to read existing task
        ro_task = replica_ro.task(uuid)
        assert_equal "Test write access", ro_task.description
        
        # Should not be able to write (this might raise an error or be silently ignored)
        ro_operations = Taskchampion::Operations.new
        new_uuid = SecureRandom.uuid
        
        # This behavior depends on implementation - might raise error or create task that can't be committed
        assert_raises(StandardError) do
          ro_task_new = replica_ro.create_task(new_uuid, ro_operations)
          ro_task_new.set_description("Should fail", ro_operations)
          replica_ro.commit_operations(ro_operations)
        end
      rescue ArgumentError, NoMethodError
        # Access mode parameter might not be implemented yet in replica creation
        skip "AccessMode parameter not yet supported in Replica.new_on_disk"
      end
    end
  end

  def test_access_mode_symbol_compatibility
    # Test that access modes work with symbols (Ruby-idiomatic)
    begin
      read_only_from_symbol = Taskchampion::AccessMode.from_symbol(:read_only)
      assert_instance_of Taskchampion::AccessMode, read_only_from_symbol
      assert read_only_from_symbol.read_only?
      
      read_write_from_symbol = Taskchampion::AccessMode.from_symbol(:read_write)
      assert_instance_of Taskchampion::AccessMode, read_write_from_symbol
      assert read_write_from_symbol.read_write?
    rescue NoMethodError
      # from_symbol method might not be implemented yet
      skip "AccessMode.from_symbol not yet implemented"
    end
  end

  def test_access_mode_thread_safety
    read_only = Taskchampion::AccessMode.read_only
    
    # Try to access from another thread
    thread_error = nil
    thread = Thread.new do
      begin
        read_only.read_only?
      rescue => e
        thread_error = e
      end
    end
    thread.join
    
    # AccessMode objects should be thread-safe (they're immutable)
    # This should NOT raise a ThreadError unlike other ThreadBound objects
    assert_nil thread_error
  end

  def test_access_mode_immutability
    read_only = Taskchampion::AccessMode.read_only
    
    # AccessMode objects should be immutable - they don't expose setter methods
    # Test that we can't call non-existent setter methods
    assert_raises(NoMethodError) do
      read_only.mode = "modified"
    end
    
    # Test that predicate methods are consistent (immutable behavior)
    assert read_only.read_only?
    assert read_only.read_only? # Should always return the same
    refute read_only.read_write?
    refute read_only.read_write? # Should always return the same
  end

  def test_access_mode_edge_cases
    # Test that access mode methods handle edge cases gracefully
    read_only = Taskchampion::AccessMode.read_only
    
    # Multiple calls should return same result
    assert read_only.read_only?
    assert read_only.read_only?
    refute read_only.read_write?
    refute read_only.read_write?
    
    # String conversion should be consistent
    str1 = read_only.to_s
    str2 = read_only.to_s
    assert_equal str1, str2
    
    # Inspect should be consistent
    inspect1 = read_only.inspect
    inspect2 = read_only.inspect
    assert_equal inspect1, inspect2
  end

  def test_access_mode_comparison_with_nil
    read_only = Taskchampion::AccessMode.read_only
    
    # Should not equal nil
    refute_equal read_only, nil
    refute_nil read_only
    
    # Should handle nil comparison gracefully
    refute_equal nil, read_only
  end

  def test_access_mode_comparison_with_other_types
    read_only = Taskchampion::AccessMode.read_only
    
    # Should not equal strings
    refute_equal read_only, "read_only"
    refute_equal "read_only", read_only
    
    # Should not equal symbols
    refute_equal read_only, :read_only
    refute_equal :read_only, read_only
    
    # Should not equal other objects
    refute_equal read_only, Object.new
    refute_equal read_only, 42
  end

  def test_all_access_mode_types_exist
    # Verify all expected access mode types are available
    mode_types = [:read_only, :read_write]
    
    mode_types.each do |type|
      # Class method should exist
      mode = Taskchampion::AccessMode.send(type)
      assert_instance_of Taskchampion::AccessMode, mode
      
      # Predicate method should exist and return true for itself
      predicate_method = "#{type}?"
      assert mode.respond_to?(predicate_method)
      assert mode.send(predicate_method)
      
      # Should return false for other predicates
      other_types = mode_types - [type]
      other_types.each do |other_type|
        other_predicate = "#{other_type}?"
        if mode.respond_to?(other_predicate)
          refute mode.send(other_predicate)
        end
      end
    end
  end

  def test_access_mode_with_in_memory_replica
    # Test that in-memory replicas default to read_write
    replica = Taskchampion::Replica.new_in_memory
    
    # Should be able to create and modify tasks (read_write behavior)
    operations = Taskchampion::Operations.new
    uuid = SecureRandom.uuid
    task = replica.create_task(uuid, operations)
    task.set_description("Memory test", operations)
    replica.commit_operations(operations)
    
    # Verify write succeeded
    retrieved_task = replica.task(uuid)
    assert_equal "Memory test", retrieved_task.description
  end

  def test_access_mode_string_representations
    read_only = Taskchampion::AccessMode.read_only
    read_write = Taskchampion::AccessMode.read_write
    
    # Test that string representations are Ruby-idiomatic (snake_case)
    assert_equal "read_only", read_only.to_s
    assert_equal "read_write", read_write.to_s
    
    # Test that inspect includes class name
    assert_match(/AccessMode.*read_only/, read_only.inspect)
    assert_match(/AccessMode.*read_write/, read_write.inspect)
  end

  def test_access_mode_creation_consistency
    # Test that multiple calls to same class method return equal objects
    mode1 = Taskchampion::AccessMode.read_only
    mode2 = Taskchampion::AccessMode.read_only
    
    assert_equal mode1, mode2
    assert_equal mode1.hash, mode2.hash
    assert_equal mode1.to_s, mode2.to_s
    assert_equal mode1.inspect, mode2.inspect
    
    # Same for read_write
    mode3 = Taskchampion::AccessMode.read_write
    mode4 = Taskchampion::AccessMode.read_write
    
    assert_equal mode3, mode4
    assert_equal mode3.hash, mode4.hash
  end
end