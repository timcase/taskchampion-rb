## [Unreleased]

- Link the system `libsqlite3` by default again, as 0.9.4 did, so
  `libsqlite3-dev` is once more a build prerequisite on Linux. Since
  0.9.5 the extension compiled its own copy of SQLite, which leaves two
  SQLite copies in any process that also loads the `sqlite3` gem; they
  do not share POSIX file locks, which can corrupt the database.
- Add an opt-in switch for bundled SQLite: set
  `TASKCHAMPION_BUNDLED_SQLITE=1` or pass `--with-bundled-sqlite` at
  install time. Only use it when nothing else in the process loads
  SQLite.

## [0.9.6] - 2026-10-22

- Update `rb-sys` to 0.9.130 (pulling in `bindgen` 0.72.1) in
  `Cargo.lock`. The previously locked `bindgen` 0.69.5 cannot parse
  Ruby's `rb_data_type_struct` with libclang 22, as shipped on Ubuntu
  26.04, so `magnus` failed to compile there.
- Drop the stale Ruby 3.5 preview from the CI matrix; CI now tests 3.3
  and 3.4. Ruby 4.0 is not yet supported (`magnus` 0.7 does not build
  against it).

## [0.9.5] - 2026-09-10

- Drop support for Ruby 3.2 (reached EOL March 2026). Minimum supported
  Ruby is now 3.3.
- Enable the `bundled` feature of the `taskchampion` crate so SQLite is
  compiled from source into the extension. Previously `default-features
  = false` dropped `bundled`, making the build link against system
  SQLite and fail with `cannot find -lsqlite3` on any host without
  `libsqlite3-dev` installed.
- Expand README build prerequisites: `clang`/`libclang-dev` (needed by
  `rb-sys` bindgen) on Linux, `xcode-select --install` on macOS, and
  note that the Rust toolchain is optional since `rb-sys` bootstraps
  one.

## [0.9.4] - 2026-07-11

- Include the full cause chain in sync error messages. TaskChampion
  wraps sync failures in an anyhow context, and the default `Display`
  previously printed only the outermost line ("Failed to synchronize
  with server"), hiding the real cause. `Error::Other` is now formatted
  with anyhow's alternate format so the full chain (HTTP status,
  connection errors, server rejections) reaches Ruby.
- Add `server-gcp` feature flag, required for `ServerConfig::Gcp` used
  by `sync_gcp`
- Fix order-dependent annotation test

## [0.9.3] - 2026-05-30

- Add `Task#set_modified` method, consistent with `set_entry`
- Move docs
- Change taskchampion dependency to enable `server-sync` feature

## [0.9.2] - 2026-05-22

- Fix all Rust compiler warnings

## [0.9.1] - 2026-05-22

- Fix error mapping to use `taskchampion::Error` enum variants instead
  of heuristic message-content matching. Adds
  `Taskchampion::OutOfSyncError < SyncError` for the `OutOfSync`
  sentinel, signaling an irrecoverable divergence that requires a full
  re-sync rather than a retry

## [0.9.0] - 2025-10-17

- Add remove and update annotations support

## [0.8.0] - 2025-09-24

- Add undo/history functionality with operation tracking
- Add `set_timestamp` and `get_timestamp` methods for custom date
  fields
- Fix RuboCop errors

## [0.7.0] - 2025-08-18

- Add `set_entry` method to `Task`
- Fix RuboCop errors

## [0.6.0] - 2025-08-14

- Add pending task support to `Replica`

## [0.5.0] - 2025-08-14

- Implement `done` status handling

Note: v0.4.0 was tagged against the same commit as v0.5.0 and carries
no distinct changes; treat v0.5.0 as its replacement.

## [0.3.0] - 2025-08-14

- Rename gem to `taskchampion-rb`
- Implement `TaskData`
- Rename `tasks` to `all_tasks`
- Support Windows and ARM builds
- Drop support for Ruby versions below 3.2

## [0.2.0] - 2025-08-11

- Enhanced error handling with contextual messages
- Added comprehensive parameter validation checks
- Added Ruby-style setter methods for naming polish
- Enhanced Operation class with introspection API
- Complete Replica class API with sync methods
- Improved thread safety implementation
- Comprehensive test suite with error handling coverage

## [0.1.0] - 2025-07-29

- Initial release
