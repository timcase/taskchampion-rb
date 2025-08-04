use magnus::{
    class, method, prelude::*, Error, IntoValue, RArray, RModule,
};
use std::sync::Arc;
use taskchampion::DependencyMap as TCDependencyMap;

use crate::thread_check::ThreadBound;
use crate::util::{uuid2tc, vec_to_ruby};

#[magnus::wrap(class = "Taskchampion::DependencyMap", free_immediately)]
pub struct DependencyMap(ThreadBound<Arc<TCDependencyMap>>);

impl DependencyMap {
    pub fn from_tc_dependency_map(tc_dependency_map: Arc<TCDependencyMap>) -> Self {
        DependencyMap(ThreadBound::new(tc_dependency_map))
    }

    fn dependencies(&self, uuid: String) -> Result<RArray, Error> {
        let dep_map = self.0.get()?;
        let tc_uuid = uuid2tc(&uuid)?;
        
        let deps: Vec<String> = dep_map
            .dependencies(tc_uuid)
            .map(|uuid| uuid.to_string())
            .collect();
        
        vec_to_ruby(deps, |s| Ok(s.into_value()))
    }

    fn dependents(&self, uuid: String) -> Result<RArray, Error> {
        let dep_map = self.0.get()?;
        let tc_uuid = uuid2tc(&uuid)?;
        
        let deps: Vec<String> = dep_map
            .dependents(tc_uuid)
            .map(|uuid| uuid.to_string())
            .collect();
        
        vec_to_ruby(deps, |s| Ok(s.into_value()))
    }

    fn has_dependency(&self, uuid: String) -> Result<bool, Error> {
        let dep_map = self.0.get()?;
        let tc_uuid = uuid2tc(&uuid)?;
        
        // Check if this UUID has any dependencies
        let result = dep_map.dependencies(tc_uuid).next().is_some();
        Ok(result)
    }

    fn inspect(&self) -> Result<String, Error> {
        Ok("#<Taskchampion::DependencyMap>".to_string())
    }
}

pub fn init(module: &RModule) -> Result<(), Error> {
    let class = module.define_class("DependencyMap", class::object())?;
    
    class.define_method("dependencies", method!(DependencyMap::dependencies, 1))?;
    class.define_method("dependents", method!(DependencyMap::dependents, 1))?;
    class.define_method("has_dependency?", method!(DependencyMap::has_dependency, 1))?;
    class.define_method("inspect", method!(DependencyMap::inspect, 0))?;
    
    Ok(())
}