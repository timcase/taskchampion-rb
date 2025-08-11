use magnus::{
    class, method, prelude::*, Error, IntoValue, RArray, RModule, Ruby, Symbol, Value,
};
use chrono::{DateTime, Utc};
use taskchampion::Task as TCTask;

use crate::annotation::Annotation;
use crate::status::Status;
use crate::tag::Tag;
use crate::thread_check::ThreadBound;
use crate::util::{datetime_to_ruby, into_error, option_to_ruby, ruby_to_datetime, ruby_to_option, uuid2tc, vec_to_ruby};
use crate::{check_thread};

#[magnus::wrap(class = "Taskchampion::Task", free_immediately)]
pub struct Task(ThreadBound<TCTask>);

impl Task {
    pub fn from_tc_task(tc_task: TCTask) -> Self {
        Task(ThreadBound::new(tc_task))
    }

    fn inspect(&self) -> Result<String, Error> {
        let task = self.0.get()?;
        Ok(format!("#<Taskchampion::Task: {}>", task.get_uuid()))
    }

    fn uuid(&self) -> Result<String, Error> {
        let task = self.0.get()?;
        Ok(task.get_uuid().to_string())
    }

    fn status(&self) -> Result<Symbol, Error> {
        let task = self.0.get()?;
        Ok(Status::from(task.get_status()).to_symbol())
    }

    fn description(&self) -> Result<String, Error> {
        let task = self.0.get()?;
        Ok(task.get_description().to_string())
    }

    fn entry(&self) -> Result<Value, Error> {
        let task = self.0.get()?;
        option_to_ruby(task.get_entry(), datetime_to_ruby)
    }

    fn priority(&self) -> Result<String, Error> {
        let task = self.0.get()?;
        Ok(task.get_priority().to_string())
    }

    fn wait(&self) -> Result<Value, Error> {
        let task = self.0.get()?;
        option_to_ruby(task.get_wait(), datetime_to_ruby)
    }

    fn modified(&self) -> Result<Value, Error> {
        let task = self.0.get()?;
        option_to_ruby(task.get_modified(), datetime_to_ruby)
    }

    fn due(&self) -> Result<Value, Error> {
        let task = self.0.get()?;
        option_to_ruby(task.get_due(), datetime_to_ruby)
    }

    fn dependencies(&self) -> Result<RArray, Error> {
        let task = self.0.get()?;
        let deps: Vec<String> = task.get_dependencies().map(|uuid| uuid.to_string()).collect();
        vec_to_ruby(deps, |s| Ok(s.into_value()))
    }

    // Boolean methods with ? suffix
    fn waiting(&self) -> Result<bool, Error> {
        let task = self.0.get()?;
        Ok(task.is_waiting())
    }

    fn active(&self) -> Result<bool, Error> {
        let task = self.0.get()?;
        Ok(task.is_active())
    }

    fn blocked(&self) -> Result<bool, Error> {
        let task = self.0.get()?;
        Ok(task.is_blocked())
    }

    fn blocking(&self) -> Result<bool, Error> {
        let task = self.0.get()?;
        Ok(task.is_blocking())
    }

    fn completed(&self) -> Result<bool, Error> {
        let task = self.0.get()?;
        Ok(task.get_status() == taskchampion::Status::Completed)
    }

    fn deleted(&self) -> Result<bool, Error> {
        let task = self.0.get()?;
        Ok(task.get_status() == taskchampion::Status::Deleted)
    }

    fn pending(&self) -> Result<bool, Error> {
        let task = self.0.get()?;
        Ok(task.get_status() == taskchampion::Status::Pending)
    }

    // Tag methods
    fn has_tag(&self, tag: &Tag) -> Result<bool, Error> {
        let task = self.0.get()?;
        Ok(task.has_tag(tag.as_ref()))
    }

    fn tags(&self) -> Result<RArray, Error> {
        let task = self.0.get()?;
        let tags: Vec<Tag> = task.get_tags().map(Tag::from).collect();
        vec_to_ruby(tags, |tag| {
            Ok(tag.into_value()) // Convert to Value using IntoValue trait
        })
    }

