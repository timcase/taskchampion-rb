# Taskchampion

Ruby bindings for TaskChampion, the task database that powers Taskwarrior.

## Ruby Version Support (2026-09-10)

This gem supports Ruby 3.3 and later. We follow Ruby's end-of-life (EOL) schedule and drop support for Ruby versions that have reached EOL.

- **Ruby 3.3**: Supported
- **Ruby 3.4**: Supported (Current stable)
- **Ruby 3.5**: Supported
- **Ruby 3.0-3.2**: Not supported (reached EOL)

## Installation

### Prerequisites

1. Ruby 3.3 or later
2. A C compiler and `clang`/`libclang` development headers — `rb-sys` runs
   libclang over Ruby's headers to generate FFI bindings during `rake compile`.
   - **Debian/Ubuntu:** `sudo apt install clang libclang-dev`
   - **macOS:** `xcode-select --install`
3. System SQLite development files — the extension links the system
   `libsqlite3` by default.
   - **Debian/Ubuntu:** `sudo apt install libsqlite3-dev`
   - **macOS:** nothing to install; the OS ships `libsqlite3`.
4. Rust toolchain (optional — if `cargo` is not found, `rb-sys` bootstraps its
   own rustup + toolchain during the build). To install it yourself:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

### Bundled SQLite (opt-in)

To compile SQLite from source into the extension instead of linking the
system library, set the switch at install time:

```bash
TASKCHAMPION_BUNDLED_SQLITE=1 gem install taskchampion-rb
# or
gem install taskchampion-rb -- --with-bundled-sqlite
# or, with Bundler
bundle config build.taskchampion-rb --with-bundled-sqlite
```

> **Warning:** do not use bundled SQLite in a process that also loads another
> copy of SQLite, such as the `sqlite3` gem (e.g. a Rails app). Two SQLite
> copies in one process do not see each other's POSIX file locks, which can
> corrupt the database. Bundling is only safe when taskchampion-rb is the sole
> SQLite user in the process.

### Building from source

```bash
bundle install
bundle exec rake compile
```

### Testing

```bash
bundle exec rake test
```

## Usage

```ruby
require 'taskchampion'

# Create an in-memory replica
replica = Taskchampion::Replica.new_in_memory

# Create an on-disk replica
replica = Taskchampion::Replica.new_on_disk("/path/to/taskdb", true)

# With access mode
replica = Taskchampion::Replica.new_on_disk("/path/to/taskdb", true, :read_only)

# Working with operations
ops = Taskchampion::Operations.new
create_op = Taskchampion::Operation.create(SecureRandom.uuid)
ops << create_op

# Task operations (when Operations integration is complete)
# task = replica.create_task(uuid, ops)
# task.set_description("New task description", ops)
# replica.commit_operations(ops)

# Working with tags and annotations
tag = Taskchampion::Tag.new("work")
puts tag.to_s          # => "work"
puts tag.user?         # => true
puts tag.synthetic?    # => false

annotation = Taskchampion::Annotation.new(DateTime.now, "This is a note")
puts annotation.description  # => "This is a note"

# Status constants
puts Taskchampion::PENDING     # => :pending
puts Taskchampion::COMPLETED   # => :completed
puts Taskchampion::ACCESS_MODES # => [:read_only, :read_write]
```

## Development Status

This is a Ruby port of the taskchampion-py Python bindings. The implementation follows the plan outlined in the `ruby_docs/` directory of the Python project.

### Completed
- ✅ Basic project structure
- ✅ Magnus and rb-sys configuration
- ✅ Error hierarchy (Error, ThreadError, StorageError, ValidationError, ConfigError)
- ✅ Thread safety utilities
- ✅ Type conversions (DateTime, Option, HashMap, Vec)
- ✅ Replica class with Ruby idiomatic API
- ✅ Task class with Ruby idiomatic API
- ✅ Tag and Annotation classes
- ✅ Status constants (:pending, :completed, :deleted, etc.)
- ✅ Operation and Operations classes
- ✅ Access mode support
- ✅ Minitest testing infrastructure
- ✅ GitHub Actions CI/CD

### TODO
- [ ] WorkingSet class implementation
- [ ] DependencyMap class implementation
- [ ] Complete Task mutation methods (requires Operations integration)
- [ ] Complete test suite porting from Python
- [ ] Cross-platform compilation
- [ ] YARD documentation
- [ ] RubyGems publication

## API Design

The Ruby API follows Ruby idioms:
- Method names use snake_case
- Boolean methods end with `?` (e.g., `active?`, `waiting?`)
- Property access doesn't use `get_` prefix (e.g., `task.uuid` not `task.get_uuid`)
- Keyword arguments for optional parameters
- `nil` instead of `None`
- Symbols for enums (e.g., `:read_only`, `:read_write`)

## Thread Safety

All TaskChampion objects are thread-local and will raise `Taskchampion::ThreadError` if accessed from a different thread than the one that created them.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/GothenburgBitFactory/taskchampion.
