# TaskChampion Ruby API Reference

This document provides comprehensive API documentation for the TaskChampion Ruby bindings.

## Core Classes

### Taskchampion::Replica

The main entry point for TaskChampion functionality. Manages task storage and synchronization.

#### Constructor Methods

```ruby
# Create an in-memory replica (for testing)
replica = Taskchampion::Replica.new_in_memory

# Create a disk-based replica
replica = Taskchampion::Replica.new_on_disk("/path/to/tasks", create_if_missing: true)
```

#### Task Management

```ruby
# Get all task UUIDs
uuids = replica.task_uuids  # => Array of String UUIDs

# Get a specific task by UUID
task = replica.task(uuid)  # => Task or nil

# Create a new task
operations = Taskchampion::Operations.new
task = replica.create_task(uuid, operations)  # => Task

# Commit operations to storage
replica.commit_operations(operations)
```

#### Working Set Management

```ruby
# Get the working set
working_set = replica.working_set  # => WorkingSet

# Rebuild working set indices
replica.rebuild_working_set
```

#### Dependency Management

```ruby
# Get dependency map
dep_map = replica.dependency_map(rebuild: false)  # => DependencyMap
```

#### Synchronization

```ruby
# Sync to local directory
replica.sync_to_local(server_dir, avoid_snapshots: false)

# Sync to remote server
replica.sync_to_remote(
  url: "https://taskserver.example.com",
  client_id: "client-123",
  encryption_secret: "secret",
  avoid_snapshots: false
)

# Sync to Google Cloud Storage
replica.sync_to_gcp(
  bucket: "my-tasks-bucket",
  credential_path: "/path/to/credentials.json",
  encryption_secret: "secret",
  avoid_snapshots: false
)
```

#### Storage Information

```ruby
# Get number of local operations
count = replica.num_local_operations  # => Integer

# Get number of undo points
count = replica.num_undo_points  # => Integer
```

### Taskchampion::Task

Represents a single task with all its properties.

#### Property Access

```ruby
# Basic properties
task.uuid         # => String
task.description  # => String or nil
task.status       # => Status
task.priority     # => String or nil

# Date properties
task.entry        # => Time or nil
task.modified     # => Time or nil
task.start        # => Time or nil
task.end          # => Time or nil
task.due          # => Time or nil
task.until        # => Time or nil
task.wait         # => Time or nil

# Collections
task.tags         # => Array of Tag
task.annotations  # => Array of Annotation
task.dependencies # => Array of String (UUIDs)

# User Defined Attributes (UDAs)
task.uda(namespace, key)  # => String or nil
task.udas  # => Hash of all UDAs

# Custom properties
task.value(property)  # => String or nil
```

#### Task Modification

All modification methods require an Operations object:

```ruby
operations = Taskchampion::Operations.new

# Basic modifications
task.set_description("New description", operations)
task.set_status(Taskchampion::Status.completed, operations)
task.set_priority("H", operations)  # H, M, L, or nil

# Date modifications
task.set_due(Time.now + 86400, operations)  # Due tomorrow
task.set_start(Time.now, operations)
task.set_end(Time.now, operations)

# Tag management
task.add_tag(Taskchampion::Tag.new("work"), operations)
task.remove_tag(Taskchampion::Tag.new("work"), operations)

# Annotation management
annotation = Taskchampion::Annotation.new(Time.now, "Added note")
task.add_annotation(annotation, operations)

# UDA management
task.set_uda("namespace", "key", "value", operations)
task.delete_uda("namespace", "key", operations)

# Custom properties
task.set_value("custom_property", "value", operations)

# Don't forget to commit!
replica.commit_operations(operations)
```

#### Status Checking

```ruby
# Status predicates
task.active?      # => Boolean (pending or recurring)
task.pending?     # => Boolean
task.completed?   # => Boolean
task.deleted?     # => Boolean
task.recurring?   # => Boolean

# Tag checking
task.has_tag?(Taskchampion::Tag.new("work"))  # => Boolean
```

### Taskchampion::Operations

Collects task modifications before committing them to storage.

```ruby
# Create new operations collection
operations = Taskchampion::Operations.new

# Add operations (done automatically by task modification methods)
# operations.push(operation)  # Usually not called directly

# Collection interface
operations.length           # => Integer
operations[index]           # => Operation
operations.each {|op| ... } # Block iteration
operations << operation     # Append operation
operations.clear            # Remove all operations
```

### Taskchampion::Operation

Represents a single task modification operation.

```ruby
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
```

### Taskchampion::Status

Enumeration of task status values.

