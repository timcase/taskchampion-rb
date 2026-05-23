use magnus::{exception, prelude::*, Error, RModule};

pub fn init_errors(module: &RModule) -> Result<(), Error> {
    let error_class = module.define_error("Error", exception::standard_error())?;
    module.define_error("ThreadError", error_class)?;
    module.define_error("StorageError", error_class)?;
    module.define_error("ValidationError", error_class)?;
    module.define_error("ConfigError", error_class)?;
    let sync_error_class = module.define_error("SyncError", error_class)?;
    module.define_error("OutOfSyncError", sync_error_class)?;
    Ok(())
}

pub fn base_error() -> magnus::ExceptionClass {
    let ruby = magnus::Ruby::get().expect("Ruby not available");
    let module = ruby.class_object().const_get::<_, RModule>("Taskchampion")
        .expect("Taskchampion module not found");
    module.const_get::<_, magnus::ExceptionClass>("Error")
        .expect("Error class not initialized")
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

pub fn sync_error() -> magnus::ExceptionClass {
    let ruby = magnus::Ruby::get().expect("Ruby not available");
    let module = ruby.class_object().const_get::<_, RModule>("Taskchampion")
        .expect("Taskchampion module not found");
    module.const_get::<_, magnus::ExceptionClass>("SyncError")
        .expect("SyncError class not initialized")
}

pub fn out_of_sync_error() -> magnus::ExceptionClass {
    let ruby = magnus::Ruby::get().expect("Ruby not available");
    let module = ruby.class_object().const_get::<_, RModule>("Taskchampion")
        .expect("Taskchampion module not found");
    module.const_get::<_, magnus::ExceptionClass>("OutOfSyncError")
        .expect("OutOfSyncError class not initialized")
}

pub fn map_taskchampion_error(error: taskchampion::Error) -> Error {
    match error {
        taskchampion::Error::Database(msg) => Error::new(storage_error(), msg),
        taskchampion::Error::Server(msg)   => Error::new(sync_error(), msg),
        taskchampion::Error::OutOfSync     => Error::new(out_of_sync_error(),
                                                 "Local replica is out of sync with the server"),
        taskchampion::Error::Usage(msg)    => Error::new(validation_error(), msg),
        _                                  => Error::new(storage_error(), error.to_string()),
    }
}
