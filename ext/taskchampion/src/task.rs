use magnus::{
    class, method, prelude::*, Error, IntoValue, RArray, RModule, Symbol, TryConvert, Value,
};
use taskchampion::Task as TCTask;

use crate::annotation::Annotation;
use crate::status::Status;
use crate::tag::Tag;
use crate::thread_check::ThreadBound;
use crate::util::{datetime_to_ruby, option_to_ruby, ruby_to_datetime, ruby_to_option, vec_to_ruby};

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
        if description.trim().is_empty() {
            return Err(Error::new(
                crate::error::validation_error(),
                "Description cannot be empty or whitespace-only"
            ));
        }

        let mut task = self.0.get_mut()?;
        operations.with_inner_mut(|ops| {
            task.set_description(description.clone(), ops)
        })?;
        Ok(())
    }

    fn set_status(&self, status: Value, operations: &crate::operations::Operations) -> Result<(), Error> {
        let mut task = self.0.get_mut()?;

        // Handle both Status objects and symbols
        let status = if let Ok(status_obj) = <&Status>::try_convert(status) {
            *status_obj // Copy the Status object
        } else if let Ok(symbol) = Symbol::try_convert(status) {
            Status::from_symbol(symbol)?
        } else {
            return Err(Error::new(
                crate::error::validation_error(),
                "Status must be a Taskchampion::Status object or a symbol (:pending, :completed, :deleted, etc.)"
            ));
        };

        operations.with_inner_mut(|ops| {
            task.set_status(status.into(), ops)
        })?;
        Ok(())
    }

    fn set_priority(&self, priority: String, operations: &crate::operations::Operations) -> Result<(), Error> {
        if priority.trim().is_empty() {
            return Err(Error::new(
                crate::error::validation_error(),
                "Priority cannot be empty or whitespace-only"
            ));
        }

        let mut task = self.0.get_mut()?;
        operations.with_inner_mut(|ops| {
            task.set_priority(priority.clone(), ops)
        })?;
        Ok(())
    }

    fn add_tag(&self, tag: &Tag, operations: &crate::operations::Operations) -> Result<(), Error> {
        let mut task = self.0.get_mut()?;
        operations.with_inner_mut(|ops| {
            task.add_tag(tag.as_ref(), ops)
        })?;
        Ok(())
    }

    fn remove_tag(&self, tag: &Tag, operations: &crate::operations::Operations) -> Result<(), Error> {
        let mut task = self.0.get_mut()?;
        operations.with_inner_mut(|ops| {
            task.remove_tag(tag.as_ref(), ops)
        })?;
        Ok(())
    }

    fn add_annotation(&self, description: String, operations: &crate::operations::Operations) -> Result<(), Error> {
        if description.trim().is_empty() {
            return Err(Error::new(
                crate::error::validation_error(),
                "Annotation description cannot be empty or whitespace-only"
            ));
        }

        let mut task = self.0.get_mut()?;
        use chrono::Utc;
        use std::sync::atomic::{AtomicU64, Ordering};

        // Use an atomic counter to ensure unique second-level timestamps
        // TaskChampion appears to truncate sub-second precision in property keys
        static ANNOTATION_COUNTER: AtomicU64 = AtomicU64::new(0);
        let counter = ANNOTATION_COUNTER.fetch_add(1, Ordering::SeqCst);

        // Get current time and add second offset to ensure uniqueness at TaskChampion's precision level
        let base_time = Utc::now();
        let now = base_time + chrono::Duration::seconds(counter as i64);
        let annotation = taskchampion::Annotation { entry: now, description: description.clone() };
        operations.with_inner_mut(|ops| {
            task.add_annotation(annotation, ops)
        })?;
        Ok(())
    }

    fn set_due(&self, due: Value, operations: &crate::operations::Operations) -> Result<(), Error> {
        let mut task = self.0.get_mut()?;
        let due_datetime = ruby_to_option(due, ruby_to_datetime)?;
        operations.with_inner_mut(|ops| {
            task.set_due(due_datetime, ops)
        })?;
        Ok(())
    }

    fn set_entry(&self, entry: Value, operations: &crate::operations::Operations) -> Result<(), Error> {
        let mut task = self.0.get_mut()?;
        let entry_datetime = ruby_to_option(entry, ruby_to_datetime)?;
        operations.with_inner_mut(|ops| {
            task.set_entry(entry_datetime, ops)
        })?;
        Ok(())
    }

    fn set_value(&self, property: String, value: Value, operations: &crate::operations::Operations) -> Result<(), Error> {
        if property.trim().is_empty() {
            return Err(Error::new(
                crate::error::validation_error(),
                "Property name cannot be empty or whitespace-only"
            ));
        }

        let mut task = self.0.get_mut()?;
        let value_str = if value.is_nil() {
            None
        } else {
            Some(value.to_string())
        };
        operations.with_inner_mut(|ops| {
            task.set_value(&property, value_str, ops)
        })?;
        Ok(())
    }

    fn set_timestamp(&self, property: String, timestamp: Value, operations: &crate::operations::Operations) -> Result<(), Error> {
        if property.trim().is_empty() {
            return Err(Error::new(
                crate::error::validation_error(),
                "Property name cannot be empty or whitespace-only"
            ));
        }

        let mut task = self.0.get_mut()?;
        let timestamp_datetime = ruby_to_option(timestamp, ruby_to_datetime)?;

        // Convert timestamp to Unix timestamp string, or None for clearing
        let timestamp_str = timestamp_datetime.map(|dt| dt.timestamp().to_string());

        operations.with_inner_mut(|ops| {
            task.set_value(&property, timestamp_str, ops)
        })?;
        Ok(())
    }

    fn get_timestamp(&self, property: String) -> Result<Value, Error> {
        if property.trim().is_empty() {
            return Err(Error::new(
                crate::error::validation_error(),
                "Property name cannot be empty or whitespace-only"
            ));
        }

        let task = self.0.get()?;

        // Get the value as string and attempt to parse as Unix timestamp
        match task.get_value(&property) {
            Some(timestamp_str) => {
                // Parse the string as Unix timestamp (seconds since epoch)
                if let Ok(timestamp_secs) = timestamp_str.parse::<i64>() {
                    use chrono::{DateTime, Utc};
                    if let Some(dt) = DateTime::from_timestamp(timestamp_secs, 0) {
                        return datetime_to_ruby(dt);
                    }
                }
                // If parsing fails, return nil
                Ok(().into_value())
            },
            None => Ok(().into_value()) // Return nil if property doesn't exist
        }
    }

    fn set_uda(&self, namespace: String, key: String, value: String, operations: &crate::operations::Operations) -> Result<(), Error> {
        if namespace.trim().is_empty() {
            return Err(Error::new(
                crate::error::validation_error(),
                "UDA namespace cannot be empty or whitespace-only"
            ));
        }
        if key.trim().is_empty() {
            return Err(Error::new(
                crate::error::validation_error(),
                "UDA key cannot be empty or whitespace-only"
            ));
        }

        let mut task = self.0.get_mut()?;
        operations.with_inner_mut(|ops| {
            task.set_uda(&namespace, &key, &value, ops)
        })?;
        Ok(())
    }

    fn delete_uda(&self, namespace: String, key: String, operations: &crate::operations::Operations) -> Result<(), Error> {
        if namespace.trim().is_empty() {
            return Err(Error::new(
                crate::error::validation_error(),
                "UDA namespace cannot be empty or whitespace-only"
            ));
        }
        if key.trim().is_empty() {
            return Err(Error::new(
                crate::error::validation_error(),
                "UDA key cannot be empty or whitespace-only"
            ));
        }

        let mut task = self.0.get_mut()?;
        operations.with_inner_mut(|ops| {
            task.remove_uda(&namespace, &key, ops)
        })?;
        Ok(())
    }

    fn done(&self, operations: &crate::operations::Operations) -> Result<(), Error> {
        let mut task = self.0.get_mut()?;
        operations.with_inner_mut(|ops| {
            task.done(ops)
        })?;
        Ok(())
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
    class.define_method("set_entry", method!(Task::set_entry, 2))?;
    class.define_method("set_value", method!(Task::set_value, 3))?;
    class.define_method("set_timestamp", method!(Task::set_timestamp, 3))?;
    class.define_method("get_timestamp", method!(Task::get_timestamp, 1))?;
    class.define_method("set_uda", method!(Task::set_uda, 4))?;
    class.define_method("delete_uda", method!(Task::delete_uda, 3))?;
    class.define_method("done", method!(Task::done, 1))?;
    Ok(())
}
