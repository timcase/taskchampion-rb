require_relative '../test_helper'
require 'securerandom'

class TestErrorHandling < Minitest::Test
  def setup
    @replica = Taskchampion::Replica.new_in_memory
    @operations = Taskchampion::Operations.new
  end

  # UUID Validation Tests
  def test_invalid_uuid_format_raises_validation_error
    assert_raises(Taskchampion::ValidationError) do
      @replica.task("invalid-uuid")
    end
    
    assert_raises(Taskchampion::ValidationError) do
      @replica.task("123")
    end
    
    assert_raises(Taskchampion::ValidationError) do
      @replica.task("")
    end
  end

  def test_invalid_uuid_error_message
    error = assert_raises(Taskchampion::ValidationError) do
      @replica.task("not-a-uuid")
    end
    assert_match(/Invalid UUID format/, error.message)
    assert_match(/not-a-uuid/, error.message)
    assert_match(/Expected format/, error.message)
  end

  # Status Validation Tests
  def test_invalid_status_raises_validation_error
    uuid = SecureRandom.uuid
    task = @replica.create_task(uuid, @operations)
    @replica.commit_operations(@operations)
    
    retrieved = @replica.task(uuid)
    ops = Taskchampion::Operations.new
    
    assert_raises(Taskchampion::ValidationError) do
      retrieved.set_status(:invalid_status, ops)
    end
    
    assert_raises(Taskchampion::ValidationError) do
      retrieved.set_status(:unknown_status, ops)
    end
  end

  def test_invalid_status_error_message
    uuid = SecureRandom.uuid
    task = @replica.create_task(uuid, @operations)
    @replica.commit_operations(@operations)
    
    retrieved = @replica.task(uuid)
    ops = Taskchampion::Operations.new
    
    error = assert_raises(Taskchampion::ValidationError) do
      retrieved.set_status(:invalid, ops)
    end
    assert_match(/Invalid status: :invalid/, error.message)
    assert_match(/Expected one of/, error.message)
    assert_match(/:pending, :completed, :deleted/, error.message)
  end

  # DateTime Validation Tests
  def test_invalid_datetime_raises_validation_error
    uuid = SecureRandom.uuid
    task = @replica.create_task(uuid, @operations)
    @replica.commit_operations(@operations)
    
    retrieved = @replica.task(uuid)
    ops = Taskchampion::Operations.new
    
    assert_raises(Taskchampion::ValidationError) do
      retrieved.set_due("not-a-date", ops)
    end
    
    assert_raises(Taskchampion::ValidationError) do
      retrieved.set_due("2023-13-45", ops)
    end
    
    assert_raises(Taskchampion::ValidationError) do
      retrieved.set_due("yesterday", ops)
    end
  end

  def test_invalid_datetime_error_message
    uuid = SecureRandom.uuid
    task = @replica.create_task(uuid, @operations)
    @replica.commit_operations(@operations)
    
    retrieved = @replica.task(uuid)
    ops = Taskchampion::Operations.new
    
    error = assert_raises(Taskchampion::ValidationError) do
      retrieved.set_due("invalid-date", ops)
    end
    assert_match(/Invalid datetime format/, error.message)
    assert_match(/invalid-date/, error.message)
    assert_match(/Expected ISO 8601 format/, error.message)
  end

  def test_valid_datetime_formats
    uuid = SecureRandom.uuid
    task = @replica.create_task(uuid, @operations)
    @replica.commit_operations(@operations)
    
    retrieved = @replica.task(uuid)
    ops = Taskchampion::Operations.new
    
    # These should all work
    retrieved.set_due(Time.now, ops)
    retrieved.set_due(DateTime.now, ops)
    retrieved.set_due("2023-01-01T12:00:00Z", ops)
    retrieved.set_due(nil, ops) # Clear due date
    
    # Should not raise any errors
    @replica.commit_operations(ops)
  end

  # Empty String Validation Tests
  def test_empty_description_raises_validation_error
    uuid = SecureRandom.uuid
    task = @replica.create_task(uuid, @operations)
    @replica.commit_operations(@operations)
    
    retrieved = @replica.task(uuid)
    ops = Taskchampion::Operations.new
    
    assert_raises(Taskchampion::ValidationError) do
      retrieved.set_description("", ops)
    end
    
    assert_raises(Taskchampion::ValidationError) do
      retrieved.set_description("   ", ops)
    end
    
    assert_raises(Taskchampion::ValidationError) do
      retrieved.set_description("\t\n", ops)
    end
  end

  def test_empty_priority_raises_validation_error
    uuid = SecureRandom.uuid
    task = @replica.create_task(uuid, @operations)
    @replica.commit_operations(@operations)
    
    retrieved = @replica.task(uuid)
    ops = Taskchampion::Operations.new
    
    assert_raises(Taskchampion::ValidationError) do
      retrieved.set_priority("", ops)
    end
    
    error = assert_raises(Taskchampion::ValidationError) do
      retrieved.set_priority("   ", ops)
    end
    assert_match(/Priority cannot be empty/, error.message)
  end

  def test_empty_annotation_raises_validation_error
    uuid = SecureRandom.uuid
    task = @replica.create_task(uuid, @operations)
    @replica.commit_operations(@operations)
    
    retrieved = @replica.task(uuid)
    ops = Taskchampion::Operations.new
    
    assert_raises(Taskchampion::ValidationError) do
      retrieved.add_annotation("", ops)
    end
    
    error = assert_raises(Taskchampion::ValidationError) do
      retrieved.add_annotation("   ", ops)
    end
    assert_match(/Annotation description cannot be empty/, error.message)
  end

  def test_empty_property_name_raises_validation_error
    uuid = SecureRandom.uuid
    task = @replica.create_task(uuid, @operations)
    @replica.commit_operations(@operations)
    
    retrieved = @replica.task(uuid)
    ops = Taskchampion::Operations.new
    
    assert_raises(Taskchampion::ValidationError) do
      retrieved.set_value("", "value", ops)
    end
    
    error = assert_raises(Taskchampion::ValidationError) do
      retrieved.set_value("   ", "value", ops)
    end
    assert_match(/Property name cannot be empty/, error.message)
  end

  def test_empty_uda_namespace_raises_validation_error
    uuid = SecureRandom.uuid
    task = @replica.create_task(uuid, @operations)
    @replica.commit_operations(@operations)
    
    retrieved = @replica.task(uuid)
    ops = Taskchampion::Operations.new
    
    assert_raises(Taskchampion::ValidationError) do
      retrieved.set_uda("", "key", "value", ops)
    end
    
    error = assert_raises(Taskchampion::ValidationError) do
      retrieved.set_uda("   ", "key", "value", ops)
    end
    assert_match(/UDA namespace cannot be empty/, error.message)
  end

  def test_empty_uda_key_raises_validation_error
    uuid = SecureRandom.uuid
    task = @replica.create_task(uuid, @operations)
    @replica.commit_operations(@operations)
    
    retrieved = @replica.task(uuid)
    ops = Taskchampion::Operations.new
    
    assert_raises(Taskchampion::ValidationError) do
      retrieved.set_uda("namespace", "", "value", ops)
    end
    
    error = assert_raises(Taskchampion::ValidationError) do
      retrieved.set_uda("namespace", "   ", "value", ops)
    end
    assert_match(/UDA key cannot be empty/, error.message)
  end

  def test_delete_uda_validation
    uuid = SecureRandom.uuid
    task = @replica.create_task(uuid, @operations)
    @replica.commit_operations(@operations)
    
    retrieved = @replica.task(uuid)
    ops = Taskchampion::Operations.new
    
    assert_raises(Taskchampion::ValidationError) do
      retrieved.delete_uda("", "key", ops)
    end
    
    assert_raises(Taskchampion::ValidationError) do
      retrieved.delete_uda("namespace", "", ops)
    end
  end

  # Error Type Tests
  def test_error_class_hierarchy
    # All custom errors should inherit from Taskchampion::Error
    assert Taskchampion::ThreadError < Taskchampion::Error
    assert Taskchampion::StorageError < Taskchampion::Error
    assert Taskchampion::ValidationError < Taskchampion::Error
    assert Taskchampion::ConfigError < Taskchampion::Error
    assert Taskchampion::SyncError < Taskchampion::Error
    
    # Base error should inherit from StandardError
    assert Taskchampion::Error < StandardError
  end

  def test_thread_error_on_cross_thread_access
    replica = Taskchampion::Replica.new_in_memory
    error = nil
    
    thread = Thread.new do
      begin
        replica.task_uuids
      rescue => e
        error = e
      end
    end
    thread.join
    
    assert_instance_of Taskchampion::ThreadError, error
    assert_match(/different thread/, error.message)
  end

  # Tag Validation Tests
  def test_invalid_tag_raises_validation_error
    assert_raises(Taskchampion::ValidationError) do
      Taskchampion::Tag.new("")
    end
    
    # Tags with invalid characters should raise
    assert_raises(Taskchampion::ValidationError) do
      Taskchampion::Tag.new("tag with spaces")
    end
  end

  # Operations Validation Tests  
  def test_operations_index_out_of_bounds
    ops = Taskchampion::Operations.new
    
    # Ruby-style behavior: return nil for out of bounds instead of raising
    assert_nil ops[0]  # Empty operations
    assert_nil ops[100]  # Out of bounds
    assert_nil ops[-1]   # Negative index on empty
  end

  # Status Symbol Creation Tests
  def test_status_from_invalid_symbol
    assert_raises(Taskchampion::ValidationError) do
      Taskchampion::Status.from_symbol(:invalid)
    end
  end

  # Ruby-style Setter Validation
  def test_ruby_setter_validation
    uuid = SecureRandom.uuid
    task = @replica.create_task(uuid, @operations)
    @replica.commit_operations(@operations)
    
    retrieved = @replica.task(uuid)
    ops = Taskchampion::Operations.new
    
    # Empty description with standard setter
    assert_raises(Taskchampion::ValidationError) do
      retrieved.set_description("", ops)
    end
    
    # Invalid status with standard setter  
    assert_raises(Taskchampion::ValidationError) do
      retrieved.set_status(:invalid, ops)
    end
    
    # Empty priority with standard setter
    assert_raises(Taskchampion::ValidationError) do
      retrieved.set_priority("", ops)
    end
  end
end