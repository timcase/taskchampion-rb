use magnus::{Error, Ruby};

mod error;
mod thread_check;
mod util;
mod access_mode;
mod status;
mod tag;
mod annotation;
mod task;
mod operation;
mod operations;
mod replica;
mod working_set;
mod dependency_map;

use error::init_errors;

#[magnus::init]
fn init(ruby: &Ruby) -> Result<(), Error> {
    let module = ruby.define_module("Taskchampion")?;

    // Initialize error classes
    init_errors(&module)?;

    // Initialize constants
    access_mode::init(&module)?;
    status::init(&module)?;

    // Initialize classes
    tag::init(&module)?;
    annotation::init(&module)?;
    task::init(&module)?;
    operation::init(&module)?;
    operations::init(&module)?;
    working_set::init(&module)?;
    dependency_map::init(&module)?;
    replica::init(&module)?;

    Ok(())
}
