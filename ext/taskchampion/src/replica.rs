use magnus::{
    class, function, method, prelude::*, Error, IntoValue, RArray, RHash, RModule, Symbol, TryConvert, Value,
};
use taskchampion::{Replica as TCReplica, ServerConfig, StorageConfig};

use crate::access_mode::AccessMode;
use crate::operations::Operations;
use crate::task::Task;
use crate::working_set::WorkingSet;
use crate::dependency_map::DependencyMap;
use crate::thread_check::ThreadBound;
use crate::util::{into_error, option_to_ruby, uuid2tc, vec_to_ruby};

#[magnus::wrap(class = "Taskchampion::Replica", free_immediately)]
pub struct Replica(ThreadBound<TCReplica>);

impl Replica {
    fn new_on_disk(
        path: String,
        create_if_missing: bool,
        access_mode: Option<Symbol>,
    ) -> Result<Self, Error> {
        let access_mode = match access_mode {
            Some(sym) => AccessMode::from_symbol(sym)?,
            None => AccessMode::from_symbol(Symbol::new("read_write"))?,
        };

        let replica = TCReplica::new(
            StorageConfig::OnDisk {
                taskdb_dir: path.into(),
                create_if_missing,
                access_mode: access_mode.into(),
            }
            .into_storage()
            .map_err(into_error)?,
        );
        Ok(Replica(ThreadBound::new(replica)))
    }

    fn new_in_memory() -> Result<Self, Error> {
        let replica = TCReplica::new(
            StorageConfig::InMemory
                .into_storage()
                .map_err(into_error)?,
        );
        Ok(Replica(ThreadBound::new(replica)))
    }

    fn create_task(&self, uuid: String, operations: &Operations) -> Result<Value, Error> {
        let mut tc_replica = self.0.get_mut()?;
        let tc_uuid = uuid2tc(&uuid)?;
        
        // Create mutable operations vector for TaskChampion
        let mut tc_ops = vec![];
        
        // Create the task in TaskChampion
        let tc_task = tc_replica.create_task(tc_uuid, &mut tc_ops).map_err(into_error)?;
        
        // Add the resulting operations to the provided Operations object
        operations.extend_from_tc(tc_ops);
        
        // Convert to Ruby Task object
        let task = Task::from_tc_task(tc_task);
        
        Ok(task.into_value())
    }

    fn commit_operations(&self, operations: &Operations) -> Result<(), Error> {
        let mut tc_replica = self.0.get_mut()?;
        
        // Convert Operations to TaskChampion Operations
        let tc_operations = operations.clone_inner();
        
        // Commit the operations
        tc_replica.commit_operations(tc_operations).map_err(into_error)?;
        
        Ok(())
    }

    fn tasks(&self) -> Result<RHash, Error> {
        let mut tc_replica = self.0.get_mut()?;
        
        let tasks = tc_replica.all_tasks().map_err(into_error)?;
        let hash = RHash::new();
        
        for (uuid, task) in tasks {
            let ruby_task = Task::from_tc_task(task);
            // Magnus automatically wraps ruby_task as a Taskchampion::Task Ruby object
            hash.aset(uuid.to_string(), ruby_task)?;
        }
        
        Ok(hash)
    }

    fn task_data(&self, uuid: String) -> Result<Value, Error> {
        let mut tc_replica = self.0.get_mut()?;
        
        let task_data = tc_replica
            .get_task_data(uuid2tc(&uuid)?)
            .map_err(into_error)?;
        
        option_to_ruby(task_data, |_data| {
            // TODO: Convert task data to Ruby TaskData object
            Ok(().into_value()) // () converts to nil in Magnus
        })
    }

    fn task(&self, uuid: String) -> Result<Value, Error> {
        let mut tc_replica = self.0.get_mut()?;
        
        let task = tc_replica
            .get_task(uuid2tc(&uuid)?)
            .map_err(into_error)?;
        
        option_to_ruby(task, |task| {
            let ruby_task = Task::from_tc_task(task);
            Ok(ruby_task.into_value()) // Convert to Value
        })
    }

    fn task_uuids(&self) -> Result<RArray, Error> {
        let mut tc_replica = self.0.get_mut()?;
        
        let uuids = tc_replica.all_task_uuids().map_err(into_error)?;
        vec_to_ruby(uuids, |uuid| Ok(uuid.to_string().into_value()))
    }

    fn working_set(&self) -> Result<Value, Error> {
        let mut tc_replica = self.0.get_mut()?;
        
        let tc_working_set = tc_replica.working_set().map_err(into_error)?;
        let working_set = WorkingSet::from_tc_working_set(tc_working_set.into());
        
        Ok(working_set.into_value())
    }

    fn dependency_map(&self, force: Option<bool>) -> Result<Value, Error> {
        let mut tc_replica = self.0.get_mut()?;
        let force = force.unwrap_or(false);
        
        let tc_dm = tc_replica.dependency_map(force).map_err(into_error)?;
        let dependency_map = DependencyMap::from_tc_dependency_map(tc_dm);
        
        Ok(dependency_map.into_value())
    }

    fn sync_to_local(&self, server_dir: String, avoid_snapshots: Option<bool>) -> Result<(), Error> {
        let mut tc_replica = self.0.get_mut()?;
        let avoid_snapshots = avoid_snapshots.unwrap_or(false);
        
        let mut server = ServerConfig::Local {
            server_dir: server_dir.into(),
        }
        .into_server()
        .map_err(into_error)?;
        
        tc_replica
            .sync(&mut server, avoid_snapshots)
            .map_err(into_error)
    }

