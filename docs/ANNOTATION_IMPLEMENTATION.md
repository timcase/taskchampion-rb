# Annotation Management Implementation Plan

## Overview

This document outlines the implementation plan for adding `remove_annotation` and `update_annotation` methods to the TaskChampion Ruby bindings, enabling full annotation lifecycle management.

## Current State

### Existing Functionality

**Annotation Class** (`ext/taskchampion/src/annotation.rs`)
- Wraps TaskChampion Rust library's `Annotation` type
- Properties:
  - `entry`: DateTime timestamp when annotation was created
  - `description`: Text content of the annotation
- Methods: `new`, `entry`, `description`, `to_s`, `inspect`, `eql?`, `hash`

**Task Methods** (`ext/taskchampion/src/task.rs`)
- `task.annotations` - Returns array of Annotation objects (read-only)
- `task.add_annotation(description, operations)` - Adds new annotation with auto-generated timestamp

### Limitations
- No way to remove annotations once added
- No way to edit/update existing annotations
- Annotations are effectively append-only

## Design Decisions

### Decision 1: API for `remove_annotation`
**Chosen: Option A - Pass full Annotation object**

```ruby
annotation = task.annotations.first
task.remove_annotation(annotation, operations)
```

**Rationale:**
- Most Ruby-idiomatic approach
- User doesn't need to extract timestamp manually
- Mirrors standard Ruby collection methods (e.g., `Array#delete`)
- Consistent with Ruby's object-oriented design

**Alternatives Considered:**
- Option B: Pass timestamp only - More explicit but less intuitive
- Option C: Support both - Added complexity without significant benefit

### Decision 2: Method Name for Editing
**Chosen: Option A - `update_annotation`**

```ruby
task.update_annotation(annotation, "Updated description", operations)
```

**Rationale:**
- Matches Rails/Ruby conventions (ActiveRecord uses `update`)
- Clearly indicates modification intent
- Common pattern in Ruby APIs

**Alternatives Considered:**
- `edit_annotation` - More conversational but less conventional
- `replace_annotation` - More accurate to implementation but unfamiliar
- No convenience method - Too low-level for common use case

### Decision 3: Timestamp Preservation
**Chosen: Option A - Preserve original timestamp**

When updating an annotation, the original `entry` timestamp is preserved.

```ruby
annotation = task.annotations.first  # entry: 2025-01-15 10:00:00
task.update_annotation(annotation, "Updated text", operations)
# Result: entry still shows 2025-01-15 10:00:00
```

**Rationale:**
- Maintains chronological history (shows when annotation was originally created)
- Audit trail remains intact
- Aligns with TaskWarrior philosophy of immutable timestamps
- Users can see historical context even after editing

**Alternatives Considered:**
- Update to current timestamp - Loses original creation time
- User choice via parameter - Added API complexity

### Decision 4: Implementation Location
**Chosen: Option A - Pure Ruby wrapper in `lib/taskchampion.rb`**

```ruby
class Task
  def update_annotation(annotation, new_description, operations)
    remove_annotation(annotation, operations)
    add_annotation(new_description, operations)
  end
end
```

