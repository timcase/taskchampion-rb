# TaskChampion-rb Examples

This document demonstrates typical Ruby usage patterns for TaskChampion-rb, showing how to build sophisticated task management applications with operational transformation, synchronization, and thread-safe access.

## 🚀 **Basic Setup & Task Creation**

```ruby
require 'taskchampion'
require 'securerandom'

# Create a task database
replica = Taskchampion::Replica.new_on_disk("./my_tasks", true)
operations = Taskchampion::Operations.new

# Create a new task
uuid = SecureRandom.uuid
task = replica.create_task(uuid, operations)

# Commit the changes
replica.commit_operations(operations)

puts "Created task: #{task.uuid}"
```

## 📝 **Real Task Management Workflow**

```ruby
# Create a personal task manager
class TaskManager
  def initialize(data_dir = "./tasks")
    @replica = Taskchampion::Replica.new_on_disk(data_dir, true)
  end

  def add_task(description)
    operations = Taskchampion::Operations.new
    uuid = SecureRandom.uuid

    task = @replica.create_task(uuid, operations)
    @replica.commit_operations(operations)

    puts "✅ Added task: #{description} (#{uuid[0..7]})"
    task
  end

  def list_tasks
    puts "\n📋 Your Tasks:"
    @replica.task_uuids.each_with_index do |uuid, index|
      task = @replica.task(uuid)
      status = task.completed? ? "✅" : "⏳"
      puts "#{index + 1}. #{status} #{task.description} (#{uuid[0..7]})"
    end
  end

  def task_count
    @replica.task_uuids.length
  end
end

# Usage
tm = TaskManager.new
tm.add_task("Buy groceries")
tm.add_task("Write documentation")
tm.add_task("Review pull requests")
tm.list_tasks
puts "Total tasks: #{tm.task_count}"
```

## 🔍 **Task Querying & Filtering**

```ruby
# Find specific tasks
def find_active_tasks(replica)
  replica.task_uuids.filter_map do |uuid|
    task = replica.task(uuid)
    task if task.active? && !task.completed?
  end
end

# Working with task properties
def task_summary(replica, uuid)
  task = replica.task(uuid)
  return "Task not found" unless task

  status_emoji = case
    when task.completed? then "✅"
    when task.waiting? then "⏸️"
    when task.blocked? then "🚫"
    else "⏳"
  end

  "#{status_emoji} #{task.description} (Priority: #{task.priority})"
end

# Usage
replica = Taskchampion::Replica.new_in_memory
operations = Taskchampion::Operations.new

uuid = SecureRandom.uuid
task = replica.create_task(uuid, operations)
replica.commit_operations(operations)

puts task_summary(replica, uuid)
```

## 🏷️ **Working with Status & Operations**

```ruby
# Status management
def mark_completed(replica, uuid)
  operations = Taskchampion::Operations.new

  # Note: Task mutation methods not yet implemented,
  # but this shows the intended workflow
  puts "Task #{uuid[0..7]} would be marked as completed"

  # When implemented, would be:
  # task = replica.task(uuid)
  # task.set_status(Taskchampion::Status.completed, operations)
  # replica.commit_operations(operations)
end

# Operations inspection
def show_operations_info(operations)
  puts "Operations count: #{operations.length}"
  puts "Empty? #{operations.empty?}"

  operations.each do |op|
    type = case
      when op.create? then "CREATE"
      when op.update? then "UPDATE"
      when op.delete? then "DELETE"
      else "OTHER"
    end
    puts "- #{type} operation"
  end
end

# Working with status objects
pending = Taskchampion::Status.pending
completed = Taskchampion::Status.completed

puts "Status: #{pending.to_s}"           # => "pending"
puts "Is pending? #{pending.pending?}"   # => true
puts "Equal? #{pending == completed}"    # => false

# Access modes
read_write = Taskchampion::AccessMode.read_write
read_only = Taskchampion::AccessMode.read_only

puts "Mode: #{read_write.to_s}"          # => "read_write"
puts "Read only? #{read_only.read_only?}" # => true
```

## 📊 **Task Organization & Dependencies**