    fn sync_to_remote(
        &self,
        kwargs: RHash,
    ) -> Result<(), Error> {
        
        // Extract required keyword arguments with proper exception type
        let url: String = kwargs.fetch(Symbol::new("url")).map_err(|_| Error::new(
            magnus::exception::arg_error(),
            "Missing required parameter: url"
        ))?;
        let client_id: String = kwargs.fetch(Symbol::new("client_id")).map_err(|_| Error::new(
            magnus::exception::arg_error(),
            "Missing required parameter: client_id"
        ))?;
        let encryption_secret: String = kwargs.fetch(Symbol::new("encryption_secret")).map_err(|_| Error::new(
            magnus::exception::arg_error(),
            "Missing required parameter: encryption_secret"
        ))?;
        let avoid_snapshots: bool = kwargs
            .fetch::<_, Value>(Symbol::new("avoid_snapshots"))
            .ok()
            .and_then(|v| bool::try_convert(v).ok())
            .unwrap_or(false);
        
        let mut tc_replica = self.0.get_mut()?;
        
        let mut server = ServerConfig::Remote {
            url,
            client_id: uuid2tc(&client_id)?,
            encryption_secret: encryption_secret.into(),
        }
        .into_server()
        .map_err(into_error)?;
        
        tc_replica
            .sync(&mut server, avoid_snapshots)
            .map_err(into_error)
    }

    fn rebuild_working_set(&self, renumber: Option<bool>) -> Result<(), Error> {
        let mut tc_replica = self.0.get_mut()?;
        let renumber = renumber.unwrap_or(false);
        
        tc_replica
            .rebuild_working_set(renumber)
            .map_err(into_error)
    }

    fn expire_tasks(&self) -> Result<(), Error> {
        let mut tc_replica = self.0.get_mut()?;
        
        tc_replica.expire_tasks().map_err(into_error)
    }

    fn sync_to_gcp(&self, kwargs: RHash) -> Result<(), Error> {
        // Extract required keyword arguments with proper exception type
        let bucket: String = kwargs.fetch(Symbol::new("bucket")).map_err(|_| Error::new(
            magnus::exception::arg_error(),
            "Missing required parameter: bucket"
        ))?;
        let credential_path: String = kwargs.fetch(Symbol::new("credential_path")).map_err(|_| Error::new(
            magnus::exception::arg_error(),
            "Missing required parameter: credential_path"
        ))?;
        let encryption_secret: String = kwargs.fetch(Symbol::new("encryption_secret")).map_err(|_| Error::new(
            magnus::exception::arg_error(),
            "Missing required parameter: encryption_secret"
        ))?;
        let avoid_snapshots: bool = kwargs
            .fetch::<_, Value>(Symbol::new("avoid_snapshots"))
            .ok()
            .and_then(|v| bool::try_convert(v).ok())
            .unwrap_or(false);
        
        let mut tc_replica = self.0.get_mut()?;
        
        let mut server = ServerConfig::Gcp {
            bucket,
            credential_path: credential_path.into(),
            encryption_secret: encryption_secret.into(),
        }
        .into_server()
        .map_err(into_error)?;
        
        tc_replica
            .sync(&mut server, avoid_snapshots)
            .map_err(into_error)
    }

    fn num_local_operations(&self) -> Result<usize, Error> {
        let mut tc_replica = self.0.get_mut()?;
        
        Ok(tc_replica.num_local_operations().map_err(into_error)?)
    }

    fn num_undo_points(&self) -> Result<usize, Error> {
        let mut tc_replica = self.0.get_mut()?;
        
        Ok(tc_replica.num_undo_points().map_err(into_error)?)
    }
}

pub fn init(module: &RModule) -> Result<(), Error> {
    let class = module.define_class("Replica", class::object())?;
    
    // Class methods
    class.define_singleton_method("new_on_disk", function!(Replica::new_on_disk, 3))?;
    class.define_singleton_method("new_in_memory", function!(Replica::new_in_memory, 0))?;
    
    // Instance methods
    class.define_method("create_task", method!(Replica::create_task, 2))?;
    class.define_method("commit_operations", method!(Replica::commit_operations, 1))?;
    class.define_method("tasks", method!(Replica::tasks, 0))?;
    class.define_method("task", method!(Replica::task, 1))?;
    class.define_method("task_data", method!(Replica::task_data, 1))?;
    class.define_method("task_uuids", method!(Replica::task_uuids, 0))?;
    class.define_method("working_set", method!(Replica::working_set, 0))?;
    class.define_method("dependency_map", method!(Replica::dependency_map, 1))?;
    class.define_method("sync_to_local", method!(Replica::sync_to_local, 2))?;
    class.define_method("sync_to_remote", method!(Replica::sync_to_remote, 1))?;
    class.define_method("sync_to_gcp", method!(Replica::sync_to_gcp, 1))?;
    class.define_method("rebuild_working_set", method!(Replica::rebuild_working_set, 1))?;
    class.define_method("expire_tasks", method!(Replica::expire_tasks, 0))?;
    class.define_method("num_local_operations", method!(Replica::num_local_operations, 0))?;
    class.define_method("num_undo_points", method!(Replica::num_undo_points, 0))?;
    
    Ok(())
}