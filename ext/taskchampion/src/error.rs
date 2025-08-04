use magnus::{exception, prelude::*, Error, RModule};

pub fn init_errors(module: &RModule) -> Result<(), Error> {
    let error_class = module.define_error("Error", exception::standard_error())?;
    module.define_error("ThreadError", error_class)?;
    module.define_error("StorageError", error_class)?;
    module.define_error("ValidationError", error_class)?;
    module.define_error("ConfigError", error_class)?;
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