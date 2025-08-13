#!/usr/bin/env ruby
# frozen_string_literal: true

# Synchronization workflow examples for TaskChampion Ruby bindings
# This file demonstrates different sync patterns and server configurations

require 'taskchampion'
require 'securerandom'
require 'tmpdir'
require 'fileutils'

puts "TaskChampion Ruby Synchronization Examples"
puts "=" * 45

# Create temporary directories for this example
temp_base = Dir.mktmpdir("taskchampion-sync")
client1_dir = File.join(temp_base, "client1")
client2_dir = File.join(temp_base, "client2")
server_dir = File.join(temp_base, "server")

begin
  # Ensure directories exist
  [client1_dir, client2_dir, server_dir].each { |dir| FileUtils.mkdir_p(dir) }

  puts "\nSetup:"
  puts "Client 1: #{client1_dir}"
  puts "Client 2: #{client2_dir}"
  puts "Server: #{server_dir}"

  # ========================================
  # 1. LOCAL FILE SYNCHRONIZATION
  # ========================================

  puts "\n" + "=" * 50
  puts "1. LOCAL FILE SYNCHRONIZATION"
  puts "=" * 50

  puts "\nCreating two client replicas..."

  # Create first client replica
  client1 = Taskchampion::Replica.new_on_disk(client1_dir, create_if_missing: true)

  # Create second client replica
  client2 = Taskchampion::Replica.new_on_disk(client2_dir, create_if_missing: true)

  # Add tasks to client 1
  puts "\nAdding tasks to Client 1..."
  ops1 = Taskchampion::Operations.new

  uuid1 = SecureRandom.uuid
  task1 = client1.create_task(uuid1, ops1)
  task1.set_description("Task from Client 1", ops1)
  task1.set_priority("H", ops1)
  task1.add_tag(Taskchampion::Tag.new("client1"), ops1)

  uuid2 = SecureRandom.uuid
  task2 = client1.create_task(uuid2, ops1)
  task2.set_description("Shared task", ops1)
  task2.add_tag(Taskchampion::Tag.new("shared"), ops1)

  client1.commit_operations(ops1)
  puts "Client 1 has #{client1.task_uuids.length} tasks"

  # Add tasks to client 2
  puts "\nAdding tasks to Client 2..."
  ops2 = Taskchampion::Operations.new

  uuid3 = SecureRandom.uuid
  task3 = client2.create_task(uuid3, ops2)
  task3.set_description("Task from Client 2", ops2)
  task3.set_priority("M", ops2)
  task3.add_tag(Taskchampion::Tag.new("client2"), ops2)

  client2.commit_operations(ops2)
  puts "Client 2 has #{client2.task_uuids.length} tasks"

  # Sync Client 1 to server (upload)
  puts "\nSyncing Client 1 to server..."
  begin
    client1.sync_to_local(server_dir, avoid_snapshots: false)
    puts "✓ Client 1 synced to server successfully"
  rescue => e
    puts "✗ Client 1 sync failed: #{e.message}"
  end

  # Sync Client 2 to server (upload) and from server (download)
  puts "\nSyncing Client 2 with server..."
  begin
    client2.sync_to_local(server_dir, avoid_snapshots: false)
    puts "✓ Client 2 synced with server successfully"
    puts "Client 2 now has #{client2.task_uuids.length} tasks"
  rescue => e
    puts "✗ Client 2 sync failed: #{e.message}"
  end

  # Sync Client 1 from server (download changes from Client 2)
  puts "\nSyncing Client 1 from server..."
  begin
    client1.sync_to_local(server_dir, avoid_snapshots: false)
    puts "✓ Client 1 synced from server successfully"
    puts "Client 1 now has #{client1.task_uuids.length} tasks"
  rescue => e
    puts "✗ Client 1 sync failed: #{e.message}"
  end

  # Verify both clients have all tasks
  puts "\nVerification after sync:"
  client1_tasks = client1.task_uuids.map { |uuid| client1.task(uuid) }.compact
  client2_tasks = client2.task_uuids.map { |uuid| client2.task(uuid) }.compact

  puts "Client 1 tasks:"
  client1_tasks.each do |task|
    tags = task.tags.map(&:name).join(", ")
    puts "  - #{task.description} [#{tags}]"
  end

  puts "Client 2 tasks:"
  client2_tasks.each do |task|
    tags = task.tags.map(&:name).join(", ")
    puts "  - #{task.description} [#{tags}]"
  end

  # ========================================
  # 2. CONFLICT RESOLUTION
  # ========================================

  puts "\n" + "=" * 50
  puts "2. CONFLICT RESOLUTION"
  puts "=" * 50

  # Create conflicting changes
  puts "\nCreating conflicting changes..."

  # Client 1 modifies the shared task
  shared_task_c1 = client1.task(uuid2)
  if shared_task_c1
    ops1_conflict = Taskchampion::Operations.new
    shared_task_c1.set_description("Shared task - modified by Client 1", ops1_conflict)
    shared_task_c1.set_priority("H", ops1_conflict)
    shared_task_c1.add_tag(Taskchampion::Tag.new("modified-c1"), ops1_conflict)
    client1.commit_operations(ops1_conflict)
    puts "✓ Client 1 modified shared task"
  end

  # Client 2 also modifies the same shared task
  shared_task_c2 = client2.task(uuid2)
  if shared_task_c2
    ops2_conflict = Taskchampion::Operations.new
    shared_task_c2.set_description("Shared task - modified by Client 2", ops2_conflict)
    shared_task_c2.set_priority("L", ops2_conflict)
    shared_task_c2.add_tag(Taskchampion::Tag.new("modified-c2"), ops2_conflict)
    client2.commit_operations(ops2_conflict)
    puts "✓ Client 2 modified shared task"
  end

  # Sync and see how conflicts are resolved
  puts "\nSyncing conflicting changes..."

  # Client 1 syncs first
  begin
    client1.sync_to_local(server_dir, avoid_snapshots: false)
    puts "✓ Client 1 synced (first to server)"
  rescue => e
    puts "✗ Client 1 sync failed: #{e.message}"
  end

  # Client 2 syncs (will resolve conflicts)
  begin
    client2.sync_to_local(server_dir, avoid_snapshots: false)
    puts "✓ Client 2 synced (conflict resolution)"
  rescue => e
    puts "✗ Client 2 sync failed: #{e.message}"
  end

  # Client 1 syncs again to get resolved state
  begin
    client1.sync_to_local(server_dir, avoid_snapshots: false)
    puts "✓ Client 1 synced (getting resolved state)"
  rescue => e
    puts "✗ Client 1 sync failed: #{e.message}"
  end

  # Show final state after conflict resolution
  puts "\nFinal state after conflict resolution:"
  final_task_c1 = client1.task(uuid2)
  final_task_c2 = client2.task(uuid2)

  if final_task_c1
    tags = final_task_c1.tags.map(&:name).join(", ")
    puts "Client 1 sees: '#{final_task_c1.description}' priority=#{final_task_c1.priority} tags=[#{tags}]"
  end

  if final_task_c2
    tags = final_task_c2.tags.map(&:name).join(", ")
    puts "Client 2 sees: '#{final_task_c2.description}' priority=#{final_task_c2.priority} tags=[#{tags}]"
  end

  # ========================================
  # 3. SYNC PATTERNS AND BEST PRACTICES
  # ========================================

  puts "\n" + "=" * 50
  puts "3. SYNC PATTERNS AND BEST PRACTICES"
  puts "=" * 50

  # Pattern 1: Sync before and after work session
  puts "\nPattern 1: Sync before and after work session"

  def work_session(replica, server_dir, client_name)
    puts "\n#{client_name}: Starting work session..."

    # 1. Sync before work (get latest changes)
    begin
      replica.sync_to_local(server_dir, avoid_snapshots: false)
      puts "  ✓ Pre-work sync completed"
    rescue => e
      puts "  ✗ Pre-work sync failed: #{e.message}"
      return false
    end

    # 2. Do work
    operations = Taskchampion::Operations.new
    work_uuid = SecureRandom.uuid
    task = replica.create_task(work_uuid, operations)
    task.set_description("Work session task from #{client_name}", operations)
    task.add_tag(Taskchampion::Tag.new("work-session"), operations)
    replica.commit_operations(operations)
    puts "  ✓ Created work session task"

    # 3. Sync after work (share changes)
    begin
      replica.sync_to_local(server_dir, avoid_snapshots: false)
      puts "  ✓ Post-work sync completed"
      true
    rescue => e
      puts "  ✗ Post-work sync failed: #{e.message}"
      false
    end
  end

  # Simulate work sessions
  work_session(client1, server_dir, "Client 1")
  work_session(client2, server_dir, "Client 2")

  # Pattern 2: Periodic sync with error handling
  puts "\nPattern 2: Periodic sync with error handling"

  def periodic_sync(replica, server_dir, client_name)
    max_retries = 3
    retry_delay = 1 # seconds

    (1..max_retries).each do |attempt|
      begin
        puts "  #{client_name}: Sync attempt #{attempt}/#{max_retries}"
        replica.sync_to_local(server_dir, avoid_snapshots: false)
        puts "  ✓ Sync successful"
        return true
      rescue => e
        puts "  ✗ Sync attempt #{attempt} failed: #{e.message}"

        if attempt < max_retries
          puts "    Retrying in #{retry_delay} seconds..."
          sleep(retry_delay)
          retry_delay *= 2 # Exponential backoff
        else
          puts "    Max retries reached, giving up"
          return false
        end
      end
    end
  end

  periodic_sync(client1, server_dir, "Client 1")

  # Pattern 3: Sync status checking
  puts "\nPattern 3: Sync status and storage information"

  def sync_status(replica, client_name)
    puts "\n#{client_name} Status:"
    puts "  Local operations: #{replica.num_local_operations}"
    puts "  Undo points: #{replica.num_undo_points}"
    puts "  Total tasks: #{replica.task_uuids.length}"
  end

  sync_status(client1, "Client 1")
  sync_status(client2, "Client 2")

  # ========================================
  # 4. REMOTE SERVER SYNC (EXAMPLES)
  # ========================================

  puts "\n" + "=" * 50
  puts "4. REMOTE SERVER SYNC (EXAMPLES)"
  puts "=" * 50

  puts "\nNote: These examples show the API but won't actually connect"
  puts "      without a real TaskWarrior server or cloud storage setup.\n"

  # Example: Sync to remote TaskWarrior server
  puts "Example: Sync to remote TaskWarrior server"
  puts "```ruby"
  puts "begin"
  puts "  replica.sync_to_remote("
  puts "    url: 'https://taskserver.example.com:53589',"
  puts "    client_id: 'your-client-id-here',"
  puts "    encryption_secret: 'your-encryption-secret',"
  puts "    avoid_snapshots: false"
  puts "  )"
  puts "  puts '✓ Successfully synced to remote server'"
  puts "rescue Taskchampion::SyncError => e"
  puts "  puts '✗ Remote sync failed: #{e.message}'"
  puts "rescue Taskchampion::ConfigError => e"
  puts "  puts '✗ Configuration error: #{e.message}'"
  puts "end"
  puts "```\n"

  # Example: Sync to Google Cloud Platform
  puts "Example: Sync to Google Cloud Storage"
  puts "```ruby"
  puts "begin"
  puts "  replica.sync_to_gcp("
  puts "    bucket: 'my-taskwarrior-bucket',"
  puts "    credential_path: '/path/to/service-account.json',"
  puts "    encryption_secret: 'your-encryption-secret',"
  puts "    avoid_snapshots: false"
  puts "  )"
  puts "  puts '✓ Successfully synced to Google Cloud'"
  puts "rescue Taskchampion::SyncError => e"
  puts "  puts '✗ GCP sync failed: #{e.message}'"
  puts "rescue Taskchampion::ConfigError => e"
  puts "  puts '✗ GCP configuration error: #{e.message}'"
  puts "end"
  puts "```\n"

  # ========================================
  # 5. SNAPSHOT MANAGEMENT
  # ========================================

  puts "\n" + "=" * 50
  puts "5. SNAPSHOT MANAGEMENT"
  puts "=" * 50

  puts "\nSnapshots help optimize sync performance for large task databases."
  puts "They can be avoided for smaller datasets or debugging purposes.\n"

  # Example with snapshots (default)
  puts "Sync with snapshots (default, faster for large datasets):"
  begin
    client1.sync_to_local(server_dir, avoid_snapshots: false)
    puts "✓ Sync with snapshots completed"
  rescue => e
    puts "✗ Sync failed: #{e.message}"
  end

  # Example without snapshots
  puts "\nSync without snapshots (slower, but more predictable):"
  begin
    client2.sync_to_local(server_dir, avoid_snapshots: true)
    puts "✓ Sync without snapshots completed"
  rescue => e
    puts "✗ Sync failed: #{e.message}"
  end

  # ========================================
  # 6. MULTI-CLIENT WORKFLOW
  # ========================================

  puts "\n" + "=" * 50
  puts "6. MULTI-CLIENT WORKFLOW SIMULATION"
  puts "=" * 50

  puts "\nSimulating a realistic multi-client workflow..."

  # Simulate desktop client
  puts "\n[Desktop Client] Creating project tasks..."
  desktop_ops = Taskchampion::Operations.new

  project_tasks = [
    "Design user interface",
    "Implement authentication",
    "Write unit tests",
    "Deploy to staging"
  ]

  project_uuids = []
  project_tasks.each_with_index do |desc, index|
    uuid = SecureRandom.uuid
    project_uuids << uuid
    task = client1.create_task(uuid, desktop_ops)
    task.set_description(desc, desktop_ops)
    task.set_priority(["H", "H", "M", "L"][index], desktop_ops)
    task.add_tag(Taskchampion::Tag.new("project"), desktop_ops)
    task.add_tag(Taskchampion::Tag.new("web-app"), desktop_ops)
  end

  client1.commit_operations(desktop_ops)
  client1.sync_to_local(server_dir, avoid_snapshots: false)
  puts "  ✓ Desktop client created and synced #{project_tasks.length} project tasks"

  # Simulate mobile client
  puts "\n[Mobile Client] Adding personal tasks and checking project status..."
  client2.sync_to_local(server_dir, avoid_snapshots: false) # Get project tasks

  mobile_ops = Taskchampion::Operations.new

  personal_tasks = [
    "Buy groceries",
    "Call dentist",
    "Review project status"
  ]

  personal_tasks.each do |desc|
    uuid = SecureRandom.uuid
    task = client2.create_task(uuid, mobile_ops)
    task.set_description(desc, mobile_ops)
    task.add_tag(Taskchampion::Tag.new("personal"), mobile_ops)
  end

  # Complete first project task from mobile
  project_task = client2.task(project_uuids.first)
  if project_task
    project_task.set_status(Taskchampion::Status.completed, mobile_ops)
    project_task.set_end(Time.now, mobile_ops)
    puts "  ✓ Completed '#{project_task.description}' from mobile"
  end

  client2.commit_operations(mobile_ops)
  client2.sync_to_local(server_dir, avoid_snapshots: false)
  puts "  ✓ Mobile client added personal tasks and updated project"

  # Desktop client gets updates
  puts "\n[Desktop Client] Syncing to see mobile updates..."
  client1.sync_to_local(server_dir, avoid_snapshots: false)

  # Show final state
  puts "\nFinal synchronized state:"
  all_tasks_c1 = client1.task_uuids.map { |uuid| client1.task(uuid) }.compact

  project_tasks_final = all_tasks_c1.select { |t| t.has_tag?(Taskchampion::Tag.new("project")) }
  personal_tasks_final = all_tasks_c1.select { |t| t.has_tag?(Taskchampion::Tag.new("personal")) }

  puts "\nProject tasks:"
  project_tasks_final.each do |task|
    status_icon = task.completed? ? "✓" : "○"
    puts "  #{status_icon} #{task.description} [#{task.priority}]"
  end

  puts "\nPersonal tasks:"
  personal_tasks_final.each do |task|
    status_icon = task.completed? ? "✓" : "○"
    puts "  #{status_icon} #{task.description}"
  end

  puts "\n" + "=" * 50
  puts "SYNCHRONIZATION EXAMPLES COMPLETED"
  puts "=" * 50

  puts "\nKey takeaways:"
  puts "✓ Local file sync enables multi-client workflows"
  puts "✓ TaskChampion handles conflict resolution automatically"
  puts "✓ Always sync before and after work sessions"
  puts "✓ Use proper error handling and retries"
  puts "✓ Monitor sync status with storage information"
  puts "✓ Consider snapshot settings for performance"

rescue => e
  puts "\nError during sync examples: #{e.class} - #{e.message}"
  puts e.backtrace.first(5).join("\n") if e.backtrace
ensure
  # Clean up temporary directories
  if temp_base && File.exist?(temp_base)
    FileUtils.remove_entry(temp_base)
    puts "\nCleaned up temporary directories: #{temp_base}"
  end
end

puts "\nFor more information, see:"
puts "- examples/basic_usage.rb - Basic TaskChampion usage"
puts "- docs/API_REFERENCE.md - Complete API documentation"
puts "- docs/THREAD_SAFETY.md - Thread safety guidelines"
