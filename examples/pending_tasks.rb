#!/usr/bin/env ruby
# frozen_string_literal: true

require 'taskchampion'
require 'securerandom'

# Create an in-memory replica
replica = Taskchampion::Replica.new_in_memory

# Create several tasks with different statuses
puts "Creating tasks..."

# Create pending tasks
3.times do |i|
  ops = Taskchampion::Operations.new
  task = replica.create_task(SecureRandom.uuid, ops)
  task.set_description("Pending task #{i + 1}", ops)
  task.set_status(Taskchampion::PENDING, ops)
  replica.commit_operations(ops)
  puts "  Created pending task: #{task.description}"
end

# Create completed tasks
2.times do |i|
  ops = Taskchampion::Operations.new
  task = replica.create_task(SecureRandom.uuid, ops)
  task.set_description("Completed task #{i + 1}", ops)
  task.set_status(Taskchampion::COMPLETED, ops)
  replica.commit_operations(ops)
  puts "  Created completed task: #{task.description}"
end

# Create a deleted task
ops = Taskchampion::Operations.new
task = replica.create_task(SecureRandom.uuid, ops)
task.set_description("Deleted task", ops)
task.set_status(Taskchampion::DELETED, ops)
replica.commit_operations(ops)
puts "  Created deleted task: #{task.description}"

puts "\n" + "=" * 50
puts "Getting pending tasks..."
puts "=" * 50

# Use the pending_tasks method to get only pending tasks
pending = replica.pending_tasks

puts "\nFound #{pending.length} pending tasks:"
pending.each_with_index do |task, index|
  puts "  #{index + 1}. [#{task.uuid[0..7]}...] #{task.description}"
  puts "     Status: #{task.status}"
  puts "     Active: #{task.active?}"
end

puts "\n" + "=" * 50
puts "For comparison, all_tasks returns #{replica.all_tasks.size} tasks total"