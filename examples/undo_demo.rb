#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "../lib/taskchampion"

# Create a replica for this demo
replica = Taskchampion::Replica.new_in_memory

puts "=== TaskChampion Undo/History Demo ==="

# Create first task with undo point
puts "\n1. Creating first task..."
ops1 = Taskchampion::Operations.new
ops1.push(Taskchampion::Operation.undo_point)
task1 = replica.create_task("550e8400-e29b-41d4-a716-446655440000", ops1)
task1.set_description("First task", ops1)
replica.commit_operations(ops1)

# Create second task with undo point
puts "2. Creating second task..."
ops2 = Taskchampion::Operations.new
ops2.push(Taskchampion::Operation.undo_point)
task2 = replica.create_task("550e8400-e29b-41d4-a716-446655440001", ops2)
task2.set_description("Second task", ops2)
task2.set_value("project", "home", ops2)
replica.commit_operations(ops2)

# Update task2's description to show old_value -> new_value
puts "\n3. Updating second task's description..."
ops3 = Taskchampion::Operations.new
task2.set_description("Updated second task", ops3)
replica.commit_operations(ops3)

# Show current tasks
puts "\n4. Current tasks:"
replica.all_tasks.each do |uuid, task|
  puts "  - #{task.description} (#{uuid})"
end

# Show task history for task2
puts "\n5. History for second task:"
task2_ops = replica.task_operations(task2.uuid)
puts "  Operations count: #{task2_ops.length}"
task2_ops.to_a.each_with_index do |op, i|
  puts "  #{i + 1}. #{op.operation_type}"
  if op.operation_type == :update
    old_val = op.old_value.nil? ? "(none)" : op.old_value
    new_val = op.value.nil? ? "(none)" : op.value
    puts "    Details: #{op.property} changed from #{old_val} to #{new_val} at #{op.timestamp}"
  end
end

# Check undo points available
puts "\n6. Undo points available: #{replica.num_undo_points}"

# Show what would be undone
puts "\n7. Operations that would be undone:"
undo_ops = replica.undo_operations
puts "  Operations to undo: #{undo_ops.length}"
undo_ops.to_a.each_with_index do |op, i|
  puts "  #{i + 1}. #{op.operation_type}"
end

# Perform undo
puts "\n8. Performing undo..."
result = replica.undo!
puts "  Undo successful: #{result}"

# Show tasks after undo
puts "\n9. Tasks after first undo:"
tasks = replica.all_tasks
if tasks.empty?
  puts "  No tasks"
else
  tasks.each do |uuid, task|
    puts "  - #{task.description} (#{uuid})"
  end
end

# Show remaining undo points
puts "\n10. Remaining undo points: #{replica.num_undo_points}"

# Perform another undo
if replica.num_undo_points > 0
  puts "\n11. Performing second undo..."
  result = replica.undo!
  puts "   Undo successful: #{result}"

  puts "\n12. Tasks after second undo:"
  tasks = replica.all_tasks
  if tasks.empty?
    puts "   No tasks remaining"
  else
    tasks.each do |uuid, task|
      puts "   - #{task.description} (#{uuid})"
    end
  end

  puts "\n13. Final undo points: #{replica.num_undo_points}"
else
  puts "\n11. No more undo points available"
end

puts "\n=== Demo Complete ==="