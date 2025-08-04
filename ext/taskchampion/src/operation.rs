use magnus::{
    class, function, method, prelude::*, Error, IntoValue, RHash, RModule, Ruby, Value,
};
use chrono::{DateTime, Utc};
use std::collections::HashMap;
use taskchampion::Operation as TCOperation;

use crate::util::{datetime_to_ruby, ruby_to_datetime, ruby_to_hashmap, uuid2tc};
use crate::error::validation_error;

#[magnus::wrap(class = "Taskchampion::Operation", free_immediately)]
pub struct Operation(TCOperation);

impl Operation {
    fn create(uuid: String) -> Result<Self, Error> {
        Ok(Operation(TCOperation::Create {
            uuid: uuid2tc(&uuid)?,
        }))
    }

    fn delete(uuid: String, old_task: RHash) -> Result<Self, Error> {
        let old_task = ruby_to_hashmap(old_task)?;
        Ok(Operation(TCOperation::Delete {
            uuid: uuid2tc(&uuid)?,
            old_task,
        }))
    }

    fn update(
        uuid: String,
        property: String,
        timestamp: Value,
        old_value: Option<String>,
        value: Option<String>,
    ) -> Result<Self, Error> {
        let timestamp = ruby_to_datetime(timestamp)?;
        Ok(Operation(TCOperation::Update {
            uuid: uuid2tc(&uuid)?,
            property,
            timestamp,
            old_value,
            value,
        }))
    }

    fn undo_point() -> Self {
        Operation(TCOperation::UndoPoint)
    }

    // Type checking methods
    fn create_op(&self) -> bool {
        matches!(self.0, TCOperation::Create { .. })
    }

    fn delete_op(&self) -> bool {
        matches!(self.0, TCOperation::Delete { .. })
    }

    fn update_op(&self) -> bool {
        matches!(self.0, TCOperation::Update { .. })
    }

    fn undo_point_op(&self) -> bool {
        matches!(self.0, TCOperation::UndoPoint)
    }

    // Getters for each variant
    fn uuid(&self) -> Result<String, Error> {
        match &self.0 {
            TCOperation::Create { uuid } => Ok(uuid.to_string()),
            TCOperation::Delete { uuid, .. } => Ok(uuid.to_string()),
            TCOperation::Update { uuid, .. } => Ok(uuid.to_string()),
            TCOperation::UndoPoint => Err(Error::new(
                magnus::exception::arg_error(),
                "UndoPoint operations do not have a uuid",
            )),
        }
    }

    fn old_task(&self) -> Result<RHash, Error> {
        match &self.0 {
            TCOperation::Delete { old_task, .. } => {
                let hash = RHash::new();
                for (k, v) in old_task {
                    hash.aset(k.clone(), v.clone())?;
                }
                Ok(hash)
            }
            _ => Err(Error::new(
                magnus::exception::arg_error(),
                "Only Delete operations have old_task",
            )),
        }
    }

    fn property(&self) -> Result<String, Error> {
        match &self.0 {
            TCOperation::Update { property, .. } => Ok(property.clone()),
            _ => Err(Error::new(
                magnus::exception::arg_error(),
                "Only Update operations have property",
            )),
        }
    }

    fn timestamp(&self) -> Result<Value, Error> {
        match &self.0 {
            TCOperation::Update { timestamp, .. } => datetime_to_ruby(*timestamp),
            _ => Err(Error::new(
                magnus::exception::arg_error(),
                "Only Update operations have timestamp",
            )),
        }
    }

    fn old_value(&self) -> Result<Value, Error> {
        match &self.0 {
            TCOperation::Update { old_value, .. } => match old_value {
                Some(val) => Ok(val.clone().into_value()),
                None => Ok(().into_value()), // () converts to nil in Magnus
            },
            _ => Err(Error::new(
                magnus::exception::arg_error(),
                "Only Update operations have old_value",
            )),
        }
    }

    fn value(&self) -> Result<Value, Error> {
        match &self.0 {
            TCOperation::Update { value, .. } => match value {
                Some(val) => Ok(val.clone().into_value()),
                None => Ok(().into_value()), // () converts to nil in Magnus
            },
            _ => Err(Error::new(
                magnus::exception::arg_error(),
                "Only Update operations have value",
            )),
        }
    }

    fn inspect(&self) -> String {
        match &self.0 {
            TCOperation::Create { uuid } => {
                format!("#<Taskchampion::Operation::Create uuid={}>", uuid)
            }
            TCOperation::Delete { uuid, .. } => {
                format!("#<Taskchampion::Operation::Delete uuid={}>", uuid)
            }
            TCOperation::Update { uuid, property, .. } => {
                format!("#<Taskchampion::Operation::Update uuid={} property={}>", uuid, property)
            }
            TCOperation::UndoPoint => {
                "#<Taskchampion::Operation::UndoPoint>".to_string()
            }
        }
    }
}

impl AsRef<TCOperation> for Operation {
    fn as_ref(&self) -> &TCOperation {
        &self.0
    }
}

impl From<TCOperation> for Operation {
    fn from(value: TCOperation) -> Self {
        Operation(value)
    }
}

impl From<Operation> for TCOperation {
    fn from(value: Operation) -> Self {
        value.0
    }
}

pub fn init(module: &RModule) -> Result<(), Error> {
    let class = module.define_class("Operation", class::object())?;
    
    // Class methods for creating operations
    class.define_singleton_method("create", function!(Operation::create, 1))?;
    class.define_singleton_method("delete", function!(Operation::delete, 2))?;
    class.define_singleton_method("update", function!(Operation::update, 5))?;
    class.define_singleton_method("undo_point", function!(Operation::undo_point, 0))?;
    
    // Type checking methods
    class.define_method("create?", method!(Operation::create_op, 0))?;
    class.define_method("delete?", method!(Operation::delete_op, 0))?;
    class.define_method("update?", method!(Operation::update_op, 0))?;
    class.define_method("undo_point?", method!(Operation::undo_point_op, 0))?;
    
    // Getter methods
    class.define_method("uuid", method!(Operation::uuid, 0))?;
    class.define_method("old_task", method!(Operation::old_task, 0))?;
    class.define_method("property", method!(Operation::property, 0))?;
    class.define_method("timestamp", method!(Operation::timestamp, 0))?;
    class.define_method("old_value", method!(Operation::old_value, 0))?;
    class.define_method("value", method!(Operation::value, 0))?;
    class.define_method("inspect", method!(Operation::inspect, 0))?;
    
    Ok(())
}