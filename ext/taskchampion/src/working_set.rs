use magnus::{
    class, method, prelude::*, Error, IntoValue, RModule, Value,
};
use std::sync::Arc;
use taskchampion::WorkingSet as TCWorkingSet;

use crate::thread_check::ThreadBound;

#[magnus::wrap(class = "Taskchampion::WorkingSet", free_immediately)]
pub struct WorkingSet(ThreadBound<Arc<TCWorkingSet>>);

impl WorkingSet {
    pub fn from_tc_working_set(tc_working_set: Arc<TCWorkingSet>) -> Self {
        WorkingSet(ThreadBound::new(tc_working_set))
    }

    fn largest_index(&self) -> Result<usize, Error> {
        let working_set = self.0.get()?;
        Ok(working_set.largest_index())
    }

    fn by_index(&self, index: usize) -> Result<Value, Error> {
        let working_set = self.0.get()?;
        match working_set.by_index(index) {
            Some(uuid) => {
                // WorkingSet returns UUID, not Task
                Ok(uuid.to_string().into_value())
            }
            None => Ok(().into_value()),
        }
    }

    fn by_uuid(&self, uuid: String) -> Result<Value, Error> {
        let working_set = self.0.get()?;
        let tc_uuid = crate::util::uuid2tc(&uuid)?;
        
        match working_set.by_uuid(tc_uuid) {
            Some(index) => Ok(index.into_value()),
            None => Ok(().into_value()),
        }
    }

    fn renumber(&self) -> Result<(), Error> {
        let _working_set = self.0.get()?;
        // Note: renumber requires &mut self in TaskChampion, but WorkingSet is immutable
        // This is a limitation we'll need to work around or document
        Err(Error::new(
            magnus::exception::runtime_error(),
            "WorkingSet renumber is not implemented due to mutability constraints",
        ))
    }

    fn inspect(&self) -> Result<String, Error> {
        let working_set = self.0.get()?;
        Ok(format!(
            "#<Taskchampion::WorkingSet: largest_index={}>",
            working_set.largest_index()
        ))
    }
}

pub fn init(module: &RModule) -> Result<(), Error> {
    let class = module.define_class("WorkingSet", class::object())?;
    
    class.define_method("largest_index", method!(WorkingSet::largest_index, 0))?;
    class.define_method("by_index", method!(WorkingSet::by_index, 1))?;
    class.define_method("by_uuid", method!(WorkingSet::by_uuid, 1))?;
    class.define_method("renumber", method!(WorkingSet::renumber, 0))?;
    class.define_method("inspect", method!(WorkingSet::inspect, 0))?;
    
    Ok(())
}