```ruby
# Status constants
status = Taskchampion::Status.pending    # => Status
status = Taskchampion::Status.completed  # => Status
status = Taskchampion::Status.deleted    # => Status
status = Taskchampion::Status.recurring  # => Status

# Status predicates
status.pending?    # => Boolean
status.completed?  # => Boolean
status.deleted?    # => Boolean
status.recurring?  # => Boolean

# String conversion
status.to_s        # => "pending", "completed", etc.
status.inspect     # => "#<Taskchampion::Status:pending>"
```

### Taskchampion::AccessMode

Enumeration of replica access modes.

```ruby
# Access mode constants
mode = Taskchampion::AccessMode.read_only   # => AccessMode
mode = Taskchampion::AccessMode.read_write  # => AccessMode

# Access mode predicates
mode.read_only?   # => Boolean
mode.read_write?  # => Boolean

# String conversion
mode.to_s         # => "read_only" or "read_write"
```

### Taskchampion::Tag

Represents a task tag.

```ruby
# Create tags
tag = Taskchampion::Tag.new("work")
tag = Taskchampion::Tag.new("project:website")

# Access tag name
tag.name          # => String
tag.to_s          # => String (same as name)

# Equality
tag1 == tag2      # => Boolean
```

### Taskchampion::Annotation

Represents a task annotation with timestamp and description.

```ruby
# Create annotations
annotation = Taskchampion::Annotation.new(Time.now, "Added note")

# Access properties
annotation.entry        # => Time
annotation.description  # => String

# String conversion
annotation.to_s         # => "2024-01-31 12:00:00 Added note"
```

### Taskchampion::WorkingSet

Manages the current set of tasks being worked on with index-based access.

```ruby
# Get working set from replica
working_set = replica.working_set

# Index management
largest = working_set.largest_index    # => Integer

# Task access by index
task = working_set.by_index(1)         # => Task or nil

# UUID to index mapping
index = working_set.by_uuid(uuid)      # => Integer or nil

# Renumber tasks
working_set.renumber
```

### Taskchampion::DependencyMap

Tracks task dependencies and relationships.

```ruby
# Get dependency map from replica
dep_map = replica.dependency_map(rebuild: false)

# Get task dependencies (tasks this task depends on)
deps = dep_map.dependencies(uuid)      # => Array of String (UUIDs)

# Get task dependents (tasks that depend on this task)
dependents = dep_map.dependents(uuid)  # => Array of String (UUIDs)

# Check if task has dependencies
has_deps = dep_map.has_dependency?(uuid)  # => Boolean
```

## Error Classes

### Taskchampion::Error

Base class for all TaskChampion errors.

### Taskchampion::ThreadError

Raised when attempting to access TaskChampion objects from the wrong thread.

```ruby
begin
  # This will fail if called from wrong thread
  replica.task_uuids
rescue Taskchampion::ThreadError => e
  puts "Thread safety violation: #{e.message}"
end
```

### Taskchampion::StorageError

Raised for file system and storage-related errors.

### Taskchampion::ValidationError

Raised for invalid input or parameter validation failures.

### Taskchampion::ConfigError

Raised for configuration-related errors.

### Taskchampion::SyncError

Raised for synchronization failures.

## Thread Safety

**Important**: All TaskChampion objects are thread-bound and can only be used from the thread that created them. Attempting to access objects from other threads will raise `Taskchampion::ThreadError`.

See [THREAD_SAFETY.md](THREAD_SAFETY.md) for detailed thread safety guidelines.

## Common Patterns

### Creating and Modifying Tasks

```ruby
replica = Taskchampion::Replica.new_on_disk("/path/to/tasks")
operations = Taskchampion::Operations.new

# Create task
uuid = SecureRandom.uuid
task = replica.create_task(uuid, operations)
task.set_description("Buy groceries", operations)
task.set_status(Taskchampion::Status.pending, operations)
task.add_tag(Taskchampion::Tag.new("errands"), operations)

# Commit changes
replica.commit_operations(operations)
```

### Querying Tasks

```ruby
# Get all tasks
all_uuids = replica.task_uuids
tasks = all_uuids.map { |uuid| replica.task(uuid) }.compact

# Filter tasks
pending_tasks = tasks.select(&:pending?)
work_tasks = tasks.select { |t| t.has_tag?(Taskchampion::Tag.new("work")) }
```

### Working with Operations

```ruby
# Group multiple changes
operations = Taskchampion::Operations.new

tasks.each do |task|
  if task.pending? && task.priority.nil?
    task.set_priority("M", operations)
  end
end

# Commit all changes at once
replica.commit_operations(operations)
```

### Error Handling

```ruby
begin
  replica = Taskchampion::Replica.new_on_disk("/invalid/path")
rescue Taskchampion::StorageError => e
  puts "Storage error: #{e.message}"
rescue Taskchampion::Error => e
  puts "TaskChampion error: #{e.message}"
end
```
