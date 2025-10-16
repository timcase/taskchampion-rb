# frozen_string_literal: true

require_relative "taskchampion/version"
require_relative "taskchampion/taskchampion" # This loads the Rust extension

module Taskchampion
  # Error classes are defined in Rust
  # Replica class is defined in Rust
  # Additional Ruby-level helpers can be added here

  # Override WorkingSet to add task lookup functionality
  class WorkingSet
    # Store replica reference for task lookup
    attr_accessor :replica

    alias_method :_original_by_index, :by_index

    def by_index(index)
      uuid_string = _original_by_index(index)
      return nil if uuid_string.nil? || uuid_string.to_s.empty?

      # If we have a replica reference, look up the actual task
      if @replica
        @replica.task(uuid_string)
      else
        uuid_string
      end
    end
  end

  # Override the Replica class to set the replica reference
  class Replica
    alias_method :_original_working_set, :working_set

    def working_set
      ws = _original_working_set
      ws.replica = self
      ws
    end

    # Ruby-style convenience methods for undo functionality
    def task_operations(uuid)
      get_task_operations(uuid)
    end

    def undo_operations
      get_undo_operations
    end

    def commit_undo!(operations)
      commit_reversed_operations(operations)
    end

    def undo!
      ops = undo_operations
      return false if ops.empty?
      commit_undo!(ops)
    end
  end

  # Task convenience methods
  class Task
    # Update an existing annotation's description while preserving its timestamp
    #
    # This is a convenience method that removes the old annotation and adds a new one
    # with the same timestamp, effectively updating the description while maintaining
    # the original creation time for chronological history.
    #
    # @param annotation [Taskchampion::Annotation] The annotation to update
    # @param new_description [String] The new description text
    # @param operations [Taskchampion::Operations] Operations collection
    # @return [void]
    #
    # @example Update an annotation
    #   annotation = task.annotations.first
    #   task.update_annotation(annotation, "Updated note", operations)
    #   replica.commit_operations(operations)
    #
    # @raise [Taskchampion::ValidationError] if new_description is empty or whitespace-only
    def update_annotation(annotation, new_description, operations)
      # Remove the old annotation
      remove_annotation(annotation, operations)

      # Add new annotation with the preserved timestamp
      add_annotation_with_timestamp(annotation.entry, new_description, operations)
    end
  end
end
