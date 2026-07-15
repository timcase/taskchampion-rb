# Migration plan: once the upstream `taskchampion` sync-error fix lands

## Context

`Replica::sync()` in the upstream `taskchampion` crate currently routes
every sync failure through `anyhow::Context`, which erases the typed
`Error` variant (`Database`, `Server`, `OutOfSync`, `Usage`) and
re-boxes it as the catch-all `Error::Other` — regardless of what
actually failed. See `upstream_issue_draft.md` at the root of this
checkout of `~/Sites/reference/taskchampion` for the full writeup filed
against `GothenburgBitFactory/taskchampion`.

This document tracks what changes in `taskchampion-rb` once that
upstream issue is fixed and released (or once we point at a patched
fork, whichever comes first).

## What does *not* need to change

`ext/taskchampion/src/error.rs`'s `map_taskchampion_error` already has
the correct match arms:

```rust
match error {
    Error::Database(msg) => Error::new(storage_error(), msg),
    Error::Server(msg)   => Error::new(sync_error(), msg),
    Error::OutOfSync     => Error::new(out_of_sync_error(), "..."),
    Error::Usage(msg)    => Error::new(validation_error(), msg),
    Error::Other(err)    => Error::new(storage_error(), format!("{err:#}")),
}
```

These arms have been correct since `0.9.1` ("Fix error mapping to use
enum variants") — they've simply been dead code for sync failures
specifically, because `Replica::sync()` never handed them a real
`Server`/`OutOfSync` value to match against. No changes needed here.

## What does need to change

### 1. Bump the pinned crate dependency

`ext/taskchampion/Cargo.toml`:

```toml
taskchampion = { version = "2.0", default-features = false, features = ["server-sync", "server-gcp"] }
```

Once the fix ships in a crates.io release, bump `"2.0"` to whatever
version includes it. If we go the fork route first (patch applied
locally, upstream PR still pending review), point at the fork instead:

```toml
taskchampion = { git = "https://github.com/<you>/taskchampion", branch = "preserve-sync-error-variant", default-features = false, features = ["server-sync", "server-gcp"] }
```

Swap back to the crates.io version once/if the PR merges and releases.

Run `cargo update -p taskchampion` (or `bundle exec rake compile`,
which will pull in the new `Cargo.lock` resolution) and recompile.

### 2. This is a breaking change for consumers — bump to 0.10.0

`Taskchampion::StorageError` and `Taskchampion::SyncError` are
**siblings** under `Taskchampion::Error`, not superclass/subclass:

```
Taskchampion::Error
├── Taskchampion::StorageError
└── Taskchampion::SyncError
    └── Taskchampion::OutOfSyncError
```

Today, every `sync_to_remote`/`sync_to_local`/`sync_to_gcp` failure
raises `StorageError`. After this fix, connection/network/out-of-sync
failures will raise `SyncError` or `OutOfSyncError` instead. Any
consumer code doing `rescue Taskchampion::StorageError` specifically
around a sync call — expecting it to catch sync failures — will
silently stop catching them.

Per semver for a pre-1.0 gem, this warrants a **minor** version bump
(`0.9.4` → `0.10.0`), not a jump to `1.0.0`. See the CHANGELOG entry
below.

### 3. Update `docs/TaskchampionRbErrors.md`

This file already documents `SyncError`/`OutOfSyncError` as reachable
via `Error::Server`/`Error::OutOfSync` — that documentation is
currently aspirational/inaccurate for sync failures specifically. Once
the fix lands, it becomes correct; no wording changes should be
needed, but re-verify the examples still match actual raised messages
(the message text may shift slightly depending on how the upstream fix
formats the wrapped context — see caveat below).

### 4. Verify existing tests still pass, add classification coverage

Existing tests are already forward-compatible:

- `test/integration/test_sync_operations.rb:150`
  (`test_sync_error_handling`) asserts
  `Taskchampion::StorageError, Taskchampion::SyncError` (either) — no
  change needed.
- `test/integration/test_sync_operations.rb`
  (`test_remote_sync_error_includes_underlying_cause`, added in
  `61130f5`) asserts the base `Taskchampion::Error` and matches on
  message content — no change needed, but re-run it: the exact message
  format may shift if the upstream fix wraps the inner message
  differently than our expectation
  (`"Failed to synchronize with server: <cause>"`).

Add new coverage once the fix lands:

- A test that a genuinely out-of-sync replica (server has diverged,
  e.g. by resetting the sync server's storage under a replica that has
  already synced) raises `Taskchampion::OutOfSyncError` specifically,
  not just `StorageError`/`SyncError`.
- A test that a connection failure (as in the existing
  `test_remote_sync_error_includes_underlying_cause`) raises
  `Taskchampion::SyncError` specifically, not `StorageError`.

### 5. CHANGELOG entry

Add to `[Unreleased]` (or a new `[0.10.0]` section once released):

```markdown
## [0.10.0] - YYYY-MM-DD

### Changed
- **Breaking:** sync failures now raise `Taskchampion::SyncError` or
  `Taskchampion::OutOfSyncError` instead of `Taskchampion::StorageError`,
  now that upstream `taskchampion` preserves the typed error variant
  through `Replica::sync()` instead of erasing it via `anyhow::Context`.
  Code that rescues `Taskchampion::StorageError` specifically around a
  sync call should rescue `Taskchampion::SyncError` (or the common
  base `Taskchampion::Error`) instead.
```

## Downstream: bravo / wt_engine

Once `taskchampion-rb` is bumped in `bravo`'s and `wt_engine`'s
`Gemfile.lock`, `Wt::SyncEventProcessor`'s failure path
(`engines/wt_engine/app/jobs/wt/sync_event_processor.rb`) and
`Tc::Sync#with_rescue` (`engines/wt_engine/app/services/tc/sync.rb`)
both use bare `rescue => e` / catch any `StandardError`, so they are
unaffected by the exception-class change — no code changes required
there. The benefit is purely in Sentry: `Taskchampion::OutOfSyncError`
and `Taskchampion::SyncError` will appear as distinct issues/fingerprints
instead of one generic `StorageError` bucket, without needing any
message-string parsing to distinguish them.
