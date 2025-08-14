# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build and Development Commands

### Building the gem
```bash
bundle install
bundle exec rake compile  # Compiles the Rust extension
```

### Running tests
```bash
bundle exec rake test              # Run all tests
bundle exec rake test TEST=test/test_replica.rb  # Run specific test file
```

### Linting
```bash
bundle exec rake rubocop           # Run RuboCop linter
```

### Publishing new version
```bash
rake publish[patch]  # Bump patch version and release
rake publish[minor]  # Bump minor version and release
rake publish[major]  # Bump major version and release
```

## Architecture Overview

This is a Ruby gem that provides bindings to TaskChampion (Rust library) for task management. The architecture consists of:

### Key Components

1. **Rust Extension** (`ext/taskchampion/`)
   - Written in Rust using Magnus for Ruby-Rust interop
   - Entry point: `ext/taskchampion/src/lib.rs`
   - Implements core classes: Replica, Task, WorkingSet, Operations, etc.
   - Thread safety enforced via `thread_check.rs` - objects can only be accessed from their creation thread

2. **Ruby Layer** (`lib/taskchampion.rb`)
   - Thin wrapper that loads the Rust extension
   - Extends WorkingSet and Replica classes with Ruby-specific convenience methods
   - Maintains Ruby idioms (snake_case methods, `?` suffix for booleans)

3. **Core Classes**
   - `Replica`: Main database interface for task storage (in-memory or on-disk)
   - `Task`: Individual task with properties and methods
   - `Operations`: Collection of operations for batch changes
   - `WorkingSet`: Active subset of tasks
   - `DependencyMap`: Task dependency management
   - Error hierarchy: Error → ThreadError, StorageError, ValidationError, ConfigError

### Testing Structure
- Uses Minitest framework
- Tests organized in `test/unit/`, `test/integration/`, and `test/performance/`
- Base test class: `TaskchampionTest` in `test/test_helper.rb`
- Tests use temporary directories for file-based replicas

### Ruby API Design Principles
- Methods use snake_case (not get_/set_ prefixes)
- Boolean methods end with `?`
- Symbols for enums (`:pending`, `:completed`, `:read_only`)
- `nil` instead of None
- Keyword arguments for optional parameters