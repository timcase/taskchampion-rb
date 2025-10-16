#!/usr/bin/env ruby
# frozen_string_literal: true

# Basic usage examples for TaskChampion Ruby bindings
# This file demonstrates common patterns and workflows

require 'taskchampion'
require 'securerandom'
require 'tmpdir'

puts "TaskChampion Ruby Basic Usage Examples"
puts "=" * 40

# Create a temporary directory for this example
temp_dir = Dir.mktmpdir("taskchampion-example")
db_path = File.join(temp_dir, "tasks")

begin
  # 1. CREATE TASK DATABASE
  puts "\n1. Creating task database at #{db_path}"
  replica = Taskchampion::Replica.new_on_disk(db_path, true, :read_write)

  # 2. CREATE AND MODIFY TASKS
  puts "\n2. Creating and modifying tasks"

  # Create operations collection for batching changes
  operations = Taskchampion::Operations.new

  # Create first task
  uuid1 = SecureRandom.uuid
  puts "Creating task with UUID: #{uuid1}"
  task1 = replica.create_task(uuid1, operations)

  # Set task properties
  task1.set_description("Learn TaskChampion Ruby bindings", operations)
  task1.set_status(Taskchampion::Status.pending, operations)
  task1.set_priority("H", operations)  # High priority
  task1.add_tag(Taskchampion::Tag.new("learning"), operations)
  task1.add_tag(Taskchampion::Tag.new("ruby"), operations)

  # Add annotation
  task1.add_annotation("Started learning TaskChampion", operations)

  # Create second task
  uuid2 = SecureRandom.uuid
  puts "Creating task with UUID: #{uuid2}"
  task2 = replica.create_task(uuid2, operations)
  task2.set_description("Write example code", operations)
  task2.set_status(Taskchampion::Status.pending, operations)
  task2.set_priority("M", operations)  # Medium priority
  task2.add_tag(Taskchampion::Tag.new("coding"), operations)

  # Set due date (tomorrow)
  task2.set_due(Time.now + 86400, operations)

  # Create third task - already completed
  uuid3 = SecureRandom.uuid
  puts "Creating completed task with UUID: #{uuid3}"
  task3 = replica.create_task(uuid3, operations)
  task3.set_description("Read TaskChampion documentation", operations)
  task3.set_status(Taskchampion::Status.completed, operations)
  task3.add_tag(Taskchampion::Tag.new("learning"), operations)

  # 3. COMMIT CHANGES TO STORAGE
  puts "\n3. Committing changes to storage"
  replica.commit_operations(operations)
  puts "Committed #{operations.length} operations"

  # 4. QUERY AND DISPLAY TASKS
  puts "\n4. Querying and displaying tasks"

  # Get all task UUIDs
  all_uuids = replica.task_uuids
  puts "Total tasks in database: #{all_uuids.length}"

  # Retrieve and display each task
  all_uuids.each_with_index do |uuid, index|
    task = replica.task(uuid)
    next unless task

    puts "\nTask #{index + 1}:"
    puts "  UUID: #{task.uuid}"
    puts "  Description: #{task.description}"
    puts "  Status: #{task.status.to_s.capitalize}"
    puts "  Priority: #{task.priority || 'None'}"

    # Display tags
    if !task.tags.empty?
      tag_names = task.tags.map(&:to_s)
      puts "  Tags: #{tag_names.join(', ')}"
    end

    # Display dates
    puts "  Created: #{task.entry.strftime('%Y-%m-%d %H:%M:%S')}" if task.entry
    puts "  Due: #{task.due.strftime('%Y-%m-%d %H:%M:%S')}" if task.due

    # Display annotations
    if !task.annotations.empty?
      puts "  Annotations:"
      task.annotations.each do |annotation|
        puts "    [#{annotation.entry.strftime('%Y-%m-%d %H:%M:%S')}] #{annotation.description}"
      end
    end

    # Status checks
    puts "  Active: #{task.active?}"
    puts "  Pending: #{task.pending?}"
    puts "  Completed: #{task.completed?}"
  end

  # 5. FILTER AND SEARCH TASKS
  puts "\n5. Filtering and searching tasks"

  # Get all tasks as objects
  all_tasks = all_uuids.map { |uuid| replica.task(uuid) }.compact

  # Find pending tasks
  pending_tasks = all_tasks.select(&:pending?)
  puts "Pending tasks: #{pending_tasks.length}"

  # Find completed tasks
  completed_tasks = all_tasks.select(&:completed?)
  puts "Completed tasks: #{completed_tasks.length}"

  # Find high priority tasks
  high_priority_tasks = all_tasks.select { |t| t.priority == "H" }
  puts "High priority tasks: #{high_priority_tasks.length}"

  # Find tasks with specific tag
  learning_tag = Taskchampion::Tag.new("learning")
  learning_tasks = all_tasks.select { |t| t.has_tag?(learning_tag) }
  puts "Learning tasks: #{learning_tasks.length}"

  # Find tasks due today or tomorrow
  tomorrow = Time.now + 86400
  due_soon = all_tasks.select { |t| t.due && t.due.to_time <= tomorrow }
  puts "Tasks due soon: #{due_soon.length}"

  # 6. MODIFY EXISTING TASKS
  puts "\n6. Modifying existing tasks"

  # Complete the first task using the done method
  operations2 = Taskchampion::Operations.new

  # Retrieve task fresh from storage
  task_to_complete = replica.task(uuid1)
  if task_to_complete && task_to_complete.pending?
    puts "Completing task: #{task_to_complete.description}"

    # Use the done() method - a convenience method for marking tasks as completed
    task_to_complete.done(operations2)

    # Add completion annotation
    task_to_complete.add_annotation("Completed successfully!", operations2)

    # Commit the changes
    replica.commit_operations(operations2)
    puts "Task completed using done() method and committed"
  end

  # Complete the second task using traditional set_status for comparison
  operations2b = Taskchampion::Operations.new
  task_to_complete2 = replica.task(uuid2)
  if task_to_complete2 && task_to_complete2.pending?
    puts "Completing second task: #{task_to_complete2.description}"

    # Alternative way: using set_status directly
    task_to_complete2.set_status(Taskchampion::Status.completed, operations2b)

    replica.commit_operations(operations2b)
    puts "Task completed using set_status() method and committed"
  end

  # 6b. ANNOTATION MANAGEMENT
  puts "\n6b. Managing annotations (add, update, remove)"

  # Get a task with annotations
  task_with_ann = replica.task(uuid1)
  if task_with_ann && !task_with_ann.annotations.empty?
    puts "Task '#{task_with_ann.description}' has #{task_with_ann.annotations.length} annotation(s)"

    # Display current annotations
    puts "Current annotations:"
    task_with_ann.annotations.each do |ann|
      puts "  - [#{ann.entry.strftime('%H:%M:%S')}] #{ann.description}"
    end

    # Update the first annotation (preserves timestamp)
    operations_ann = Taskchampion::Operations.new
    first_ann = task_with_ann.annotations.first
    original_time = first_ann.entry

    puts "\nUpdating first annotation..."
    task_with_ann.update_annotation(first_ann, "Updated: Started and completed learning TaskChampion", operations_ann)
    replica.commit_operations(operations_ann)

    # Verify update
    task_updated = replica.task(uuid1)
    updated_ann = task_updated.annotations.first
    puts "Updated annotation: #{updated_ann.description}"
    puts "Timestamp preserved: #{(updated_ann.entry.to_time - original_time.to_time).abs < 1}"

    # Add a temporary annotation
    operations_ann2 = Taskchampion::Operations.new
    task_updated.add_annotation("Temporary progress note", operations_ann2)
    replica.commit_operations(operations_ann2)

    task_temp = replica.task(uuid1)
    puts "\nAnnotations after adding temporary note: #{task_temp.annotations.length}"
    task_temp.annotations.each do |ann|
      puts "  - #{ann.description}"
    end

    # Remove the temporary annotation
    operations_ann3 = Taskchampion::Operations.new
    temp_ann = task_temp.annotations.find { |a| a.description.include?("Temporary") }
    if temp_ann
      task_temp.remove_annotation(temp_ann, operations_ann3)
      replica.commit_operations(operations_ann3)

      task_final = replica.task(uuid1)
      puts "\nAnnotations after removal: #{task_final.annotations.length}"
      task_final.annotations.each do |ann|
        puts "  - #{ann.description}"
      end
    end
  end

  # 7. WORKING WITH WORKING SET
  puts "\n7. Working with Working Set"

  working_set = replica.working_set
  largest_index = working_set.largest_index
  puts "Largest task index: #{largest_index}"

  # Access tasks by index
  (1..largest_index).each do |index|
    task = working_set.by_index(index)
    if task
      puts "Task ##{index}: #{task.description}"

      # Find index by UUID
      found_index = working_set.by_uuid(task.uuid)
      puts "  UUID #{task.uuid} maps to index #{found_index}"
    end
  end

  # 8. WORKING WITH DEPENDENCIES
  puts "\n8. Working with Dependencies"

  dep_map = replica.dependency_map(rebuild: false)

  # Check dependencies for each task
  all_uuids.each do |uuid|
    deps = dep_map.dependencies(uuid)
    dependents = dep_map.dependents(uuid)
    has_deps = dep_map.has_dependency?(uuid)

    task = replica.task(uuid)
    if task
      puts "Task '#{task.description}':"
      puts "  Has dependencies: #{has_deps}"
      puts "  Depends on: #{deps.length} tasks"
      puts "  Blocks: #{dependents.length} tasks"
    end
  end

  # 9. USER DEFINED ATTRIBUTES (UDAs)
  puts "\n9. Working with User Defined Attributes"

  operations3 = Taskchampion::Operations.new
  test_task = replica.task(uuid2)

  if test_task
    # Set custom UDAs
    test_task.set_uda("project", "website", "company-website", operations3)
    test_task.set_uda("estimate", "hours", "8", operations3)
    test_task.set_uda("client", "name", "ACME Corp", operations3)

    replica.commit_operations(operations3)

    # Retrieve UDAs
    fresh_task = replica.task(uuid2)
    if fresh_task
      puts "UDAs for '#{fresh_task.description}':"

      website = fresh_task.uda("project", "website")
      hours = fresh_task.uda("estimate", "hours")
      client = fresh_task.uda("client", "name")

      puts "  Project: #{website}" if website
      puts "  Estimated hours: #{hours}" if hours
      puts "  Client: #{client}" if client

      # Get all UDAs
      all_udas = fresh_task.udas
      puts "  All UDAs: #{all_udas.inspect}" unless all_udas.empty?
    end
  end

  # 10. UPDATING TASKS WITH TASKDATA
  puts "\n10. Updating Tasks with TaskData"

  # Create a new task to demonstrate TaskData updates
  operations_update = Taskchampion::Operations.new
  update_uuid = SecureRandom.uuid

  puts "Creating task for TaskData update demo: #{update_uuid}"

  # Create task using TaskData (low-level API)
  task_data = Taskchampion::TaskData.create(update_uuid, operations_update)

  # Set initial properties using TaskData
  task_data.update("description", "Task for update demo", operations_update)
  task_data.update("status", "pending", operations_update)
  task_data.update("priority", "L", operations_update) # Low priority
  task_data.update("project", "examples", operations_update)

  # Commit initial task
  replica.commit_operations(operations_update)
  puts "Initial task created with TaskData API"

  # Retrieve and display initial task
  initial_task_data = replica.task_data(update_uuid)
  if initial_task_data
    puts "Initial task properties:"
    initial_task_data.properties.each do |prop|
      puts "  #{prop}: #{initial_task_data.get(prop)}"
    end
  end

  # Update the task with new properties
  update_operations = Taskchampion::Operations.new
  retrieved_task_data = replica.task_data(update_uuid)

  if retrieved_task_data
    puts "\nUpdating task properties..."

    # Update existing properties
    retrieved_task_data.update("description", "Updated task description", update_operations)
    retrieved_task_data.update("priority", "M", update_operations) # Medium priority

    # Add new properties
    retrieved_task_data.update("tags", "example,taskdata,demo", update_operations)
    retrieved_task_data.update("estimate", "2h", update_operations)
    retrieved_task_data.update("modified", Time.now.to_i.to_s, update_operations)

    # Remove a property by setting it to nil
    retrieved_task_data.update("project", nil, update_operations)

    # Commit updates
    replica.commit_operations(update_operations)
    puts "Task updated successfully"

    # Display updated task
    updated_task_data = replica.task_data(update_uuid)
    if updated_task_data
      puts "Updated task properties:"
      updated_task_data.properties.each do |prop|
        puts "  #{prop}: #{updated_task_data.get(prop)}"
      end

      puts "Task hash representation:"
      puts "  #{updated_task_data.to_hash}"
    end
  end

  # 11. DELETING TASKS WITH TASKDATA
  puts "\n11. Deleting Tasks with TaskData"

  # Create a task specifically for deletion demo
  delete_operations = Taskchampion::Operations.new
  delete_uuid = SecureRandom.uuid

  puts "Creating task for deletion demo: #{delete_uuid}"

  # Create task to be deleted
  deletable_task_data = Taskchampion::TaskData.create(delete_uuid, delete_operations)
  deletable_task_data.update("description", "Task to be deleted", delete_operations)
  deletable_task_data.update("status", "completed", delete_operations)
  deletable_task_data.update("note", "This task will be deleted", delete_operations)

  # Commit the task
  replica.commit_operations(delete_operations)
  puts "Task created for deletion"

  # Verify task exists
  before_delete = replica.task_data(delete_uuid)
  if before_delete
    puts "Task exists before deletion:"
    puts "  Description: #{before_delete.get('description')}"
    puts "  Status: #{before_delete.get('status')}"
    puts "  Note: #{before_delete.get('note')}"
    puts "  Properties: #{before_delete.properties.join(', ')}"
  else
    puts "ERROR: Task not found before deletion"
  end

  # Delete the task using TaskData.delete
  final_delete_operations = Taskchampion::Operations.new
  task_to_delete = replica.task_data(delete_uuid)

  if task_to_delete
    puts "\nDeleting task..."
    task_to_delete.delete(final_delete_operations)

    # Commit the deletion
    replica.commit_operations(final_delete_operations)
    puts "Task deletion committed"

    # Verify task is deleted
    after_delete = replica.task_data(delete_uuid)
    if after_delete.nil?
      puts "✓ Task successfully deleted - no longer exists in database"
    else
      puts "✗ Task still exists after deletion attempt"
    end

    # Also verify it's not in the task list
    remaining_uuids = replica.task_uuids
    if remaining_uuids.include?(delete_uuid)
      puts "✗ Task UUID still found in task list"
    else
      puts "✓ Task UUID removed from task list"
    end
  else
    puts "ERROR: Could not retrieve task for deletion"
  end

  # Show difference between task deletion and status update
  puts "\nNote: TaskData.delete() completely removes the task from the database."
  puts "This is different from setting status to 'deleted', which keeps the task"
  puts "but marks it as deleted. Use TaskData.delete() when you want to permanently"
  puts "purge a task and all its data."

  # 12. FINAL STATISTICS
  puts "\n12. Final Statistics"

  # Refresh task list
  final_uuids = replica.task_uuids
  final_tasks = final_uuids.map { |uuid| replica.task(uuid) }.compact

  total_tasks = final_tasks.length
  pending_count = final_tasks.count(&:pending?)
  completed_count = final_tasks.count(&:completed?)
  high_priority_count = final_tasks.count { |t| t.priority == "H" }
  tagged_count = final_tasks.count { |t| !t.tags.empty? }

  puts "Database Summary:"
  puts "  Total tasks: #{total_tasks}"
  puts "  Pending: #{pending_count}"
  puts "  Completed: #{completed_count}"
  puts "  High priority: #{high_priority_count}"
  puts "  Tagged: #{tagged_count}"

  # Storage information
  puts "\nStorage Information:"
  puts "  Local operations: #{replica.num_local_operations}"
  puts "  Undo points: #{replica.num_undo_points}"

  puts "\nExample completed successfully!"
  puts "Database stored at: #{db_path}"

rescue => e
  puts "Error: #{e.class} - #{e.message}"
  puts e.backtrace.first(5).join("\n") if e.backtrace
ensure
  # Clean up temporary directory
  if temp_dir && File.exist?(temp_dir)
    FileUtils.remove_entry(temp_dir)
    puts "\nCleaned up temporary directory: #{temp_dir}"
  end
end

puts "\nFor more examples, see:"
puts "- examples/sync_workflow.rb - Synchronization examples"
puts "- docs/API_REFERENCE.md - Complete API documentation"
puts "- docs/THREAD_SAFETY.md - Thread safety guidelines"