    fn annotations(&self) -> Result<RArray, Error> {
        let task = self.0.get()?;
        let annotations: Vec<Annotation> = task.get_annotations().map(Annotation::from).collect();
        vec_to_ruby(annotations, |ann| {
            Ok(ann.into_value()) // Convert to Value using IntoValue trait
        })
    }

    // Value access
    fn get_value(&self, property: String) -> Result<Value, Error> {
        let task = self.0.get()?;
        match task.get_value(property) {
            Some(value) => Ok(value.into_value()),
            None => Ok(().into_value()), // () converts to nil in Magnus
        }
    }

    fn get_uda(&self, namespace: String, key: String) -> Result<Value, Error> {
        let task = self.0.get()?;
        match task.get_uda(&namespace, &key) {
            Some(value) => Ok(value.into_value()),
            None => Ok(().into_value()), // () converts to nil in Magnus
        }
    }

    fn udas(&self) -> Result<RArray, Error> {
        let task = self.0.get()?;
        let udas: Vec<((String, String), String)> = task.get_udas()
            .map(|((ns, key), value)| ((ns.to_string(), key.to_string()), value.to_string()))
            .collect();

        vec_to_ruby(udas, |(key_tuple, value)| {
            let array = RArray::new();
            let key_array = RArray::new();
            key_array.push(key_tuple.0)?;
            key_array.push(key_tuple.1)?;
            array.push(key_array)?;
            array.push(value)?;
            Ok(array.into_value())
        })
    }

    // Mutation methods that require Operations parameter
    fn set_description(&self, description: String, operations: &crate::operations::Operations) -> Result<(), Error> {
        let mut task = self.0.get()?;
        let ops = &mut operations.clone_inner();
        task.set_description(ops, description)
            .map_err(into_error)
    }

    fn set_status(&self, status: Symbol, operations: &crate::operations::Operations) -> Result<(), Error> {
        let mut task = self.0.get()?;
        let status = Status::from_symbol(status)?;
        let ops = &mut operations.clone_inner();
        task.set_status(ops, status.into())
            .map_err(into_error)
    }

    fn set_priority(&self, priority: String, operations: &crate::operations::Operations) -> Result<(), Error> {
        let mut task = self.0.get()?;
        let ops = &mut operations.clone_inner();
        task.set_priority(ops, &priority)
            .map_err(into_error)
    }

    fn add_tag(&self, tag: &Tag, operations: &crate::operations::Operations) -> Result<(), Error> {
        let mut task = self.0.get()?;
        let ops = &mut operations.clone_inner();
        task.add_tag(ops, tag.as_ref())
            .map_err(into_error)
    }

    fn remove_tag(&self, tag: &Tag, operations: &crate::operations::Operations) -> Result<(), Error> {
        let mut task = self.0.get()?;
        let ops = &mut operations.clone_inner();
        task.remove_tag(ops, tag.as_ref())
            .map_err(into_error)
    }

    fn add_annotation(&self, description: String, operations: &crate::operations::Operations) -> Result<(), Error> {
        let mut task = self.0.get()?;
        let ops = &mut operations.clone_inner();
        task.add_annotation(ops, description)
            .map_err(into_error)
    }

    fn set_due(&self, due: Value, operations: &crate::operations::Operations) -> Result<(), Error> {
        let mut task = self.0.get()?;
        let ops = &mut operations.clone_inner();
        let due_datetime = ruby_to_option(due, ruby_to_datetime)?;
        task.set_due(ops, due_datetime)
            .map_err(into_error)
    }

    fn set_value(&self, property: String, value: Value, operations: &crate::operations::Operations) -> Result<(), Error> {
        let mut task = self.0.get()?;
        let ops = &mut operations.clone_inner();
        let value_str = if value.is_nil() {
            None
        } else {
            Some(value.to_string())
        };
        task.set_value(ops, &property, value_str)
            .map_err(into_error)
    }

    fn set_uda(&self, namespace: String, key: String, value: String, operations: &crate::operations::Operations) -> Result<(), Error> {
        let mut task = self.0.get()?;
        let ops = &mut operations.clone_inner();
        task.set_uda(ops, &namespace, &key, &value)
            .map_err(into_error)
    }

