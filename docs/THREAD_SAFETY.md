# Thread Safety in TaskChampion Ruby

TaskChampion Ruby bindings implement strict thread safety through a **ThreadBound** pattern. This document explains how thread safety works and how to use TaskChampion safely in multi-threaded applications.

## Overview

**All TaskChampion objects are thread-bound** - they can only be used from the thread that created them. Attempting to access objects from other threads will raise `Taskchampion::ThreadError`.

## Why Thread Binding?

1. **Memory Safety**: TaskChampion's Rust core uses non-thread-safe data structures for performance
2. **Consistency**: Prevents race conditions and data corruption
3. **Predictability**: Clear ownership model - objects belong to their creating thread
4. **Performance**: Avoids overhead of locks and synchronization

## Thread-Bound Objects

The following objects are thread-bound:

- `Taskchampion::Replica`
- `Taskchampion::Task`
- `Taskchampion::Operations`
- `Taskchampion::WorkingSet`
- `Taskchampion::DependencyMap`
- `Taskchampion::Operation`

Value objects (Status, AccessMode, Tag, Annotation) are **not** thread-bound and can be shared between threads.

## Safe Usage Patterns

### ✅ Single Thread Usage (Recommended)

```ruby
# All operations in one thread - always safe
replica = Taskchampion::Replica.new_on_disk("/path/to/tasks")
operations = Taskchampion::Operations.new

# Create and modify tasks
uuid = SecureRandom.uuid
task = replica.create_task(uuid, operations)
task.set_description("My task", operations)
replica.commit_operations(operations)

# Query tasks
tasks = replica.task_uuids.map { |id| replica.task(id) }
```

### ✅ One Replica Per Thread

```ruby
# Each thread gets its own replica - safe
threads = 5.times.map do |i|
  Thread.new do
    # Each thread creates its own replica
    replica = Taskchampion::Replica.new_on_disk("/path/to/tasks#{i}")
    operations = Taskchampion::Operations.new

    # Work with replica in this thread
    uuid = SecureRandom.uuid
    task = replica.create_task(uuid, operations)
    task.set_description("Thread #{i} task", operations)
    replica.commit_operations(operations)
  end
end

threads.each(&:join)
```

### ✅ Shared File System with Separate Replicas

```ruby
# Multiple replicas can share the same task database file
# Each thread has its own replica instance
threads = 3.times.map do |i|
  Thread.new do
    # Same database path, different replica instances
    replica = Taskchampion::Replica.new_on_disk("/shared/tasks")

    # Each thread works independently
    uuids = replica.task_uuids
    puts "Thread #{i}: Found #{uuids.length} tasks"
  end
end

threads.each(&:join)
```

## Unsafe Patterns to Avoid

### ❌ Sharing Replica Between Threads

```ruby
# DON'T DO THIS - will raise ThreadError
replica = Taskchampion::Replica.new_on_disk("/path/to/tasks")

thread = Thread.new do
  # This will raise Taskchampion::ThreadError
  replica.task_uuids
end

thread.join
```

### ❌ Passing Tasks Between Threads

```ruby
# DON'T DO THIS - tasks are bound to their creating thread
replica = Taskchampion::Replica.new_on_disk("/path/to/tasks")
task = replica.task(some_uuid)

thread = Thread.new do
  # This will raise Taskchampion::ThreadError
  task.description
end

thread.join
```

### ❌ Sharing Operations Between Threads

```ruby
# DON'T DO THIS - operations are thread-bound
operations = Taskchampion::Operations.new

thread = Thread.new do
  # This will raise Taskchampion::ThreadError
  operations.length
end

thread.join
```

## Error Handling

When thread safety is violated, TaskChampion raises `Taskchampion::ThreadError`:

```ruby
replica = Taskchampion::Replica.new_on_disk("/path/to/tasks")

thread = Thread.new do
  begin
    replica.task_uuids
  rescue Taskchampion::ThreadError => e
    puts "Thread safety violation: #{e.message}"
    # Message will be something like:
    # "Replica was created on a different thread than the current one"
  end
end

thread.join
```

## Multi-threaded Application Patterns

### Pattern 1: Thread Pool with Per-Thread Replicas

