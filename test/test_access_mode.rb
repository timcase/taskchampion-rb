# frozen_string_literal: true

require "test_helper"

class TestAccessMode < TaskchampionTest
  def test_access_mode_constructors
    read_only = Taskchampion::AccessMode.read_only
    read_write = Taskchampion::AccessMode.read_write

    assert_instance_of Taskchampion::AccessMode, read_only
    assert_instance_of Taskchampion::AccessMode, read_write
  end

  def test_access_mode_predicates
    read_only = Taskchampion::AccessMode.read_only
    read_write = Taskchampion::AccessMode.read_write

    assert read_only.read_only?
    refute read_only.read_write?
    
    assert read_write.read_write?
    refute read_write.read_only?
  end

  def test_access_mode_to_s
    assert_equal "read_only", Taskchampion::AccessMode.read_only.to_s
    assert_equal "read_write", Taskchampion::AccessMode.read_write.to_s
  end

  def test_access_mode_inspect
    assert_equal "#<Taskchampion::AccessMode:read_only>", Taskchampion::AccessMode.read_only.inspect
    assert_equal "#<Taskchampion::AccessMode:read_write>", Taskchampion::AccessMode.read_write.inspect
  end

  def test_access_mode_equality
    ro1 = Taskchampion::AccessMode.read_only
    ro2 = Taskchampion::AccessMode.read_only
    rw = Taskchampion::AccessMode.read_write

    assert_equal ro1, ro2
    refute_equal ro1, rw
  end

  def test_access_mode_constants_still_exist
    # For backward compatibility
    assert_equal :read_only, Taskchampion::READ_ONLY
    assert_equal :read_write, Taskchampion::READ_WRITE
  end
end