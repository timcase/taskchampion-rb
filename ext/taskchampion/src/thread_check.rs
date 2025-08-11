use magnus::Error;
use std::thread::ThreadId;
use std::cell::RefCell;
use crate::error::thread_error;

pub struct ThreadBound<T> {
    inner: RefCell<T>,
    thread_id: ThreadId,
}

// SAFETY: ThreadBound ensures thread-local access only
// The RefCell prevents concurrent access from the same thread
// The thread_id check prevents access from different threads
unsafe impl<T> Send for ThreadBound<T> {}
unsafe impl<T> Sync for ThreadBound<T> {}

impl<T> ThreadBound<T> {
    pub fn new(inner: T) -> Self {
        Self {
            inner: RefCell::new(inner),
            thread_id: std::thread::current().id(),
        }
    }

    pub fn check_thread(&self) -> Result<(), Error> {
        if self.thread_id != std::thread::current().id() {
            return Err(Error::new(
                thread_error(),
                "Object cannot be accessed from a different thread",
            ));
        }
        Ok(())
    }

    pub fn get(&self) -> Result<std::cell::Ref<T>, Error> {
        self.check_thread()?;
        Ok(self.inner.borrow())
    }

    pub fn get_mut(&self) -> Result<std::cell::RefMut<T>, Error> {
        self.check_thread()?;
        Ok(self.inner.borrow_mut())
    }

    pub fn into_inner(self) -> Result<T, Error> {
        if self.thread_id != std::thread::current().id() {
            return Err(Error::new(
                thread_error(),
                "Object cannot be extracted from a different thread",
            ));
        }
        Ok(self.inner.into_inner())
    }
}

#[macro_export]
macro_rules! check_thread {
    ($self:expr) => {
        $self.0.check_thread()?;
    };
}