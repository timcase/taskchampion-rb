  🎯 Phase 3 Overview

  With the core ThreadBound architecture working and clean compilation achieved, Phase 3 focuses on:

  1. Completing missing method registrations (mutable methods in Operations)
  2. Implementing missing classes (WorkingSet, DependencyMap, Status, AccessMode)
  3. Adding comprehensive method coverage for all classes
  4. Ensuring Ruby-idiomatic API design
  5. Basic integration testing

  3.1: Fix Remaining Method Registration Issues

  Priority: HIGHTimeline: 1 dayCurrent Issue: Mutable methods in Operations class fail registration

  3.1.1: Resolve Mutable Method Registration

  Problem: Methods like push and clear that take &mut self don't register with method! macro in Magnus 0.7.

  Files Affected:
  - ext/taskchampion/src/operations.rs - Lines 90-92, 101

  Current Error Pattern:
  error[E0599]: the method `call_handle_error` exists for fn item `fn(&mut Operations, &Operation) -> Result<(), Error>
  {...::push}`, but its trait bounds were not satisfied

  Research Tasks:
  - Research Magnus 0.7 patterns for mutable methods
  - Check if different trait imports are needed
  - Investigate alternative registration approaches
  - Test with simplified mutable method signatures

  Fallback Strategy:
  If mutable methods can't be registered directly:
  - Create wrapper methods that return new instances instead of mutating
  - Use internal mutability patterns with RefCell if needed
  - Document limitations and plan for future Magnus versions

  3.1.2: Complete Operations API

  Goal: Full Operations class functionality

  Methods to implement:
  operations = Operations.new
  operations.push(operation)        # Add operation
  operations << operation           # Alias for push
  operations.clear                  # Clear all operations
  operations.length                 # Count operations
  operations[index]                 # Get operation by index
  operations.each {|op| ... }      # Iterate operations

  Success Criteria:
  - All Operations methods work without errors
  - Ruby-idiomatic API (<<, each, [])
  - Proper error handling for edge cases

  3.2: Implement Missing Core Classes

  Priority: HIGHTimeline: 2-3 daysCurrent Status: Classes exist but not fully implemented

  3.2.1: Complete Status Class

  Current File: ext/taskchampion/src/status.rsCurrent State: Basic enum, needs method registration

  TaskChampion Status Values:
  - Pending - Task is pending
  - Completed - Task is completed
  - Deleted - Task is deleted
  - Recurring - Task is recurring

  Ruby API Design:
  # Class methods
  Status.pending    # => Status instance
  Status.completed  # => Status instance
  Status.deleted    # => Status instance

  # Instance methods
  status.pending?   # => boolean
  status.completed? # => boolean
  status.to_s       # => "pending"
  status.inspect    # => "#<Taskchampion::Status:pending>"

  Implementation Tasks:
  - Add constructor methods (pending, completed, etc.)
  - Add predicate methods (pending?, completed?, etc.)
  - Add string conversion methods
  - Add equality and hash methods
  - Register all methods properly

  3.2.2: Complete AccessMode Class

  Current File: ext/taskchampion/src/access_mode.rsCurrent State: Basic enum, needs method registration

  TaskChampion AccessMode Values:
  - ReadOnly - Read-only access to replica
  - ReadWrite - Read-write access to replica

  Ruby API Design:
  # Class methods
  AccessMode.read_only   # => AccessMode instance
  AccessMode.read_write  # => AccessMode instance

  # Instance methods
  mode.read_only?   # => boolean
  mode.read_write?  # => boolean
  mode.to_s         # => "read_only"

  Implementation Tasks:
  - Add constructor methods
  - Add predicate methods
  - Add string conversion
  - Register all methods

  3.2.3: Implement WorkingSet Class

  Current File: Create ext/taskchampion/src/working_set.rsCurrent State: Missing - needs full implementation

  TaskChampion WorkingSet: Manages the current set of tasks being worked on.

  Ruby API Design:
  working_set = replica.working_set
  working_set.largest_index      # => Integer
  working_set.by_index(1)       # => Task or nil
  working_set.by_uuid(uuid)     # => Integer or nil
  working_set.renumber          # Renumber tasks

  Implementation Tasks:
  - Create WorkingSet struct with ThreadBound wrapper
  - Implement largest_index method
  - Implement by_index method
  - Implement by_uuid method
  - Implement renumber method
  - Add to module registration in lib.rs

  3.2.4: Implement DependencyMap Class

  Current File: Create ext/taskchampion/src/dependency_map.rsCurrent State: Missing - needs full implementation

  TaskChampion DependencyMap: Tracks task dependencies and relationships.

  Ruby API Design:
  dep_map = replica.dependency_map
  dep_map.dependencies(uuid)    # => Array of UUIDs
  dep_map.dependents(uuid)      # => Array of UUIDs
  dep_map.has_dependency?(uuid) # => boolean

  Implementation Tasks:
  - Create DependencyMap struct with ThreadBound wrapper
  - Implement dependencies method
  - Implement dependents method
  - Implement has_dependency? method
  - Add to module registration in lib.rs

  3.3: Complete Existing Class APIs

  Priority: MEDIUMTimeline: 2 daysCurrent State: Basic methods implemented, many missing

  3.3.1: Complete Task Class API

  Current File: ext/taskchampion/src/task.rsCurrent State: Read methods implemented, mutation methods stubbed

  Missing Methods:
  # Task modification (these currently return NotImplementedError)
  task.set_description(desc)
  task.set_status(status, operations)
  task.set_priority(priority, operations)
  task.add_tag(tag, operations)
  task.remove_tag(tag, operations)
  task.add_annotation(annotation, operations)
  task.set_due(datetime, operations)
  task.set_value(property, value, operations)
  task.set_uda(namespace, key, value, operations)
  task.delete_uda(namespace, key, operations)

  Implementation Strategy:
  All mutation methods require Operations parameter since they modify task state.

  Tasks:
  - Implement set_description method
  - Implement set_status method
  - Implement set_priority method
  - Implement tag manipulation methods
  - Implement annotation methods
  - Implement UDA (User Defined Attributes) methods
  - Implement date/time property methods
  - Add proper error handling and validation

  3.3.2: Complete Replica Class API

  Current File: ext/taskchampion/src/replica.rsCurrent State: Basic methods implemented, sync methods missing

  Missing Methods:
  # Task manipulation
  replica.create_task(uuid, operations)     # Currently stubbed
  replica.commit_operations(operations)     # Missing

  # Synchronization
  replica.sync_to_local(server_dir, avoid_snapshots: false)
  replica.sync_to_remote(url:, client_id:, encryption_secret:, avoid_snapshots: false)
  replica.sync_to_gcp(bucket:, credential_path:, encryption_secret:, avoid_snapshots: false)

  # Storage management
  replica.rebuild_working_set              # Missing
  replica.num_local_operations            # Missing
  replica.num_undo_points                 # Missing

  Tasks:
  - Complete create_task implementation
  - Implement commit_operations
  - Implement sync methods (local, remote, GCP)
  - Add storage management methods
  - Add proper keyword argument handling for sync methods

  3.3.3: Enhance Operation Class API

  Current File: ext/taskchampion/src/operation.rsCurrent State: Basic implementation, needs completion

  Ruby API Design:
  # Operation introspection
  operation.operation_type    # => Symbol (:create, :update, :delete)
  operation.uuid             # => String (task UUID)
  operation.property         # => String or nil
  operation.value            # => String or nil
  operation.old_value        # => String or nil
  operation.timestamp        # => Time

  # String representation
  operation.to_s             # => Human readable string
  operation.inspect          # => Debug representation

  Tasks:
  - Add operation type detection
  - Add property access methods
  - Add timestamp conversion
  - Improve string representations

  3.4: Ruby-Idiomatic API Polish

  Priority: MEDIUMTimeline: 1 dayGoal: Ensure API follows Ruby conventions

  3.4.1: Method Naming Conventions

  Ruby Conventions to Follow:
  # Good Ruby API design
  task.active?         # not task.is_active
  task.description     # not task.get_description
  task.uuid           # not task.get_uuid
  task.tags           # not task.get_tags

  # Mutation methods
  task.description = "new desc"  # Setter syntax
  task.status = :completed       # Using symbols

  # Collection methods
  operations.each {|op| ... }    # Block iteration
  operations.length              # not operations.size_hint
  operations[index]              # Array-like access
  operations << operation        # Append operator

  Tasks:
  - Review all method names for Ruby conventions
  - Add setter methods where appropriate
  - Ensure predicate methods end with ?
  - Add collection-style methods
  - Use symbols for enums where appropriate

  3.4.2: Error Handling Improvements

  Current State: Basic error mapping existsGoal: Comprehensive, helpful error messages

  Error Classes Needed:
  Taskchampion::Error              # Base error
  Taskchampion::ThreadError        # ✅ Already implemented
  Taskchampion::StorageError       # File system issues
  Taskchampion::ValidationError    # Invalid input
  Taskchampion::ConfigError        # Configuration issues
  Taskchampion::SyncError          # Synchronization failures

  Tasks:
  - Ensure all error classes are properly defined
  - Add helpful error messages with context
  - Map all TaskChampion Rust errors to appropriate Ruby errors
  - Add input validation with clear error messages

  3.4.3: Parameter Validation

  Goal: Prevent invalid input with clear error messages

  Validation Needed:
  # UUID validation
  replica.task("invalid-uuid")  # Should raise ValidationError

  # Status validation
  task.set_status(:invalid_status, ops)  # Should raise ValidationError

  # Date validation
  task.set_due("not-a-date", ops)  # Should raise ValidationError

  Tasks:
  - Add UUID format validation
  - Add enum value validation
  - Add date/time format validation
  - Add nil/empty string handling
  - Provide helpful error messages

  3.5: Integration Testing

  Priority: HIGHTimeline: 1 dayGoal: End-to-end functionality verification

  3.5.1: Comprehensive Test Suite

  Test Structure:
  test/
  ├── integration/
  │   ├── test_task_lifecycle.rb     # Create → Modify → Complete workflow
  │   ├── test_sync_operations.rb    # Sync functionality
  │   └── test_working_set.rb        # Working set management
  ├── unit/
  │   ├── test_operations.rb         # Operations class
  │   ├── test_status.rb            # Status enum
  │   ├── test_access_mode.rb       # AccessMode enum
  │   └── test_error_handling.rb    # Error scenarios
  └── performance/
      └── test_thread_safety.rb     # Stress test ThreadBound

  3.5.2: Task Lifecycle Integration Test

  Test Scenario: Complete task workflow
  def test_complete_task_workflow
    replica = Taskchampion::Replica.new_in_memory
    operations = Taskchampion::Operations.new

    # Create task
    uuid = SecureRandom.uuid
    task = replica.create_task(uuid, operations)

    # Modify task
    task.set_description("Buy groceries", operations)
    task.set_status(Taskchampion::Status.pending, operations)
    task.add_tag(Taskchampion::Tag.new("shopping"), operations)

    # Commit changes
    replica.commit_operations(operations)

    # Verify changes
    retrieved = replica.task(uuid)
    assert_equal "Buy groceries", retrieved.description
    assert retrieved.pending?
    assert retrieved.has_tag?(Taskchampion::Tag.new("shopping"))
  end

  3.5.3: Thread Safety Stress Test

  Goal: Verify ThreadBound under concurrent load

  Test Pattern:
  def test_concurrent_access_stress
    replica = Taskchampion::Replica.new_in_memory
    errors = []

    # Spawn 20 threads trying to access replica
    threads = 20.times.map do
      Thread.new do
        100.times do
          begin
            replica.task_uuids
            errors << "No error raised in #{Thread.current}"
          rescue Taskchampion::ThreadError
            # Expected - this is correct
          rescue => e
            errors << "Wrong error: #{e.class} - #{e.message}"
          end
        end
      end
    end

    threads.each(&:join)
    assert errors.empty?, "Thread safety issues: #{errors.first(5)}"
  end

  3.6: Documentation & Examples

  Priority: LOWTimeline: 1 dayGoal: Usable documentation

  3.6.1: API Reference Documentation

  Create Files:
  - docs/API_REFERENCE.md - Complete method documentation
  - docs/THREAD_SAFETY.md - ThreadBound usage guidelines
  - examples/basic_usage.rb - Common patterns
  - examples/sync_workflow.rb - Synchronization examples

  3.6.2: Usage Examples

  Basic Usage Example:
  # examples/basic_usage.rb
  require 'taskchampion'

  # Create task database
  replica = Taskchampion::Replica.new_on_disk("/tmp/tasks", create_if_missing: true)
  operations = Taskchampion::Operations.new

  # Create and modify tasks
  uuid1 = SecureRandom.uuid
  task = replica.create_task(uuid1, operations)
  task.set_description("Learn TaskChampion Ruby bindings", operations)
  task.set_status(Taskchampion::Status.pending, operations)

  # Commit changes
  replica.commit_operations(operations)

  # Query tasks
  all_uuids = replica.task_uuids
  puts "Total tasks: #{all_uuids.size}"

  🎯 Success Metrics

  Phase 3 Completion Criteria

  Technical Requirements:
  - All classes implemented with full API coverage
  - All method registrations working (including mutable methods)
  - Ruby-idiomatic interface throughout
  - Comprehensive error handling
  - Integration tests passing

  Quality Gates:
  - No compilation errors or warnings
  - All unit tests pass
  - Integration test suite passes
  - Thread safety stress tests pass
  - Memory usage reasonable (no obvious leaks)

  API Completeness:
  - Operations: push, clear, iteration work
  - Status: all enum values and predicates
  - AccessMode: read_only/read_write modes
  - WorkingSet: index-based task access
  - DependencyMap: dependency relationships
  - Task: full CRUD operations with Operations
  - Replica: create, commit, sync, storage management

  🚀 Getting Started with Phase 3

  Immediate Next Steps (Today)

  1. Start with 3.1.1: Research Magnus 0.7 mutable method patterns
  cd /home/tcase/Sites/reference/taskchampion-rb
  # Try enabling the commented-out methods one by one
  # Research Magnus examples and documentation
  2. Focus on Operations class: Get push and clear methods working
  3. Test incrementally: Each method should compile before moving to next

  Daily Progress Tracking

  Create progress files:
  - progress/phase3/2025-01-31.md - Document daily accomplishments
  - Track method completion count
  - Note any blockers or research needed

  Research Resources

  - Magnus 0.7 Documentation: https://docs.rs/magnus/0.7.1/magnus/
  - Magnus Examples: Look for mutable method patterns
  - TaskChampion API: https://docs.rs/taskchampion/2.0.2/taskchampion/
  - Ruby Extension Patterns: Mutable object handling

  🎉 Phase 3 Impact

  What Phase 3 Achieves:
  - Complete API: Full TaskChampion functionality available in Ruby
  - Production Ready: All major features implemented
  - Ruby Native Feel: Idiomatic Ruby interface
  - Robust Error Handling: Clear error messages and proper validation
  - Integration Ready: Can be used in real Ruby applications

  After Phase 3:
  - Ruby developers can use TaskChampion naturally
  - All major TaskChampion features accessible
  - Thread safety is transparent and reliable
  - Ready for community adoption and feedback

  The foundation is solid - now we build the complete experience! 🏗️