```ruby
# Working with working sets
def show_task_organization(replica)
  working_set = replica.working_set
  dep_map = replica.dependency_map

  puts "📊 Task Organization:"
  puts "Largest index: #{working_set.largest_index}"

  # Show tasks by index
  (1..working_set.largest_index).each do |index|
    uuid = working_set.by_index(index)
    if uuid
      task = replica.task(uuid)
      deps = dep_map.dependencies(uuid)

      dep_info = deps.empty? ? "" : " (depends on #{deps.length} tasks)"
      puts "#{index}. #{task.description}#{dep_info}"
    end
  end
end

# Working with dependencies
def analyze_dependencies(replica, uuid)
  dep_map = replica.dependency_map

  dependencies = dep_map.dependencies(uuid)
  dependents = dep_map.dependents(uuid)

  puts "Task #{uuid[0..7]}:"
  puts "  Depends on: #{dependencies.length} tasks"
  puts "  Blocks: #{dependents.length} tasks"
  puts "  Has dependencies? #{dep_map.has_dependency?(uuid)}"
end
```

## 🛠️ **Error Handling & Thread Safety**

```ruby
# Proper error handling
def safe_task_access(replica, uuid)
  begin
    task = replica.task(uuid)
    task ? task.description : "Task not found"
  rescue Taskchampion::ThreadError => e
    "Access denied: #{e.message}"
  rescue Taskchampion::Error => e
    "TaskChampion error: #{e.message}"
  rescue => e
    "Unexpected error: #{e.message}"
  end
end

# Thread safety demonstration
def demonstrate_thread_safety
  replica = Taskchampion::Replica.new_in_memory

  Thread.new do
    begin
      replica.task_uuids  # This will raise ThreadError
    rescue Taskchampion::ThreadError
      puts "✅ Thread safety working - cross-thread access blocked"
    end
  end.join
end

# Operations manipulation
def demonstrate_operations
  operations = Taskchampion::Operations.new

  # Create some operations
  uuid1 = SecureRandom.uuid
  uuid2 = SecureRandom.uuid

  op1 = Taskchampion::Operation.create(uuid1)
  op2 = Taskchampion::Operation.create(uuid2)

  # Add operations
  operations.push(op1)
  operations << op2        # Same as push

  puts "Operations count: #{operations.length}"
  puts "Operations: #{operations.inspect}"

  # Iterate operations
  operations.each do |op|
    puts "Operation type: #{op.create? ? 'CREATE' : 'OTHER'}"
  end

  # Convert to array
  ops_array = operations.to_a
  puts "Array length: #{ops_array.length}"

  # Clear operations
  operations.clear
  puts "After clear: #{operations.empty?}"
end
```

## 🎯 **Complete Example: Simple CLI Task Manager**

