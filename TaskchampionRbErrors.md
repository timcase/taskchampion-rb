# Taskchampion Ruby Errors

## Hierarchy

```
StandardError
└── Taskchampion::Error
    ├── Taskchampion::ThreadError
    ├── Taskchampion::StorageError
    ├── Taskchampion::ValidationError
    ├── Taskchampion::ConfigError
    └── Taskchampion::SyncError
        └── Taskchampion::OutOfSyncError
```

## Error Classes

- **`Taskchampion::Error`** — Base class for all Taskchampion errors.
- **`Taskchampion::ThreadError`** — Raised when an object (Replica, Task, etc.) is accessed from a thread other than the one that created it.
- **`Taskchampion::StorageError`** — Raised for database and storage failures (`Error::Database`), and for wrapped IO/SQLite/cloud infrastructure errors (`Error::Other`).
- **`Taskchampion::ValidationError`** — Raised for incorrect API usage (`Error::Usage`): bad tag names, empty descriptions, invalid UUIDs, wrong argument types, invalid status symbols.
- **`Taskchampion::ConfigError`** — Defined for compatibility; not raised by the current TaskChampion error variants. Missing sync keyword arguments raise Ruby `ArgumentError` instead.
- **`Taskchampion::SyncError`** — Raised for server communication errors (`Error::Server`).
- **`Taskchampion::OutOfSyncError`** — Raised when the local replica is irrecoverably out of sync with the server (`Error::OutOfSync`). Subclass of `SyncError`. Signals that re-syncing from scratch is required, not just a retry.

## Mapping from TaskChampion Rust errors

| Rust variant | Ruby class |
|---|---|
| `Error::Database(msg)` | `StorageError` |
| `Error::Server(msg)` | `SyncError` |
| `Error::OutOfSync` | `OutOfSyncError` |
| `Error::Usage(msg)` | `ValidationError` |
| `Error::Other(_)` / unknown | `StorageError` |

## Usage

Rescue any error via the base class or individually:

```ruby
begin
  replica.sync(config)
rescue Taskchampion::OutOfSyncError => e
  # local replica is irrecoverably diverged — must re-sync from scratch
rescue Taskchampion::SyncError => e
  # transient server/network error — may retry
rescue Taskchampion::StorageError => e
  # database or IO failure
rescue Taskchampion::ValidationError => e
  # bad input
rescue Taskchampion::Error => e
  # catch-all for any Taskchampion error
end
```
