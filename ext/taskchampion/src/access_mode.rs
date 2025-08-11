use magnus::{class, function, method, prelude::*, Error, RModule, Symbol};
pub use taskchampion::storage::AccessMode as TCAccessMode;

#[magnus::wrap(class = "Taskchampion::AccessMode", free_immediately)]
#[derive(Clone, Copy, PartialEq)]
pub struct AccessMode(AccessModeKind);

#[derive(Clone, Copy, PartialEq, Hash)]
enum AccessModeKind {
    ReadOnly,
    ReadWrite,
}

impl AccessMode {
    // Constructor methods
    fn read_only() -> Self {
        AccessMode(AccessModeKind::ReadOnly)
    }

    fn read_write() -> Self {
        AccessMode(AccessModeKind::ReadWrite)
    }

    // Predicate methods
    fn is_read_only(&self) -> bool {
        matches!(self.0, AccessModeKind::ReadOnly)
    }

    fn is_read_write(&self) -> bool {
        matches!(self.0, AccessModeKind::ReadWrite)
    }

    // String representations
    fn to_s(&self) -> &'static str {
        match self.0 {
            AccessModeKind::ReadOnly => "read_only",
            AccessModeKind::ReadWrite => "read_write",
        }
    }

    fn inspect(&self) -> String {
        format!("#<Taskchampion::AccessMode:{}>", self.to_s())
    }

    // Equality
    fn eq(&self, other: &AccessMode) -> bool {
        self.0 == other.0
    }

    fn eql(&self, other: &AccessMode) -> bool {
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
        match sym.to_string().as_str() {
            "read_only" => Ok(AccessMode(AccessModeKind::ReadOnly)),
            "read_write" => Ok(AccessMode(AccessModeKind::ReadWrite)),
            _ => Err(Error::new(
                magnus::exception::arg_error(),
                "Invalid access mode, expected :read_only or :read_write",
            )),
        }
    }

    pub fn to_symbol(&self) -> Symbol {
        match self.0 {
            AccessModeKind::ReadOnly => Symbol::new("read_only"),
            AccessModeKind::ReadWrite => Symbol::new("read_write"),
        }
    }
}

impl From<TCAccessMode> for AccessMode {
    fn from(mode: TCAccessMode) -> Self {
        match mode {
            TCAccessMode::ReadOnly => AccessMode(AccessModeKind::ReadOnly),
            TCAccessMode::ReadWrite => AccessMode(AccessModeKind::ReadWrite),
        }
    }
}

impl From<AccessMode> for TCAccessMode {
    fn from(mode: AccessMode) -> Self {
        match mode.0 {
            AccessModeKind::ReadOnly => TCAccessMode::ReadOnly,
            AccessModeKind::ReadWrite => TCAccessMode::ReadWrite,
        }
    }
}

pub fn init(module: &RModule) -> Result<(), Error> {
    let class = module.define_class("AccessMode", class::object())?;

    // Constructor methods
    class.define_singleton_method("read_only", function!(AccessMode::read_only, 0))?;
    class.define_singleton_method("read_write", function!(AccessMode::read_write, 0))?;

    // Predicate methods
    class.define_method("read_only?", method!(AccessMode::is_read_only, 0))?;
    class.define_method("read_write?", method!(AccessMode::is_read_write, 0))?;

    // String representations
    class.define_method("to_s", method!(AccessMode::to_s, 0))?;
    class.define_method("inspect", method!(AccessMode::inspect, 0))?;

    // Equality
    class.define_method("==", method!(AccessMode::eq, 1))?;
    class.define_method("eql?", method!(AccessMode::eql, 1))?;
    class.define_method("hash", method!(AccessMode::hash, 0))?;

    // Keep the constants for backward compatibility
    module.const_set("READ_ONLY", Symbol::new("read_only"))?;
    module.const_set("READ_WRITE", Symbol::new("read_write"))?;

    Ok(())
}