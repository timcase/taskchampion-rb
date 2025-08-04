use magnus::{class, function, method, prelude::*, Error, RModule, Ruby, Value};
use chrono::{DateTime, Utc};
use taskchampion::Annotation as TCAnnotation;
use crate::util::{datetime_to_ruby, ruby_to_datetime};

#[magnus::wrap(class = "Taskchampion::Annotation", free_immediately)]
pub struct Annotation(TCAnnotation);

impl Annotation {
    fn new(_ruby: &Ruby, entry: Value, description: String) -> Result<Self, Error> {
        let entry = ruby_to_datetime(entry)?;
        Ok(Annotation(TCAnnotation { entry, description }))
    }

    fn entry(&self) -> Result<Value, Error> {
        datetime_to_ruby(self.0.entry)
    }

    fn description(&self) -> String {
        self.0.description.clone()
    }

    fn inspect(&self) -> Result<String, Error> {
        let entry_str = self.0.entry.to_rfc3339();
        Ok(format!("#<Taskchampion::Annotation: {} \"{}\">", entry_str, self.0.description))
    }

    fn to_s(&self) -> String {
        self.0.description.clone()
    }

    fn eql(&self, other: &Annotation) -> bool {
        self.0 == other.0
    }

    fn hash(&self) -> i64 {
        use std::collections::hash_map::DefaultHasher;
        use std::hash::{Hash, Hasher};
        
        let mut hasher = DefaultHasher::new();
        self.0.entry.hash(&mut hasher);
        self.0.description.hash(&mut hasher);
        hasher.finish() as i64
    }
}

impl AsRef<TCAnnotation> for Annotation {
    fn as_ref(&self) -> &TCAnnotation {
        &self.0
    }
}

impl From<TCAnnotation> for Annotation {
    fn from(value: TCAnnotation) -> Self {
        Annotation(value)
    }
}

impl From<Annotation> for TCAnnotation {
    fn from(value: Annotation) -> Self {
        value.0
    }
}

pub fn init(module: &RModule) -> Result<(), Error> {
    let class = module.define_class("Annotation", class::object())?;
    
    class.define_singleton_method("new", function!(Annotation::new, 2))?;
    class.define_method("entry", method!(Annotation::entry, 0))?;
    class.define_method("description", method!(Annotation::description, 0))?;
    class.define_method("inspect", method!(Annotation::inspect, 0))?;
    class.define_method("to_s", method!(Annotation::to_s, 0))?;
    class.define_method("eql?", method!(Annotation::eql, 1))?;
    class.define_method("==", method!(Annotation::eql, 1))?;
    class.define_method("hash", method!(Annotation::hash, 0))?;
    
    Ok(())
}