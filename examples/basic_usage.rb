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
  replica = Taskchampion::Replica.new_on_disk(db_path, create_if_missing: true)

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
  annotation = Taskchampion::Annotation.new(Time.now, "Started learning TaskChampion")
  task1.add_annotation(annotation, operations)

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
  task3.set_end(Time.now, operations)

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
      tag_names = task.tags.map(&:name)
      puts "  Tags: #{tag_names.join(', ')}"
    end

    # Display dates
    puts "  Created: #{task.entry.strftime('%Y-%m-%d %H:%M:%S')}" if task.entry
    puts "  Due: #{task.due.strftime('%Y-%m-%d %H:%M:%S')}" if task.due
    puts "  Completed: #{task.end.strftime('%Y-%m-%d %H:%M:%S')}" if task.end

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
  due_soon = all_tasks.select { |t| t.due && t.due <= tomorrow }
  puts "Tasks due soon: #{due_soon.length}"

  # 6. MODIFY EXISTING TASKS
  puts "\n6. Modifying existing tasks"

  # Complete the first task
  operations2 = Taskchampion::Operations.new

  # Retrieve task fresh from storage
  task_to_complete = replica.task(uuid1)
  if task_to_complete && task_to_complete.pending?
    puts "Completing task: #{task_to_complete.description}"
    task_to_complete.set_status(Taskchampion::Status.completed, operations2)
    task_to_complete.set_end(Time.now, operations2)

    # Add completion annotation
    completion_note = Taskchampion::Annotation.new(Time.now, "Completed successfully!")
    task_to_complete.add_annotation(completion_note, operations2)

    # Commit the changes
    replica.commit_operations(operations2)
    puts "Task completed and committed"
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

  # 10. FINAL STATISTICS
  puts "\n10. Final Statistics"

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