```ruby
#!/usr/bin/env ruby
require 'taskchampion'
require 'securerandom'

class SimpleTasks
  def initialize
    @replica = Taskchampion::Replica.new_on_disk(
      File.expand_path("~/.simple_tasks"),
      true
    )
  end

  def add(description)
    operations = Taskchampion::Operations.new
    uuid = SecureRandom.uuid

    task = @replica.create_task(uuid, operations)
    @replica.commit_operations(operations)

    puts "Added: #{description} [#{uuid[0..7]}]"
  end

  def list
    uuids = @replica.task_uuids
    if uuids.empty?
      puts "No tasks yet. Use 'add <description>' to create one."
      return
    end

    puts "\nYour Tasks:"
    uuids.each_with_index do |uuid, i|
      task = @replica.task(uuid)
      puts "#{i + 1}. #{task.description} [#{uuid[0..7]}]"
    end
  end

  def stats
    count = @replica.task_uuids.length
    working_set = @replica.working_set

    puts "\n📊 Stats:"
    puts "Total tasks: #{count}"
    puts "Largest index: #{working_set.largest_index}"
  end

  def show_task_details(index)
    uuids = @replica.task_uuids
    if index < 1 || index > uuids.length
      puts "Invalid task number. Use 'list' to see tasks."
      return
    end

    uuid = uuids[index - 1]
    task = @replica.task(uuid)

    puts "\n📋 Task Details:"
    puts "UUID: #{task.uuid}"
    puts "Description: #{task.description}"
    puts "Status: #{task.status}"
    puts "Priority: #{task.priority}"
    puts "Created: #{task.entry}"
    puts "Modified: #{task.modified}"
    puts "Active: #{task.active?}"
    puts "Completed: #{task.completed?}"
    puts "Waiting: #{task.waiting?}"
    puts "Blocked: #{task.blocked?}"
    puts "Blocking others: #{task.blocking?}"

    deps = task.dependencies
    puts "Dependencies: #{deps.empty? ? 'None' : deps.join(', ')}"

    tags = task.tags
    puts "Tags: #{tags.empty? ? 'None' : tags.map(&:to_s).join(', ')}"
  end
end

# CLI Usage
if ARGV.empty?
  puts "Usage: #{$0} <command> [args]"
  puts "Commands:"
  puts "  add <description>  - Add a new task"
  puts "  list              - List all tasks"
  puts "  show <number>     - Show task details"
  puts "  stats             - Show statistics"
  exit 1
end

tasks = SimpleTasks.new

case ARGV[0]
when 'add'
  description = ARGV[1..-1].join(' ')
  if description.empty?
    puts "Please provide a task description"
    exit 1
  end
  tasks.add(description)
when 'list'
  tasks.list
when 'show'
  index = ARGV[1].to_i
  tasks.show_task_details(index)
when 'stats'
  tasks.stats
else
  puts "Unknown command: #{ARGV[0]}"
  exit 1
end
```

## 💡 **Key Ruby Patterns**

TaskChampion-rb follows standard Ruby conventions:

### **Boolean Methods**
```ruby
# Methods ending in ? return booleans
task.active?        # => true/false
task.completed?     # => true/false
status.pending?     # => true/false
mode.read_only?     # => true/false
operations.empty?   # => true/false
```

### **Operators and Enumerable**
```ruby
# Natural Ruby operators
operations << operation           # Append operator
operations.each {|op| puts op }  # Block iteration
operations.length                # Collection size
operations[index]                # Array-like access

# Convert to array
ops_array = operations.to_a
```

### **String Representations**
```ruby
# Proper to_s and inspect methods
status.to_s         # => "pending"
status.inspect      # => "#<Taskchampion::Status:pending>"
operations.inspect  # => "#<Taskchampion::Operations: 5 operations>"
```

### **Exception Hierarchy**
```ruby
begin
  replica.task(uuid)
rescue Taskchampion::ThreadError => e
  # Thread safety violation
rescue Taskchampion::Error => e
  # General TaskChampion error
rescue => e
  # Other errors
end
```

### **Flexible Constructors**
```ruby
# Multiple constructor patterns
Taskchampion::Replica.new_in_memory
Taskchampion::Replica.new_on_disk(path, create_if_missing)
Taskchampion::Replica.new_on_disk(path, create_if_missing, access_mode)

# Factory methods for enums
Taskchampion::Status.pending
Taskchampion::Status.completed
Taskchampion::AccessMode.read_write
```

## 🏗️ **Architecture Benefits**

### **Thread Safety**
```ruby
# Automatic thread safety enforcement
replica = Taskchampion::Replica.new_in_memory

Thread.new do
  # This will raise Taskchampion::ThreadError
  replica.task_uuids
end
```

### **Operations-Based Consistency**
```ruby
# All changes go through operations for consistency
operations = Taskchampion::Operations.new

# Multiple operations can be batched
task1 = replica.create_task(uuid1, operations)
task2 = replica.create_task(uuid2, operations)

# Single commit applies all changes atomically
replica.commit_operations(operations)
```

### **Operational Transformation**
```ruby
# Operations can be inspected and manipulated
operations.each do |op|
  puts "Operation: #{op.inspect}"
  puts "  Type: #{op.create? ? 'CREATE' : 'UPDATE'}"
  puts "  UUID: #{op.uuid}" unless op.undo_point?
  puts "  Timestamp: #{op.timestamp}"
end
```

This gives Ruby developers a familiar, idiomatic interface to powerful task management capabilities with built-in consistency guarantees and thread safety!
