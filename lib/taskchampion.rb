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
  end
end
