# frozen_string_literal: true

require "test_helper"

class TestTask < TaskchampionTest
  def test_status_constants
    assert_equal :pending, Taskchampion::PENDING
    assert_equal :completed, Taskchampion::COMPLETED
    assert_equal :deleted, Taskchampion::DELETED
    assert_equal :recurring, Taskchampion::RECURRING
    assert_equal :unknown, Taskchampion::UNKNOWN
  end

  def test_tag_creation
    tag = Taskchampion::Tag.new("work")
    assert_instance_of Taskchampion::Tag, tag
    assert_equal "work", tag.to_s
    assert tag.user?
    refute tag.synthetic?
  end

  def test_tag_equality
    tag1 = Taskchampion::Tag.new("work")
    tag2 = Taskchampion::Tag.new("work")
    tag3 = Taskchampion::Tag.new("home")

    assert tag1.eql?(tag2)
    assert_equal tag1, tag2
    refute tag1.eql?(tag3)
    refute_equal tag1, tag3

    assert_equal tag1.hash, tag2.hash
    refute_equal tag1.hash, tag3.hash
  end

  def test_annotation_creation
    now = DateTime.now
    annotation = Taskchampion::Annotation.new(now, "This is a note")

    assert_instance_of Taskchampion::Annotation, annotation
    assert_equal "This is a note", annotation.description
    assert_equal "This is a note", annotation.to_s

    # Entry should be close to what we passed in
    entry_diff = (annotation.entry.to_time - now.to_time).abs
    assert entry_diff < 1  # Within 1 second
  end

  def test_annotation_equality
    now = DateTime.now
    ann1 = Taskchampion::Annotation.new(now, "Same note")
    ann2 = Taskchampion::Annotation.new(now, "Same note")
    ann3 = Taskchampion::Annotation.new(now, "Different note")

    assert ann1.eql?(ann2)
    assert_equal ann1, ann2
    refute ann1.eql?(ann3)
    refute_equal ann1, ann3
  end

  def test_replica_with_in_memory_tasks
    replica = Taskchampion::Replica.new_in_memory

    # Should start with no tasks
    assert_equal [], replica.task_uuids
    assert_equal({}, replica.all_tasks)
  end

  def test_task_class_exists
    # We can't easily create Task instances without Operations,
    # but we can verify the class exists
    assert_kind_of Class, Taskchampion::Task
  end

  def test_set_and_get_timestamp
    replica = Taskchampion::Replica.new_in_memory
    operations = Taskchampion::Operations.new

    # Create a task
    uuid = SecureRandom.uuid
    task = replica.create_task(uuid, operations)
    task.set_description("Test task", operations)

    # Set a custom timestamp property
    scheduled_time = DateTime.now + 7 # 7 days from now
    task.set_timestamp("scheduled", scheduled_time, operations)

    # Commit and retrieve the task
    replica.commit_operations(operations)
    retrieved_task = replica.task(uuid)

    # Verify the timestamp was stored and retrieved correctly
    retrieved_scheduled = retrieved_task.get_timestamp("scheduled")
    refute_nil retrieved_scheduled
    assert_instance_of DateTime, retrieved_scheduled

    # Should be very close (within 1 second due to precision)
    time_diff = (retrieved_scheduled.to_time - scheduled_time.to_time).abs
    assert time_diff < 1
  end

  def test_set_timestamp_with_nil
    replica = Taskchampion::Replica.new_in_memory
    operations = Taskchampion::Operations.new

    # Create a task
    uuid = SecureRandom.uuid
    task = replica.create_task(uuid, operations)
    task.set_description("Test task", operations)

    # Set a custom timestamp, then clear it
    task.set_timestamp("scheduled", DateTime.now, operations)
    task.set_timestamp("scheduled", nil, operations)

    # Commit and retrieve
    replica.commit_operations(operations)
    retrieved_task = replica.task(uuid)

    # Should return nil when timestamp is cleared
    retrieved_scheduled = retrieved_task.get_timestamp("scheduled")
    assert_nil retrieved_scheduled
  end

  def test_set_timestamp_with_different_formats
    replica = Taskchampion::Replica.new_in_memory
    operations = Taskchampion::Operations.new

    # Create a task
    uuid = SecureRandom.uuid
    task = replica.create_task(uuid, operations)
    task.set_description("Test task", operations)

    # Test with Ruby Time object
    time_obj = Time.now + (24 * 60 * 60) # 1 day from now
    task.set_timestamp("due_custom", time_obj, operations)

    # Test with DateTime object
    datetime_obj = DateTime.now + 2 # 2 days from now
    task.set_timestamp("wait_custom", datetime_obj, operations)

    # Test with ISO 8601 string
    iso_string = "2024-12-31T23:59:59Z"
    task.set_timestamp("end_custom", iso_string, operations)

    replica.commit_operations(operations)
    retrieved_task = replica.task(uuid)

    # All should be retrievable as DateTime objects
    due_custom = retrieved_task.get_timestamp("due_custom")
    wait_custom = retrieved_task.get_timestamp("wait_custom")
    end_custom = retrieved_task.get_timestamp("end_custom")

    assert_instance_of DateTime, due_custom
    assert_instance_of DateTime, wait_custom
    assert_instance_of DateTime, end_custom

    # Check the ISO string was parsed correctly
    assert_equal 2024, end_custom.year
    assert_equal 12, end_custom.month
    assert_equal 31, end_custom.day
    assert_equal 23, end_custom.hour
    assert_equal 59, end_custom.min
    assert_equal 59, end_custom.sec
  end

  def test_get_timestamp_nonexistent_property
    replica = Taskchampion::Replica.new_in_memory
    operations = Taskchampion::Operations.new

    # Create a task
    uuid = SecureRandom.uuid
    task = replica.create_task(uuid, operations)
    task.set_description("Test task", operations)

    replica.commit_operations(operations)
    retrieved_task = replica.task(uuid)

    # Getting a non-existent timestamp should return nil
    nonexistent = retrieved_task.get_timestamp("nonexistent")
    assert_nil nonexistent
  end

  def test_timestamp_consistency_with_built_in_dates
    replica = Taskchampion::Replica.new_in_memory
    operations = Taskchampion::Operations.new

    # Create a task
    uuid = SecureRandom.uuid
    task = replica.create_task(uuid, operations)
    task.set_description("Test task", operations)

    # Set both a built-in date and custom date
    due_time = DateTime.now + 1
    custom_time = DateTime.now + 2

    task.set_due(due_time, operations)
    task.set_timestamp("custom_due", custom_time, operations)

    replica.commit_operations(operations)
    retrieved_task = replica.task(uuid)

    # Both should be retrievable and have same format
    built_in_due = retrieved_task.due
    custom_due = retrieved_task.get_timestamp("custom_due")

    assert_instance_of DateTime, built_in_due
    assert_instance_of DateTime, custom_due

    # Should also be able to get built-in date using get_timestamp
    due_via_get_timestamp = retrieved_task.get_timestamp("due")
    assert_instance_of DateTime, due_via_get_timestamp

    # Both methods should return the same value for built-in fields
    time_diff = (built_in_due.to_time - due_via_get_timestamp.to_time).abs
    assert time_diff < 0.01 # Should be essentially identical
  end

  def test_timestamp_property_validation
    replica = Taskchampion::Replica.new_in_memory
    operations = Taskchampion::Operations.new

    # Create a task
    uuid = SecureRandom.uuid
    task = replica.create_task(uuid, operations)
    task.set_description("Test task", operations)

    replica.commit_operations(operations)
    retrieved_task = replica.task(uuid)

    # Empty property name should raise validation error
    assert_raises Taskchampion::ValidationError do
      retrieved_task.set_timestamp("", DateTime.now, operations)
    end

    assert_raises Taskchampion::ValidationError do
      retrieved_task.set_timestamp("   ", DateTime.now, operations)
    end

    assert_raises Taskchampion::ValidationError do
      retrieved_task.get_timestamp("")
    end

    assert_raises Taskchampion::ValidationError do
      retrieved_task.get_timestamp("   ")
    end
  end
end
