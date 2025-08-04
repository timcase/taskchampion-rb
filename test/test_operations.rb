# frozen_string_literal: true

require "test_helper"

class TestOperations < TaskchampionTest
  def test_operations_creation
    ops = Taskchampion::Operations.new
    assert_instance_of Taskchampion::Operations, ops
    assert_equal 0, ops.length
    assert_equal 0, ops.size
    assert ops.empty?
  end

  def test_operation_create
    uuid = SecureRandom.uuid
    op = Taskchampion::Operation.create(uuid)

    assert_instance_of Taskchampion::Operation, op
    assert op.create?
    refute op.delete?
    refute op.update?
    refute op.undo_point?
    assert_equal uuid, op.uuid
  end

  def test_operation_delete
    uuid = SecureRandom.uuid
    old_task = { "description" => "old task", "status" => "pending" }
    op = Taskchampion::Operation.delete(uuid, old_task)

    assert_instance_of Taskchampion::Operation, op
    refute op.create?
    assert op.delete?
    refute op.update?
    refute op.undo_point?
    assert_equal uuid, op.uuid
    assert_equal old_task, op.old_task
  end

  def test_operation_update
    uuid = SecureRandom.uuid
    timestamp = DateTime.now
    op = Taskchampion::Operation.update(uuid, "description", timestamp, "old desc", "new desc")

    assert_instance_of Taskchampion::Operation, op
    refute op.create?
    refute op.delete?
    assert op.update?
    refute op.undo_point?
    assert_equal uuid, op.uuid
    assert_equal "description", op.property
    assert_equal "old desc", op.old_value
    assert_equal "new desc", op.value

    # Timestamp should be close to what we passed in
    time_diff = (op.timestamp.to_time - timestamp.to_time).abs
    assert time_diff < 1  # Within 1 second
  end

  def test_operation_undo_point
    op = Taskchampion::Operation.undo_point

    assert_instance_of Taskchampion::Operation, op
    refute op.create?
    refute op.delete?
    refute op.update?
    assert op.undo_point?

    # UndoPoint operations should raise errors for uuid access
    assert_raises(ArgumentError) { op.uuid }
  end

  def test_operations_with_operations
    ops = Taskchampion::Operations.new

    uuid = SecureRandom.uuid
    create_op = Taskchampion::Operation.create(uuid)
    update_op = Taskchampion::Operation.update(uuid, "description", DateTime.now, nil, "new desc")

    ops.push(create_op)
    ops << update_op

    assert_equal 2, ops.length
    refute ops.empty?

    # Test array access
    assert_equal create_op.class, ops[0].class
    assert_equal update_op.class, ops[1].class

    # Test array conversion
    array = ops.to_a
    assert_instance_of Array, array
    assert_equal 2, array.length
  end

  def test_operations_clear
    ops = Taskchampion::Operations.new
    ops.push(Taskchampion::Operation.create(SecureRandom.uuid))

    assert_equal 1, ops.length
    ops.clear
    assert_equal 0, ops.length
    assert ops.empty?
  end
end