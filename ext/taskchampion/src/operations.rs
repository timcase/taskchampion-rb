use magnus::{
    class, function, method, prelude::*, Error, IntoValue, RArray, RModule, Ruby, Value,
};
use std::cell::RefCell;
use taskchampion::Operations as TCOperations;

use crate::operation::Operation;
use crate::thread_check::ThreadBound;

#[magnus::wrap(class = "Taskchampion::Operations", free_immediately)]
pub struct Operations(ThreadBound<RefCell<TCOperations>>);

impl Operations {
    fn new(_ruby: &Ruby) -> Self {
        Operations(ThreadBound::new(RefCell::new(TCOperations::new())))
    }

    fn push(&self, operation: &Operation) -> Result<(), Error> {
        let ops = self.0.get()?;
        ops.borrow_mut().push(operation.as_ref().clone());
        Ok(())
    }

    fn len(&self) -> Result<usize, Error> {
        let ops = self.0.get()?;
        let borrowed = ops.borrow();
        Ok(borrowed.len())
    }

    fn empty(&self) -> Result<bool, Error> {
        let ops = self.0.get()?;
        let borrowed = ops.borrow();
        Ok(borrowed.is_empty())
    }

    fn get(&self, index: isize) -> Result<Value, Error> {
        let ops = self.0.get()?;
        let ops = ops.borrow();
        let len = ops.len() as isize;

        // Handle negative indices (Ruby-style)
        let actual_index = if index < 0 {
            len + index
        } else {
            index
        };

        // Check bounds - return nil instead of raising for Ruby compatibility
        if actual_index < 0 || actual_index >= len {
            let ruby = magnus::Ruby::get().map_err(|e| Error::new(
                magnus::exception::runtime_error(),
                e.to_string(),
            ))?;
            return Ok(ruby.qnil().into_value());  // Return nil
        }

        let operation = Operation::from(ops[actual_index as usize].clone());
        Ok(operation.into_value())
    }

    fn each(&self) -> Result<Value, Error> {
        let ruby = magnus::Ruby::get().map_err(|e| Error::new(
            magnus::exception::runtime_error(),
            format!("Failed to get Ruby context: {}", e),
        ))?;

        // Check if a block was given
        if ruby.block_given() {
            let ops = self.0.get()?;
            let ops = ops.borrow();
            let block = ruby.block_proc()?;

            for op in ops.iter() {
                let operation = Operation::from(op.clone());
                block.call::<_, Value>((operation,))?;
            }

            // Ruby's each method returns self when called with a block
            let ruby = magnus::Ruby::get().unwrap();
            Ok(ruby.qnil().into_value())
        } else {
            // No block given, return an enumerator (or array for simplicity)
            self.to_array()
        }
    }

    fn to_array(&self) -> Result<Value, Error> {
        let array = RArray::new();
        let ops = self.0.get()?;
        let ops = ops.borrow();

        for op in ops.iter() {
            let operation = Operation::from(op.clone());
            // Magnus handles wrapping automatically
            array.push(operation)?;
        }

        Ok(array.into_value())
    }

    fn inspect(&self) -> Result<String, Error> {
        let ops = self.0.get()?;
        Ok(format!("#<Taskchampion::Operations: {} operations>", ops.borrow().len()))
    }

    fn clear(&self) -> Result<(), Error> {
        let ops = self.0.get()?;
        ops.borrow_mut().clear();
        Ok(())
    }

    // Internal method for accessing the operations
    pub(crate) fn clone_inner(&self) -> Result<TCOperations, Error> {
        let ops = self.0.get()?;
        let borrowed = ops.borrow();
        Ok(borrowed.clone())
    }

    pub(crate) fn with_inner_mut<T, F>(&self, f: F) -> Result<T, Error>
    where
        F: FnOnce(&mut TCOperations) -> Result<T, taskchampion::Error>,
    {
        let ops = self.0.get()?;
        let mut ops = ops.borrow_mut();
        f(&mut *ops).map_err(|e| Error::new(
            magnus::exception::runtime_error(),
            e.to_string(),
        ))
    }

    // Internal method for pushing operations from TaskChampion
    pub(crate) fn extend_from_tc(&self, tc_ops: Vec<taskchampion::Operation>) -> Result<(), Error> {
        let ops = self.0.get()?;
        let mut ops = ops.borrow_mut();
        for op in tc_ops {
            ops.push(op);
        }
        Ok(())
    }

    // Internal method for creating Operations from TaskChampion operations
    pub(crate) fn from_tc_operations(tc_ops: Vec<taskchampion::Operation>) -> Self {
        let mut operations = TCOperations::new();
        for op in tc_ops {
            operations.push(op);
        }
        Operations(ThreadBound::new(RefCell::new(operations)))
    }
}

// Note: AsRef and AsMut cannot be implemented with RefCell
// as they require returning references with the lifetime of self.
// Instead, we'll provide methods to work with the inner value.

impl From<TCOperations> for Operations {
    fn from(value: TCOperations) -> Self {
        Operations(ThreadBound::new(RefCell::new(value)))
    }
}

impl From<Operations> for TCOperations {
    fn from(value: Operations) -> Self {
        // This implementation will panic if called from wrong thread
        // but that's appropriate for ThreadBound behavior
        let cell = match value.0.into_inner() {
            Ok(cell) => cell,
            Err(_) => panic!("Attempted to extract Operations from wrong thread"),
        };
        cell.into_inner()
    }
}

pub fn init(module: &RModule) -> Result<(), Error> {
    let class = module.define_class("Operations", class::object())?;

    class.define_singleton_method("new", function!(Operations::new, 0))?;
    class.define_method("push", method!(Operations::push, 1))?;
    class.define_method("<<", method!(Operations::push, 1))?;
    class.define_method("length", method!(Operations::len, 0))?;
    class.define_method("size", method!(Operations::len, 0))?;
    class.define_method("empty?", method!(Operations::empty, 0))?;
    class.define_method("[]", method!(Operations::get, 1))?;
    class.define_method("each", method!(Operations::each, 0))?;
    class.define_method("to_a", method!(Operations::to_array, 0))?;
    class.define_method("inspect", method!(Operations::inspect, 0))?;
    class.define_method("clear", method!(Operations::clear, 0))?;

    Ok(())
}
