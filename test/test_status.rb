# frozen_string_literal: true

require "test_helper"

class TestStatus < TaskchampionTest
  def test_status_constructors
    pending = Taskchampion::Status.pending
    completed = Taskchampion::Status.completed
    deleted = Taskchampion::Status.deleted
    recurring = Taskchampion::Status.recurring
    unknown = Taskchampion::Status.unknown

    assert_instance_of Taskchampion::Status, pending
    assert_instance_of Taskchampion::Status, completed
    assert_instance_of Taskchampion::Status, deleted
    assert_instance_of Taskchampion::Status, recurring
    assert_instance_of Taskchampion::Status, unknown
  end

  def test_status_predicates
    pending = Taskchampion::Status.pending
    completed = Taskchampion::Status.completed

    assert pending.pending?
    refute pending.completed?
    refute pending.deleted?

    assert completed.completed?
    refute completed.pending?
    refute completed.deleted?
  end

  def test_status_to_s
    assert_equal "pending", Taskchampion::Status.pending.to_s
    assert_equal "completed", Taskchampion::Status.completed.to_s
    assert_equal "deleted", Taskchampion::Status.deleted.to_s
    assert_equal "recurring", Taskchampion::Status.recurring.to_s
    assert_equal "unknown", Taskchampion::Status.unknown.to_s
  end

  def test_status_inspect
    assert_equal "#<Taskchampion::Status:pending>", Taskchampion::Status.pending.inspect
    assert_equal "#<Taskchampion::Status:completed>", Taskchampion::Status.completed.inspect
  end

  def test_status_equality
    pending1 = Taskchampion::Status.pending
    pending2 = Taskchampion::Status.pending
    completed = Taskchampion::Status.completed

    assert_equal pending1, pending2
    refute_equal pending1, completed
  end

  def test_status_constants_still_exist
    # For backward compatibility
    assert_equal :pending, Taskchampion::PENDING
    assert_equal :completed, Taskchampion::COMPLETED
    assert_equal :deleted, Taskchampion::DELETED
    assert_equal :recurring, Taskchampion::RECURRING
    assert_equal :unknown, Taskchampion::UNKNOWN
  end
end
