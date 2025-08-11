use magnus::{class, function, method, prelude::*, Error, RModule, Symbol};
pub use taskchampion::Status as TCStatus;
use crate::error::validation_error;

#[magnus::wrap(class = "Taskchampion::Status", free_immediately)]
#[derive(Clone, Copy, PartialEq)]
pub struct Status(StatusKind);

#[derive(Clone, Copy, PartialEq, Hash)]
enum StatusKind {
    Pending,
    Completed,
    Deleted,
    Recurring,
    Unknown,
}

impl Status {
    // Constructor methods
    fn pending() -> Self {
        Status(StatusKind::Pending)
    }

    fn completed() -> Self {
        Status(StatusKind::Completed)
    }

    fn deleted() -> Self {
        Status(StatusKind::Deleted)
    }

    fn recurring() -> Self {
        Status(StatusKind::Recurring)
    }

    fn unknown() -> Self {
        Status(StatusKind::Unknown)
    }

    // Predicate methods
    fn is_pending(&self) -> bool {
        matches!(self.0, StatusKind::Pending)
    }

    fn is_completed(&self) -> bool {
        matches!(self.0, StatusKind::Completed)
    }

    fn is_deleted(&self) -> bool {
        matches!(self.0, StatusKind::Deleted)
    }

    fn is_recurring(&self) -> bool {
        matches!(self.0, StatusKind::Recurring)
    }

    fn is_unknown(&self) -> bool {
        matches!(self.0, StatusKind::Unknown)
    }

    // String representations
    fn to_s(&self) -> &'static str {
        match self.0 {
            StatusKind::Pending => "pending",
            StatusKind::Completed => "completed",
            StatusKind::Deleted => "deleted",
            StatusKind::Recurring => "recurring",
            StatusKind::Unknown => "unknown",
        }
    }

    fn inspect(&self) -> String {
        format!("#<Taskchampion::Status:{}>", self.to_s())
    }

    // Equality
    fn eq(&self, other: &Status) -> bool {
        self.0 == other.0
    }

    fn eql(&self, other: &Status) -> bool {
        self.0 == other.0
    }

    fn hash(&self) -> u64 {
        use std::collections::hash_map::DefaultHasher;
        use std::hash::{Hash, Hasher};
        
        let mut hasher = DefaultHasher::new();
        std::mem::discriminant(&self.0).hash(&mut hasher);
        hasher.finish()
    }

    // For internal use
    pub fn from_symbol(sym: Symbol) -> Result<Self, Error> {
        let sym_str = sym.to_string();
        match sym_str.as_str() {
            "pending" => Ok(Status(StatusKind::Pending)),
            "completed" => Ok(Status(StatusKind::Completed)),
            "deleted" => Ok(Status(StatusKind::Deleted)),
            "recurring" => Ok(Status(StatusKind::Recurring)),
            "unknown" => Ok(Status(StatusKind::Unknown)),
            _ => Err(Error::new(
                validation_error(),
                format!("Invalid status: :{} - Expected one of: :pending, :completed, :deleted, :recurring, :unknown", sym_str),
            )),
        }
    }

    pub fn to_symbol(&self) -> Symbol {
        match self.0 {
            StatusKind::Pending => Symbol::new("pending"),
            StatusKind::Completed => Symbol::new("completed"),
            StatusKind::Deleted => Symbol::new("deleted"),
            StatusKind::Recurring => Symbol::new("recurring"),
            StatusKind::Unknown => Symbol::new("unknown"),
        }
    }
}

impl From<TCStatus> for Status {
    fn from(status: TCStatus) -> Self {
        match status {
            TCStatus::Pending => Status(StatusKind::Pending),
            TCStatus::Completed => Status(StatusKind::Completed),
            TCStatus::Deleted => Status(StatusKind::Deleted),
            TCStatus::Recurring => Status(StatusKind::Recurring),
            _ => Status(StatusKind::Unknown),
        }
    }
}

impl From<Status> for TCStatus {
    fn from(status: Status) -> Self {
        match status.0 {
            StatusKind::Pending => TCStatus::Pending,
            StatusKind::Completed => TCStatus::Completed,
            StatusKind::Deleted => TCStatus::Deleted,
            StatusKind::Recurring => TCStatus::Recurring,
            StatusKind::Unknown => TCStatus::Unknown("unknown status".to_string()),
        }
    }
}

pub fn init(module: &RModule) -> Result<(), Error> {
    let class = module.define_class("Status", class::object())?;
    
    // Constructor methods
    class.define_singleton_method("pending", function!(Status::pending, 0))?;
    class.define_singleton_method("completed", function!(Status::completed, 0))?;
    class.define_singleton_method("deleted", function!(Status::deleted, 0))?;
    class.define_singleton_method("recurring", function!(Status::recurring, 0))?;
    class.define_singleton_method("unknown", function!(Status::unknown, 0))?;
    class.define_singleton_method("from_symbol", function!(Status::from_symbol, 1))?;
    
    // Predicate methods
    class.define_method("pending?", method!(Status::is_pending, 0))?;
    class.define_method("completed?", method!(Status::is_completed, 0))?;
    class.define_method("deleted?", method!(Status::is_deleted, 0))?;
    class.define_method("recurring?", method!(Status::is_recurring, 0))?;
    class.define_method("unknown?", method!(Status::is_unknown, 0))?;
    
    // String representations
    class.define_method("to_s", method!(Status::to_s, 0))?;
    class.define_method("inspect", method!(Status::inspect, 0))?;
    
    // Equality
    class.define_method("==", method!(Status::eq, 1))?;
    class.define_method("eql?", method!(Status::eql, 1))?;
    class.define_method("hash", method!(Status::hash, 0))?;
    
    // Keep the constants for backward compatibility
    module.const_set("PENDING", Symbol::new("pending"))?;
    module.const_set("COMPLETED", Symbol::new("completed"))?;
    module.const_set("DELETED", Symbol::new("deleted"))?;
    module.const_set("RECURRING", Symbol::new("recurring"))?;
    module.const_set("UNKNOWN", Symbol::new("unknown"))?;
    
    Ok(())
}