```ruby
class TaskProcessor
  def initialize(db_path)
    @db_path = db_path
    @replica = nil
  end

  def process_tasks
    # Create replica in worker thread
    @replica ||= Taskchampion::Replica.new_on_disk(@db_path)

    # Process tasks in this thread
    @replica.task_uuids.each do |uuid|
      task = @replica.task(uuid)
      process_task(task) if task&.pending?
    end
  end

  private

  def process_task(task)
    operations = Taskchampion::Operations.new
    # ... modify task ...
    @replica.commit_operations(operations)
  end
end

# Each thread gets its own processor
threads = 5.times.map do
  Thread.new do
    processor = TaskProcessor.new("/shared/tasks")
    processor.process_tasks
  end
end

threads.each(&:join)
```

### Pattern 2: Producer-Consumer with UUIDs

```ruby
require 'thread'

# Share UUIDs between threads, not objects
uuid_queue = Queue.new

# Producer thread
producer = Thread.new do
  replica = Taskchampion::Replica.new_on_disk("/path/to/tasks")

  replica.task_uuids.each do |uuid|
    uuid_queue << uuid
  end

  uuid_queue << nil # Signal end
end

# Consumer threads
consumers = 3.times.map do
  Thread.new do
    # Each consumer has its own replica
    replica = Taskchampion::Replica.new_on_disk("/path/to/tasks")

    while (uuid = uuid_queue.pop)
      task = replica.task(uuid)
      puts "Processing: #{task&.description}" if task
    end
  end
end

[producer, *consumers].each(&:join)
```

### Pattern 3: Web Application Request Handling

```ruby
# In a web framework like Sinatra or Rails
class TaskController
  def show_task(uuid)
    # Create replica per request (could be cached per thread)
    replica = Taskchampion::Replica.new_on_disk(db_path)
    task = replica.task(uuid)

    if task
      render_task(task)
    else
      render_not_found
    end
  end

  def update_task(uuid, params)
    replica = Taskchampion::Replica.new_on_disk(db_path)
    task = replica.task(uuid)

    return render_not_found unless task

    operations = Taskchampion::Operations.new
    task.set_description(params[:description], operations) if params[:description]
    task.set_priority(params[:priority], operations) if params[:priority]

    replica.commit_operations(operations)
    render_task(task)
  end
end
```

## Performance Considerations

### Replica Creation Cost

Creating replicas has some overhead. Consider:

```ruby
# Expensive - creates replica per operation
def get_task_count
  replica = Taskchampion::Replica.new_on_disk("/path/to/tasks")
  replica.task_uuids.length
end

# Better - reuse replica in same thread
class TaskService
  def initialize
    @replica = Taskchampion::Replica.new_on_disk("/path/to/tasks")
  end

  def task_count
    @replica.task_uuids.length
  end

  def find_task(uuid)
    @replica.task(uuid)
  end
end
```

### Thread-Local Storage

```ruby
# Use thread-local storage for replica instances
class TaskService
  def self.replica
    Thread.current[:taskchampion_replica] ||=
      Taskchampion::Replica.new_on_disk("/path/to/tasks")
  end

  def self.task_count
    replica.task_uuids.length
  end
end
```

## Testing Thread Safety

TaskChampion includes comprehensive thread safety tests. You can run them:

```bash
ruby test/performance/test_thread_safety.rb
```

To test your own code:

```ruby
def test_my_thread_safety
  errors = []
  replica = Taskchampion::Replica.new_on_disk("/tmp/test")

  threads = 10.times.map do
    Thread.new do
      begin
        # This should fail
        replica.task_uuids
        errors << "No error raised!"
      rescue Taskchampion::ThreadError
        # Expected
      end
    end
  end

  threads.each(&:join)
  assert errors.empty?, "Thread safety issues: #{errors}"
end
```

## Debugging Thread Issues

### Enable Detailed Error Messages

Thread errors include the creating thread ID:

```ruby
begin
  replica.task_uuids
rescue Taskchampion::ThreadError => e
  puts e.message
  # "Replica was created on thread 123 but accessed from thread 456"
end
```

### Common Mistakes

1. **Instance Variables**: Don't store TaskChampion objects in instance variables accessed by multiple threads
2. **Class Variables**: Never use class variables for TaskChampion objects
3. **Global Variables**: Avoid global TaskChampion objects
4. **Shared State**: Don't pass TaskChampion objects through shared data structures

## Summary

- **One replica per thread** is the safest pattern
- **Never share** TaskChampion objects between threads
- **Handle ThreadError** gracefully in multi-threaded code
- **Test thoroughly** with concurrent access patterns
- **Use thread-local storage** for performance in web applications

The thread-bound model ensures memory safety and prevents data corruption at the cost of some flexibility. Follow these patterns and your TaskChampion usage will be both safe and performant.
