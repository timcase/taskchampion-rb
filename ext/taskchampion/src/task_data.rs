use magnus::{
    class, function, method, prelude::*, Error, IntoValue, RArray, RHash, RModule, Value,
};
use taskchampion::TaskData as TCTaskData;

use crate::operations::Operations;
use crate::thread_check::ThreadBound;
use crate::util::{option_to_ruby, uuid2tc, vec_to_ruby};

#[magnus::wrap(class = "Taskchampion::TaskData", free_immediately)]
pub struct TaskData(ThreadBound<TCTaskData>);

impl TaskData {
    pub fn from_tc_task_data(tc_task_data: TCTaskData) -> Self {
        TaskData(ThreadBound::new(tc_task_data))
    }
    fn inspect(&self) -> Result<String, Error> {
        let task_data = self.0.get()?;
        Ok(format!("#<Taskchampion::TaskData: {}>", task_data.get_uuid()))
    }

    fn uuid(&self) -> Result<String, Error> {
        let task_data = self.0.get()?;
        Ok(task_data.get_uuid().to_string())
    }

    fn get(&self, property: String) -> Result<Value, Error> {
        let task_data = self.0.get()?;
        option_to_ruby(task_data.get(&property), |s| Ok(s.into_value()))
    }

    fn has(&self, property: String) -> Result<bool, Error> {
        let task_data = self.0.get()?;
        Ok(task_data.has(&property))
    }

    fn properties(&self) -> Result<RArray, Error> {
        let task_data = self.0.get()?;
        let props: Vec<String> = task_data.properties().cloned().collect();
        vec_to_ruby(props, |s| Ok(s.into_value()))
    }

    fn to_hash(&self) -> Result<RHash, Error> {
        let task_data = self.0.get()?;
        let hash = RHash::new();

        for (key, value) in task_data.iter() {
            hash.aset(key.clone(), value.clone())?;
        }

        Ok(hash)
    }

    fn update(&self, property: String, value: Value, operations: &Operations) -> Result<(), Error> {
        if property.trim().is_empty() {
            return Err(Error::new(
                crate::error::validation_error(),
                "Property name cannot be empty or whitespace-only"
            ));
        }

        let mut task_data = self.0.get_mut()?;
        let value_str = if value.is_nil() {
            None
        } else {
            Some(value.to_string())
        };

        operations.with_inner_mut(|ops| {
            task_data.update(&property, value_str, ops);
            Ok(())
        })?;

        Ok(())
    }

    fn delete(&self, operations: &Operations) -> Result<(), Error> {
        let mut task_data = self.0.get_mut()?;

        operations.with_inner_mut(|ops| {
            task_data.delete(ops);
            Ok(())
        })?;

        Ok(())
    }
}

fn create_task_data(uuid: String, operations: &Operations) -> Result<TaskData, Error> {
    let tc_uuid = uuid2tc(&uuid)?;

    // Create operations for TaskChampion
    let mut tc_ops = taskchampion::Operations::new();

    // Create the TaskData
    let tc_task_data = TCTaskData::create(tc_uuid, &mut tc_ops);

    // Add the resulting operations to the provided Operations object
    operations.extend_from_tc(tc_ops.into_iter().collect())?;

    Ok(TaskData(ThreadBound::new(tc_task_data)))
}

pub fn init(module: &RModule) -> Result<(), Error> {
    let class = module.define_class("TaskData", class::object())?;

    // Class methods
    class.define_singleton_method("create", function!(create_task_data, 2))?;

    // Instance methods
    class.define_method("inspect", method!(TaskData::inspect, 0))?;
    class.define_method("uuid", method!(TaskData::uuid, 0))?;
    class.define_method("get", method!(TaskData::get, 1))?;
    class.define_method("has?", method!(TaskData::has, 1))?;
    class.define_method("properties", method!(TaskData::properties, 0))?;
    class.define_method("to_hash", method!(TaskData::to_hash, 0))?;
    class.define_method("to_h", method!(TaskData::to_hash, 0))?;
    class.define_method("update", method!(TaskData::update, 3))?;
    class.define_method("delete", method!(TaskData::delete, 1))?;

    Ok(())
}