    fn delete_uda(&self, namespace: String, key: String, operations: &crate::operations::Operations) -> Result<(), Error> {
        let mut task = self.0.get()?;
        let ops = &mut operations.clone_inner();
        task.remove_uda(ops, &namespace, &key)
            .map_err(into_error)
    }

    // Ruby-style setter methods (convenience wrappers)
    // Note: These require an Operations object to be passed to the Ruby method
    fn set_description_eq(&self, description: String, operations: &crate::operations::Operations) -> Result<(), Error> {
        self.set_description(description, operations)
    }

    fn set_status_eq(&self, status: Symbol, operations: &crate::operations::Operations) -> Result<(), Error> {
        self.set_status(status, operations)
    }

    fn set_priority_eq(&self, priority: String, operations: &crate::operations::Operations) -> Result<(), Error> {
        self.set_priority(priority, operations)
    }
}

// Remove AsRef implementation as it doesn't work well with thread bounds
// Use direct method calls instead

impl From<TCTask> for Task {
    fn from(value: TCTask) -> Self {
        Task(ThreadBound::new(value))
    }
}

pub fn init(module: &RModule) -> Result<(), Error> {
    let class = module.define_class("Task", class::object())?;

    // Property methods (Ruby idiomatic - no get_ prefix)
    class.define_method("inspect", method!(Task::inspect, 0))?;
    class.define_method("uuid", method!(Task::uuid, 0))?;
    class.define_method("status", method!(Task::status, 0))?;
    class.define_method("description", method!(Task::description, 0))?;
    class.define_method("entry", method!(Task::entry, 0))?;
    class.define_method("priority", method!(Task::priority, 0))?;
    class.define_method("wait", method!(Task::wait, 0))?;
    class.define_method("modified", method!(Task::modified, 0))?;
    class.define_method("due", method!(Task::due, 0))?;
    class.define_method("dependencies", method!(Task::dependencies, 0))?;

    // Boolean methods with ? suffix
    class.define_method("waiting?", method!(Task::waiting, 0))?;
    class.define_method("active?", method!(Task::active, 0))?;
    class.define_method("blocked?", method!(Task::blocked, 0))?;
    class.define_method("blocking?", method!(Task::blocking, 0))?;
    class.define_method("completed?", method!(Task::completed, 0))?;
    class.define_method("deleted?", method!(Task::deleted, 0))?;
    class.define_method("pending?", method!(Task::pending, 0))?;

    // Tag methods
    class.define_method("has_tag?", method!(Task::has_tag, 1))?;
    class.define_method("tags", method!(Task::tags, 0))?;
    class.define_method("annotations", method!(Task::annotations, 0))?;

    // Value access - Ruby convention: no get_ prefix
    class.define_method("value", method!(Task::get_value, 1))?;
    class.define_method("get_value", method!(Task::get_value, 1))?;  // Keep for backward compatibility
    class.define_method("uda", method!(Task::get_uda, 2))?;
    class.define_method("get_uda", method!(Task::get_uda, 2))?;    // Keep for backward compatibility
    class.define_method("udas", method!(Task::udas, 0))?;

    // Mutation methods
    class.define_method("set_description", method!(Task::set_description, 2))?;
    class.define_method("set_status", method!(Task::set_status, 2))?;
    class.define_method("set_priority", method!(Task::set_priority, 2))?;
    class.define_method("add_tag", method!(Task::add_tag, 2))?;
    class.define_method("remove_tag", method!(Task::remove_tag, 2))?;
    class.define_method("add_annotation", method!(Task::add_annotation, 2))?;
    class.define_method("set_due", method!(Task::set_due, 2))?;
    class.define_method("set_value", method!(Task::set_value, 3))?;
    class.define_method("set_uda", method!(Task::set_uda, 4))?;
    class.define_method("delete_uda", method!(Task::delete_uda, 3))?;

    // Ruby-style setter methods (require operations parameter)
    class.define_method("description=", method!(Task::set_description_eq, 2))?;
    class.define_method("status=", method!(Task::set_status_eq, 2))?;
    class.define_method("priority=", method!(Task::set_priority_eq, 2))?;

    Ok(())
}