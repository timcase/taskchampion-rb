use magnus::{Error, Value, RString, RHash, RArray, Ruby, IntoValue, prelude::*};
use taskchampion::Uuid;
use chrono::{DateTime, Utc};
use std::collections::HashMap;
use crate::error::{validation_error, storage_error};

/// Convert a string from Ruby into a Rust Uuid
pub fn uuid2tc(s: impl AsRef<str>) -> Result<Uuid, Error> {
    Uuid::parse_str(s.as_ref())
        .map_err(|_| Error::new(validation_error(), "Invalid UUID"))
}

/// Convert a taskchampion::Error into a Ruby error
pub fn into_error(err: taskchampion::Error) -> Error {
    Error::new(storage_error(), err.to_string())
}

/// Convert Rust DateTime<Utc> to Ruby DateTime
pub fn datetime_to_ruby(dt: DateTime<Utc>) -> Result<Value, Error> {
    let ruby = magnus::Ruby::get().map_err(|e| Error::new(magnus::exception::runtime_error(), e.to_string()))?;
    let datetime_class: Value = ruby.eval("require 'date'; DateTime")?;
    
    // Convert to string and parse in Ruby (simplest approach)
    let iso_string = dt.to_rfc3339();
    datetime_class.funcall("parse", (iso_string,))
}

/// Convert Ruby DateTime/Time/String to Rust DateTime<Utc>
pub fn ruby_to_datetime(value: Value) -> Result<DateTime<Utc>, Error> {
    let ruby = magnus::Ruby::get().map_err(|e| Error::new(magnus::exception::runtime_error(), e.to_string()))?;
    
    // If it's a string, parse it
    if let Ok(s) = RString::try_convert(value) {
        let s = unsafe { s.as_str()? };
        DateTime::parse_from_rfc3339(s)
            .map(|dt| dt.with_timezone(&Utc))
            .or_else(|_| DateTime::parse_from_str(s, "%Y-%m-%d %H:%M:%S %z")
                .map(|dt| dt.with_timezone(&Utc)))
            .map_err(|e| Error::new(validation_error(), format!("Invalid datetime: {}", e)))
    } else {
        // Convert Ruby DateTime/Time to ISO string then parse
        let iso_string: String = value.funcall("iso8601", ())?;
        DateTime::parse_from_rfc3339(&iso_string)
            .map(|dt| dt.with_timezone(&Utc))
            .map_err(|e| Error::new(validation_error(), format!("Invalid datetime: {}", e)))
    }
}

/// Convert Option<T> to Ruby value (nil for None)
pub fn option_to_ruby<T, F>(opt: Option<T>, converter: F) -> Result<Value, Error>
where
    F: FnOnce(T) -> Result<Value, Error>,
{
    match opt {
        Some(val) => converter(val),
        None => Ok(().into_value()), // () converts to nil in Magnus
    }
}

/// Convert Ruby value to Option<T> (nil becomes None)
pub fn ruby_to_option<T, F>(value: Value, converter: F) -> Result<Option<T>, Error>
where
    F: FnOnce(Value) -> Result<T, Error>,
{
    if value.is_nil() {
        Ok(None)
    } else {
        converter(value).map(Some)
    }
}

/// Convert HashMap to Ruby Hash
pub fn hashmap_to_ruby(map: HashMap<String, String>) -> Result<RHash, Error> {
    let hash = RHash::new();
    for (k, v) in map {
        hash.aset(k, v)?;
    }
    Ok(hash)
}

/// Convert Ruby Hash to HashMap
pub fn ruby_to_hashmap(hash: RHash) -> Result<HashMap<String, String>, Error> {
    let mut map = HashMap::new();
    hash.foreach(|key: String, value: String| {
        map.insert(key, value);
        Ok(magnus::r_hash::ForEach::Continue)
    })?;
    Ok(map)
}

/// Convert Vec to Ruby Array
pub fn vec_to_ruby<T, F>(vec: Vec<T>, converter: F) -> Result<RArray, Error>
where
    F: Fn(T) -> Result<Value, Error>,
{
    let array = RArray::with_capacity(vec.len());
    for item in vec {
        array.push(converter(item)?)?;
    }
    Ok(array)
}

/// Convert Ruby Array to Vec
pub fn ruby_to_vec<T, F>(array: RArray, converter: F) -> Result<Vec<T>, Error>
where
    F: Fn(Value) -> Result<T, Error>,
{
    let mut vec = Vec::with_capacity(array.len());
    for i in 0..array.len() {
        let value: Value = array.entry(i as isize)?;
        vec.push(converter(value)?);
    }
    Ok(vec)
}