**Rationale:**
- Easier to implement and maintain
- Transparent implementation (users can see it's remove + add)
- No Rust compilation needed for changes
- Adequate performance for this use case

**Alternatives Considered:**
- Rust implementation - More atomic but adds complexity

### Decision 5: Error Handling
**Chosen: Option A - Silent success (match Rust behavior)**

Attempting to remove a non-existent annotation succeeds silently without error.

```ruby
task.remove_annotation(non_existent_annotation, operations)
# No error - operation succeeds even if annotation doesn't exist
```

**Rationale:**
- Matches underlying Rust library behavior
- Idempotent (safe to call multiple times)
- Simple implementation
- Consistent with underlying system design

**Alternatives Considered:**
- Raise ValidationError - More defensive but inconsistent with Rust layer
- Return boolean - Less Ruby-idiomatic

## Implementation Details

### 1. Rust Extension Changes

**File:** `ext/taskchampion/src/task.rs`

Add `remove_annotation` method:

```rust
fn remove_annotation(&self, annotation: &Annotation, operations: &crate::operations::Operations) -> Result<(), Error> {
    let mut task = self.0.get_mut()?;
    let entry_timestamp = annotation.0.entry;

    operations.with_inner_mut(|ops| {
        task.remove_annotation(entry_timestamp, ops)
    })?;
    Ok(())
}
```

Register in `init()` function:

```rust
class.define_method("remove_annotation", method!(Task::remove_annotation, 2))?;
```

### 2. Ruby Wrapper Changes

**File:** `lib/taskchampion.rb`

Add to Task class:

```ruby
class Task
  # Update an existing annotation's description while preserving its timestamp
  #
  # @param annotation [Taskchampion::Annotation] The annotation to update
  # @param new_description [String] The new description text
  # @param operations [Taskchampion::Operations] Operations collection
  # @return [void]
  #
  # @example
  #   annotation = task.annotations.first
  #   task.update_annotation(annotation, "Updated note", operations)
  #   replica.commit_operations(operations)
  #
  def update_annotation(annotation, new_description, operations)
    # Remove the old annotation
    remove_annotation(annotation, operations)

    # Add new annotation with preserved timestamp
    # Note: add_annotation creates a new timestamp, so we need to use the lower-level API
    # This preserves the original entry time
    entry_time = annotation.entry
    new_ann = Taskchampion::Annotation.new(entry_time, new_description)

    # We need to expose add_annotation that accepts an Annotation object
    # For now, document that timestamp preservation requires the annotation
    # to be removed and re-added with the same timestamp
    remove_annotation(annotation, operations)

    # Create new annotation with same timestamp
    # This will require modifying add_annotation to accept either:
    # 1. A description string (current behavior - auto timestamp)
    # 2. An Annotation object (new behavior - preserve timestamp)
  end
end
```

**Note:** This reveals we need to modify `add_annotation` to support passing an Annotation object directly, or add a separate lower-level method.

### 3. Revised Implementation Approach

Given the need to preserve timestamps, we have two options:

#### Option A: Modify `add_annotation` to accept Annotation objects

```rust
// In task.rs, modify add_annotation signature
fn add_annotation(&self, arg: Value, operations: &Operations) -> Result<(), Error> {
    let mut task = self.0.get_mut()?;

    // Check if arg is an Annotation object or a String
    if let Ok(annotation) = <&Annotation>::try_convert(arg) {
        // User passed an Annotation object - use its timestamp
        operations.with_inner_mut(|ops| {
            task.add_annotation(annotation.0.clone(), ops)
        })?;
    } else if let Ok(description) = String::try_convert(arg) {
        // User passed a string - create new annotation with current time
        // ... existing implementation ...
    } else {
        return Err(Error::new(
            crate::error::validation_error(),
            "add_annotation expects an Annotation object or description string"
        ));
    }
    Ok(())
}
```

#### Option B: Add separate `add_annotation_with_timestamp` method

```rust
fn add_annotation_with_timestamp(
    &self,
    timestamp: Value,
    description: String,
    operations: &Operations
) -> Result<(), Error> {
    let mut task = self.0.get_mut()?;
    let entry = ruby_to_datetime(timestamp)?;

    let annotation = taskchampion::Annotation {
        entry,
        description
    };

    operations.with_inner_mut(|ops| {
        task.add_annotation(annotation, ops)
    })?;
    Ok(())
}
```

Then Ruby wrapper:

```ruby
def update_annotation(annotation, new_description, operations)
  remove_annotation(annotation, operations)
  add_annotation_with_timestamp(annotation.entry, new_description, operations)
end
```

**Recommendation:** Option B is cleaner and maintains backward compatibility.

### 4. Testing Strategy

**File:** `test/test_task.rb`

```ruby
def test_remove_annotation
  replica = Taskchampion::Replica.new_in_memory
  operations = Taskchampion::Operations.new

  uuid = SecureRandom.uuid
  task = replica.create_task(uuid, operations)
  task.set_description("Test task", operations)

  # Add annotations
  task.add_annotation("First note", operations)
  task.add_annotation("Second note", operations)
  replica.commit_operations(operations)

  # Verify both exist
  retrieved = replica.task(uuid)
  assert_equal 2, retrieved.annotations.length

  # Remove first annotation
  ops2 = Taskchampion::Operations.new
  annotation_to_remove = retrieved.annotations.first
  retrieved.remove_annotation(annotation_to_remove, ops2)
  replica.commit_operations(ops2)

  # Verify only one remains
  final = replica.task(uuid)
  assert_equal 1, final.annotations.length
  assert_equal "Second note", final.annotations.first.description
end

def test_remove_annotation_nonexistent
  replica = Taskchampion::Replica.new_in_memory
  operations = Taskchampion::Operations.new

  uuid = SecureRandom.uuid
  task = replica.create_task(uuid, operations)
  task.set_description("Test task", operations)
  task.add_annotation("Note", operations)
  replica.commit_operations(operations)

  # Create annotation with different timestamp
  fake_annotation = Taskchampion::Annotation.new(
    DateTime.now + 1,
    "Doesn't exist"
  )

  # Should not raise error
  ops2 = Taskchampion::Operations.new
  retrieved = replica.task(uuid)
  assert_nothing_raised do
    retrieved.remove_annotation(fake_annotation, ops2)
  end
  replica.commit_operations(ops2)

  # Original annotation should still exist
  final = replica.task(uuid)
  assert_equal 1, final.annotations.length
end

def test_update_annotation
  replica = Taskchampion::Replica.new_in_memory
  operations = Taskchampion::Operations.new

  uuid = SecureRandom.uuid
  task = replica.create_task(uuid, operations)
  task.set_description("Test task", operations)
  task.add_annotation("Original note", operations)
  replica.commit_operations(operations)

  # Get annotation and note its timestamp
  retrieved = replica.task(uuid)
  annotation = retrieved.annotations.first
  original_timestamp = annotation.entry

  # Update annotation
  ops2 = Taskchampion::Operations.new
  retrieved.update_annotation(annotation, "Updated note", ops2)
  replica.commit_operations(ops2)

  # Verify description changed but timestamp preserved
  final = replica.task(uuid)
  assert_equal 1, final.annotations.length
  updated = final.annotations.first
  assert_equal "Updated note", updated.description

  # Timestamp should be preserved (within 1 second tolerance)
  time_diff = (updated.entry.to_time - original_timestamp.to_time).abs
  assert time_diff < 1, "Timestamp should be preserved"
end

def test_update_annotation_empty_description
  replica = Taskchampion::Replica.new_in_memory
  operations = Taskchampion::Operations.new

  uuid = SecureRandom.uuid
  task = replica.create_task(uuid, operations)
  task.set_description("Test task", operations)
  task.add_annotation("Note", operations)
  replica.commit_operations(operations)

  retrieved = replica.task(uuid)
  annotation = retrieved.annotations.first

  # Should raise validation error for empty description
  ops2 = Taskchampion::Operations.new
  assert_raises Taskchampion::ValidationError do
    retrieved.update_annotation(annotation, "", ops2)
  end

  assert_raises Taskchampion::ValidationError do
    retrieved.update_annotation(annotation, "   ", ops2)
  end
end
```

**File:** `test/integration/test_task_lifecycle.rb`

```ruby
def test_annotation_removal_workflow
  # Create task with multiple annotations
  uuid = SecureRandom.uuid
  task = @replica.create_task(uuid, @operations)
  task.set_description("Task with annotations", @operations)

  task.add_annotation("First annotation", @operations)
  task.add_annotation("Second annotation", @operations)
  task.add_annotation("Third annotation", @operations)
  @replica.commit_operations(@operations)

  # Remove middle annotation
  retrieved = @replica.task(uuid)
  annotations = retrieved.annotations.sort_by(&:entry)
  middle_annotation = annotations[1]

  ops2 = Taskchampion::Operations.new
  retrieved.remove_annotation(middle_annotation, ops2)
  @replica.commit_operations(ops2)

  # Verify correct annotation was removed
  final = @replica.task(uuid)
  assert_equal 2, final.annotations.length
  remaining_descriptions = final.annotations.map(&:description)
  assert_includes remaining_descriptions, "First annotation"
  assert_includes remaining_descriptions, "Third annotation"
  refute_includes remaining_descriptions, "Second annotation"
end

def test_annotation_update_workflow
  # Create task with annotation
  uuid = SecureRandom.uuid
  task = @replica.create_task(uuid, @operations)
  task.set_description("Task to update", @operations)
  task.add_annotation("Original text", @operations)
  @replica.commit_operations(@operations)

  # Update annotation multiple times
  retrieved = @replica.task(uuid)
  annotation = retrieved.annotations.first
  original_entry = annotation.entry

  ops2 = Taskchampion::Operations.new
  retrieved.update_annotation(annotation, "First update", ops2)
  @replica.commit_operations(ops2)

  retrieved2 = @replica.task(uuid)
  annotation2 = retrieved2.annotations.first
  assert_equal "First update", annotation2.description

  ops3 = Taskchampion::Operations.new
  retrieved2.update_annotation(annotation2, "Second update", ops3)
  @replica.commit_operations(ops3)

  # Verify final state
  final = @replica.task(uuid)
  assert_equal 1, final.annotations.length
  final_annotation = final.annotations.first
  assert_equal "Second update", final_annotation.description

  # Verify timestamp preserved through multiple updates
  time_diff = (final_annotation.entry.to_time - original_entry.to_time).abs
  assert time_diff < 1, "Original timestamp should be preserved"
end
```

### 5. Documentation Updates

**File:** `docs/API_REFERENCE.md`

Add to Annotation Management section:

```markdown
#### Annotation Management

```ruby
# Add annotation
task.add_annotation("Added note", operations)

# Remove annotation
annotation = task.annotations.first
task.remove_annotation(annotation, operations)

# Update annotation (preserves original timestamp)
annotation = task.annotations.find { |a| a.description.include?("old text") }
task.update_annotation(annotation, "New text", operations)

# Commit changes
replica.commit_operations(operations)
```

**Method Reference:**

##### `task.remove_annotation(annotation, operations)`

Removes an annotation from the task. Identified by the annotation's entry timestamp.

- **Parameters:**
  - `annotation` (Taskchampion::Annotation) - The annotation to remove
  - `operations` (Taskchampion::Operations) - Operations collection
- **Returns:** `nil`
- **Raises:** None (silently succeeds if annotation doesn't exist)
- **Example:**
  ```ruby
  annotation = task.annotations.first
  task.remove_annotation(annotation, operations)
  replica.commit_operations(operations)
  ```

##### `task.update_annotation(annotation, new_description, operations)`

Updates an annotation's description while preserving its original timestamp.

- **Parameters:**
  - `annotation` (Taskchampion::Annotation) - The annotation to update
  - `new_description` (String) - The new description text
  - `operations` (Taskchampion::Operations) - Operations collection
- **Returns:** `nil`
- **Raises:**
  - `Taskchampion::ValidationError` - If new_description is empty or whitespace-only
- **Example:**
  ```ruby
  annotation = task.annotations.first
  task.update_annotation(annotation, "Updated note", operations)
  replica.commit_operations(operations)
  ```
- **Note:** This is a convenience method that removes the old annotation and adds a new one with the same timestamp, preserving the chronological history.
```

### 6. Example Code Updates

**File:** `examples/basic_usage.rb`

Add section after annotation display (around line 110):

```ruby
  # 5b. REMOVING AND UPDATING ANNOTATIONS
  puts "\n5b. Removing and updating annotations"

  # Get a task with annotations
  task_with_ann = replica.task(uuid1)
  if task_with_ann && !task_with_ann.annotations.empty?
    puts "Original annotations: #{task_with_ann.annotations.length}"
    task_with_ann.annotations.each do |ann|
      puts "  - [#{ann.entry.strftime('%H:%M:%S')}] #{ann.description}"
    end

    # Update first annotation
    operations_ann = Taskchampion::Operations.new
    first_ann = task_with_ann.annotations.first
    original_time = first_ann.entry

    puts "\nUpdating first annotation..."
    task_with_ann.update_annotation(first_ann, "Updated: Started learning TaskChampion", operations_ann)
    replica.commit_operations(operations_ann)

    # Verify update
    task_updated = replica.task(uuid1)
    updated_ann = task_updated.annotations.first
    puts "Updated annotation: #{updated_ann.description}"
    puts "Timestamp preserved: #{updated_ann.entry == original_time}"

    # Add another annotation then remove it
    operations_ann2 = Taskchampion::Operations.new
    task_updated.add_annotation("Temporary note", operations_ann2)
    replica.commit_operations(operations_ann2)

    task_temp = replica.task(uuid1)
    puts "\nAnnotations after adding temporary: #{task_temp.annotations.length}"

    # Remove the temporary annotation
    operations_ann3 = Taskchampion::Operations.new
    temp_ann = task_temp.annotations.find { |a| a.description == "Temporary note" }
    task_temp.remove_annotation(temp_ann, operations_ann3) if temp_ann
    replica.commit_operations(operations_ann3)

    task_final = replica.task(uuid1)
    puts "Annotations after removal: #{task_final.annotations.length}"
  end
```

## Implementation Checklist

### Phase 1: Core `remove_annotation` Implementation
- [ ] Add `remove_annotation` Rust method in `ext/taskchampion/src/task.rs`
- [ ] Register method in `init()` function
- [ ] Add `add_annotation_with_timestamp` Rust method for timestamp preservation
- [ ] Register `add_annotation_with_timestamp` in `init()` function
- [ ] Run `bundle exec rake compile` to build extension
- [ ] Add unit tests in `test/test_task.rb`
- [ ] Run tests: `bundle exec rake test TEST=test/test_task.rb`

### Phase 2: Ruby `update_annotation` Wrapper
- [ ] Add `update_annotation` method to Task class in `lib/taskchampion.rb`
- [ ] Add comprehensive unit tests for update functionality
- [ ] Add integration tests in `test/integration/test_task_lifecycle.rb`
- [ ] Run full test suite: `bundle exec rake test`

### Phase 3: Documentation & Examples
- [ ] Update `docs/API_REFERENCE.md` with new methods
- [ ] Add usage examples to `examples/basic_usage.rb`
- [ ] Run example to verify: `ruby examples/basic_usage.rb`
- [ ] Update CHANGELOG.md with new features

### Phase 4: Code Quality
- [ ] Run RuboCop: `bundle exec rake rubocop`
- [ ] Fix any linting issues
- [ ] Review error messages for clarity
- [ ] Ensure consistent code style

## Potential Future Enhancements

### 1. Batch Operations
Add methods for bulk annotation management:

```ruby
task.remove_annotations(annotations_array, operations)
task.update_annotations(annotation_updates_hash, operations)
```

### 2. Annotation Filtering
Add helper methods for finding annotations:

```ruby
task.find_annotation { |a| a.description.include?("text") }
task.annotations_since(datetime)
task.annotations_matching(pattern)
```

### 3. Annotation History
Track annotation changes through operations log:

```ruby
task.annotation_history  # Returns timeline of all annotation changes
```

## Estimated Implementation Time

- **Phase 1 (Rust methods):** 1-2 hours
- **Phase 2 (Ruby wrapper & tests):** 1-2 hours
- **Phase 3 (Documentation):** 30-60 minutes
- **Phase 4 (Polish):** 30 minutes

**Total:** 3-5 hours

## Notes & Considerations

1. **Thread Safety:** All methods maintain thread-bound safety through existing ThreadBound wrapper
2. **Backward Compatibility:** All changes are additive - no breaking changes to existing API
3. **Performance:** Ruby wrapper approach adds minimal overhead; acceptable for typical use cases
4. **Synchronization:** All changes tracked through Operations system for replica sync
5. **Validation:** Leverages existing validation in `add_annotation` for description validation

## References

- TaskChampion Rust library: `/home/tcase/Sites/reference/taskchampion`
- Existing annotation implementation: `ext/taskchampion/src/annotation.rs`
- Task implementation: `ext/taskchampion/src/task.rs`
- Current tests: `test/test_task.rb`, `test/integration/test_task_lifecycle.rb`
