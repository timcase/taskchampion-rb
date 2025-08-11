use magnus::{exception, prelude::*, Error, RModule};

pub fn init_errors(module: &RModule) -> Result<(), Error> {
    let error_class = module.define_error("Error", exception::standard_error())?;
    module.define_error("ThreadError", error_class)?;
    module.define_error("StorageError", error_class)?;
    module.define_error("ValidationError", error_class)?;
    module.define_error("ConfigError", error_class)?;
    module.define_error("SyncError", error_class)?;
    Ok(())
}

pub fn thread_error() -> magnus::ExceptionClass {
    let ruby = magnus::Ruby::get().expect("Ruby not available");
    let module = ruby.class_object().const_get::<_, RModule>("Taskchampion")
        .expect("Taskchampion module not found");
    module.const_get::<_, magnus::ExceptionClass>("ThreadError")
        .expect("ThreadError class not initialized")
}

pub fn storage_error() -> magnus::ExceptionClass {
    let ruby = magnus::Ruby::get().expect("Ruby not available");
    let module = ruby.class_object().const_get::<_, RModule>("Taskchampion")
        .expect("Taskchampion module not found");
    module.const_get::<_, magnus::ExceptionClass>("StorageError")
        .expect("StorageError class not initialized")
}

pub fn validation_error() -> magnus::ExceptionClass {
    let ruby = magnus::Ruby::get().expect("Ruby not available");
    let module = ruby.class_object().const_get::<_, RModule>("Taskchampion")
        .expect("Taskchampion module not found");
    module.const_get::<_, magnus::ExceptionClass>("ValidationError")
        .expect("ValidationError class not initialized")
}

pub fn config_error() -> magnus::ExceptionClass {
    let ruby = magnus::Ruby::get().expect("Ruby not available");
    let module = ruby.class_object().const_get::<_, RModule>("Taskchampion")
        .expect("Taskchampion module not found");
    module.const_get::<_, magnus::ExceptionClass>("ConfigError")
        .expect("ConfigError class not initialized")
}

pub fn sync_error() -> magnus::ExceptionClass {
    let ruby = magnus::Ruby::get().expect("Ruby not available");
    let module = ruby.class_object().const_get::<_, RModule>("Taskchampion")
        .expect("Taskchampion module not found");
    module.const_get::<_, magnus::ExceptionClass>("SyncError")
        .expect("SyncError class not initialized")
}

// Enhanced error mapping function with context-aware error types
pub fn map_taskchampion_error(error: taskchampion::Error) -> Error {
    let error_msg = error.to_string();
    
    // Map TaskChampion errors to appropriate Ruby error types based on error content
    if error_msg.contains("No such file") || error_msg.contains("Permission denied") || 
       error_msg.contains("storage") || error_msg.contains("database") {
        Error::new(storage_error(), format!("Storage error: {}", error_msg))
    } else if error_msg.contains("sync") || error_msg.contains("server") || 
              error_msg.contains("network") || error_msg.contains("remote") {
        Error::new(sync_error(), format!("Synchronization error: {}", error_msg))
    } else if error_msg.contains("config") || error_msg.contains("invalid config") {
        Error::new(config_error(), format!("Configuration error: {}", error_msg))
    } else if error_msg.contains("invalid") || error_msg.contains("parse") || 
              error_msg.contains("format") || error_msg.contains("validation") {
        Error::new(validation_error(), format!("Validation error: {}", error_msg))
    } else {
        // Generic TaskChampion error for unknown types
        let ruby = magnus::Ruby::get().expect("Ruby not available");
        let module = ruby.class_object().const_get::<_, RModule>("Taskchampion")
            .expect("Taskchampion module not found");
        let error_class = module.const_get::<_, magnus::ExceptionClass>("Error")
            .expect("Error class not initialized");
        Error::new(error_class, format!("TaskChampion error: {}", error_msg))
    }
}