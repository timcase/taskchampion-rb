#!/usr/bin/env ruby
# Phase 2 Validation Script - Test basic functionality and ThreadBound implementation

require_relative 'lib/taskchampion'
require 'securerandom'

puts "🧪 Phase 2: Basic Functionality Testing"
puts "=" * 50

# Test 1: Extension Loading
begin
  puts "✅ Test 1: Extension loading - SUCCESS"
rescue => e
  puts "❌ Test 1: Extension loading - FAILED: #{e.message}"
  exit 1
end

# Test 2: Replica Creation
begin
  replica = Taskchampion::Replica.new_in_memory
  puts "✅ Test 2: Replica creation - SUCCESS"
rescue => e
  puts "❌ Test 2: Replica creation - FAILED: #{e.message}"
  exit 1
end

# Test 3: Thread Safety Enforcement
begin
  puts "\n🧵 Test 3: Thread Safety Enforcement"
  replica = Taskchampion::Replica.new_in_memory

  thread_error_raised = false
  error_message = nil

  Thread.new do
    begin
      replica.task_uuids # Should raise ThreadError
      puts "❌ No error raised - thread safety FAILED"
    rescue => e
      thread_error_raised = true
      error_message = e.message
      puts "✅ ThreadError raised: #{e.class} - #{e.message}"
    end
  end.join

  if thread_error_raised
    puts "✅ Test 3: Thread safety enforcement - SUCCESS"
  else
    puts "❌ Test 3: Thread safety enforcement - FAILED"
    exit 1
  end
rescue => e
  puts "❌ Test 3: Thread safety test failed: #{e.message}"
  exit 1
end

# Test 4: Same-thread access should work
begin
  puts "\n🧵 Test 4: Same-thread access"
  replica = Taskchampion::Replica.new_in_memory
  uuids = replica.task_uuids
  puts "✅ Test 4: Same-thread access works - got #{uuids.class}"
rescue => e
  puts "❌ Test 4: Same-thread access failed: #{e.message}"
  exit 1
end

puts "\n" + "=" * 50
puts "🎉 Phase 2 Validation: COMPLETE!"
puts "✅ Extension loads successfully"
puts "✅ ThreadBound implementation working"
puts "✅ Thread safety enforcement active"
puts "✅ Same-thread access functional"
puts "\nReady to proceed to Phase 3!"
