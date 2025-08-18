# TaskChampion Ruby Error Reference

## Error Hierarchy

All TaskChampion errors inherit from `Taskchampion::Error`, which inherits from Ruby's `StandardError`.

```
StandardError
└── Taskchampion::Error
    ├── Taskchampion::ThreadError
    ├── Taskchampion::StorageError
    ├── Taskchampion::ValidationError
    ├── Taskchampion::ConfigError
    └── Taskchampion::SyncError
```

## Error Types

### Taskchampion::ValidationError

Raised when data validation fails, including:
- Invalid UUID format
- Invalid datetime format
- Parse errors
- Format validation failures

**Example:**
```ruby
# Invalid UUID format
replica.create_task("bad-uuid", operations)
# => Taskchampion::ValidationError: Invalid UUID format: 'bad-uuid'. Expected format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
```

### Taskchampion::ThreadError

Raised when an object is accessed from a different thread than the one that created it. TaskChampion enforces thread safety by requiring objects to be accessed only from their creation thread.

**Example:**
```ruby
replica = Taskchampion::Replica.new_in_memory
Thread.new { replica.all_tasks }.join
# => Taskchampion::ThreadError: Object accessed from wrong thread
```

### Taskchampion::StorageError

Raised for database and storage-related issues:
- File not found
- Permission denied
- Database corruption
- Storage access failures

**Example:**
```ruby
Taskchampion::Replica.new_on_disk("/invalid/path", false)
# => Taskchampion::StorageError: Storage error: No such file or directory
```

### Taskchampion::ConfigError

Raised when configuration is invalid or missing required parameters:
- Invalid configuration values
- Missing required configuration

**Example:**
```ruby
# Missing required sync configuration
replica.sync_to_remote(url: "https://example.com")
# => Taskchampion::ConfigError: Configuration error: missing client_id
```

### Taskchampion::SyncError

Raised during synchronization operations:
- Network failures
- Server connection issues
- Remote sync problems
- Authentication failures

**Example:**
```ruby
replica.sync_to_remote(
  url: "https://invalid.server",
  client_id: "...",
  encryption_secret: "..."
)
# => Taskchampion::SyncError: Synchronization error: network timeout
```

### Taskchampion::Error

Generic error class for TaskChampion errors that don't fall into specific categories. This is the base class for all TaskChampion-specific errors.

## Common Error Scenarios

### Creating Tasks

```ruby
begin
  task = replica.create_task(uuid, operations)
rescue Taskchampion::ValidationError => e
  # Handle invalid UUID format
  puts "Invalid UUID: #{e.message}"
rescue Taskchampion::StorageError => e
  # Handle storage issues
  puts "Storage problem: #{e.message}"
rescue Taskchampion::ThreadError => e
  # Handle thread safety violation
  puts "Thread error: #{e.message}"
end
```

### Synchronization

```ruby
begin
  replica.sync_to_remote(
    url: server_url,
    client_id: client_id,
    encryption_secret: secret
  )
rescue Taskchampion::SyncError => e
  # Handle sync failures
  puts "Sync failed: #{e.message}"
rescue Taskchampion::ConfigError => e
  # Handle configuration issues
  puts "Config error: #{e.message}"
end
```

### File Operations

```ruby
begin
  replica = Taskchampion::Replica.new_on_disk(path, false, :read_write)
rescue Taskchampion::StorageError => e
  # Handle file access issues
  puts "Cannot access database: #{e.message}"
end
```

## Error Message Patterns

The error mapping system examines error message content to determine the appropriate exception type:

- Messages containing "storage", "database", "No such file", or "Permission denied" → `StorageError`
- Messages containing "sync", "server", "network", or "remote" → `SyncError`
- Messages containing "config" or "invalid config" → `ConfigError`
- Messages containing "invalid", "parse", "format", or "validation" → `ValidationError`
- Thread access violations → `ThreadError`
- All other TaskChampion errors → `Error` (base class)