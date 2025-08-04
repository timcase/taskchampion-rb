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
    assert_equal({}, replica.tasks)
  end

  def test_task_class_exists
    # We can't easily create Task instances without Operations,
    # but we can verify the class exists
    assert_kind_of Class, Taskchampion::Task
  end
end