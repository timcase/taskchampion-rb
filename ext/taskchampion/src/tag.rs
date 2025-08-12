use magnus::{class, function, method, prelude::*, Error, RModule, Ruby};
use taskchampion::Tag as TCTag;
use crate::error::validation_error;

#[magnus::wrap(class = "Taskchampion::Tag", free_immediately)]
pub struct Tag(TCTag);

impl Tag {
    fn new(_ruby: &Ruby, tag: String) -> Result<Self, Error> {
        let tc_tag = tag.parse()
            .map_err(|_| Error::new(validation_error(), "Invalid tag"))?;
        Ok(Tag(tc_tag))
    }

    fn to_s(&self) -> String {
        self.0.to_string()
    }

    fn inspect(&self) -> String {
        format!("#<Taskchampion::Tag:{:?}>", self.0)
    }

    fn synthetic(&self) -> bool {
        self.0.is_synthetic()
    }

    fn user(&self) -> bool {
        self.0.is_user()
    }

    fn hash(&self) -> i64 {
        use std::collections::hash_map::DefaultHasher;
        use std::hash::{Hash, Hasher};

        let mut hasher = DefaultHasher::new();
        self.0.hash(&mut hasher);
        hasher.finish() as i64
    }

    fn eql(&self, other: &Tag) -> bool {
        self.0 == other.0
    }
}

impl AsRef<TCTag> for Tag {
    fn as_ref(&self) -> &TCTag {
        &self.0
    }
}

impl From<TCTag> for Tag {
    fn from(value: TCTag) -> Self {
        Tag(value)
    }
}

impl From<Tag> for TCTag {
    fn from(value: Tag) -> Self {
        value.0
    }
}

pub fn init(module: &RModule) -> Result<(), Error> {
    let class = module.define_class("Tag", class::object())?;

    class.define_singleton_method("new", function!(Tag::new, 1))?;
    class.define_method("to_s", method!(Tag::to_s, 0))?;
    class.define_method("to_str", method!(Tag::to_s, 0))?;
    class.define_method("inspect", method!(Tag::inspect, 0))?;
    class.define_method("synthetic?", method!(Tag::synthetic, 0))?;
    class.define_method("user?", method!(Tag::user, 0))?;
    class.define_method("hash", method!(Tag::hash, 0))?;
    class.define_method("eql?", method!(Tag::eql, 1))?;
    class.define_method("==", method!(Tag::eql, 1))?;

    Ok(())
}
