use magnus::{
    class, function, method, prelude::*, Error, RArray, RModule, Ruby, Value,
};
use std::cell::RefCell;
use taskchampion::Operations as TCOperations;

use crate::operation::Operation;

#[magnus::wrap(class = "Taskchampion::Operations", free_immediately)]
pub struct Operations(RefCell<TCOperations>);

impl Operations {
    fn new(_ruby: &Ruby) -> Self {
        Operations(RefCell::new(TCOperations::new()))
    }

    fn push(&self, operation: &Operation) -> Result<(), Error> {
        self.0.borrow_mut().push(operation.as_ref().clone());
        Ok(())
    }

    fn len(&self) -> usize {
        self.0.borrow().len()
    }

    fn empty(&self) -> bool {
        self.0.borrow().is_empty()
    }

    fn get(&self, index: usize) -> Result<Operation, Error> {
        let ops = self.0.borrow();
        if index >= ops.len() {
            return Err(Error::new(
                magnus::exception::index_error(),
                "Index out of bounds",
            ));
        }
        
        let operation = Operation::from(ops[index].clone());
        Ok(operation)
    }

    fn each(&self) -> Result<RArray, Error> {
        let array = RArray::new();
        let ops = self.0.borrow();
        
        for op in ops.iter() {
            let operation = Operation::from(op.clone());
            // Magnus handles wrapping automatically
            array.push(operation)?;
        }
        
        Ok(array)
    }

    fn inspect(&self) -> String {
        format!("#<Taskchampion::Operations: {} operations>", self.0.borrow().len())
    }

    fn clear(&self) {
        self.0.borrow_mut().clear();
    }

    // Internal method for accessing the operations
    pub(crate) fn clone_inner(&self) -> TCOperations {
        self.0.borrow().clone()
    }

    // Internal method for pushing operations from TaskChampion
    pub(crate) fn extend_from_tc(&self, tc_ops: Vec<taskchampion::Operation>) {
        let mut ops = self.0.borrow_mut();
        for op in tc_ops {
            ops.push(op);
        }
    }
}

// Note: AsRef and AsMut cannot be implemented with RefCell
// as they require returning references with the lifetime of self.
// Instead, we'll provide methods to work with the inner value.

impl From<TCOperations> for Operations {
    fn from(value: TCOperations) -> Self {
        Operations(RefCell::new(value))
    }
}

impl From<Operations> for TCOperations {
    fn from(value: Operations) -> Self {
        value.0.into_inner()
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
    class.define_method("to_a", method!(Operations::each, 0))?;
    class.define_method("inspect", method!(Operations::inspect, 0))?;
    class.define_method("clear", method!(Operations::clear, 0))?;
    
    Ok(())
}