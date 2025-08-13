use magnus::{Error, Value, RString, RHash, RArray, IntoValue, prelude::*};
use taskchampion::Uuid;
use chrono::{DateTime, Utc};
use std::collections::HashMap;
use crate::error::validation_error;

/// Convert a string from Ruby into a Rust Uuid with enhanced validation
pub fn uuid2tc(s: impl AsRef<str>) -> Result<Uuid, Error> {
    let uuid_str = s.as_ref();
    Uuid::parse_str(uuid_str)
        .map_err(|_| Error::new(
            validation_error(),
            format!("Invalid UUID format: '{}'. Expected format: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx", uuid_str)
        ))
}

/// Convert a taskchampion::Error into a Ruby error with enhanced mapping
pub fn into_error(err: taskchampion::Error) -> Error {
    crate::error::map_taskchampion_error(err)
}

/// Convert Rust DateTime<Utc> to Ruby DateTime
pub fn datetime_to_ruby(dt: DateTime<Utc>) -> Result<Value, Error> {
    let ruby = magnus::Ruby::get().map_err(|e| Error::new(magnus::exception::runtime_error(), e.to_string()))?;
    let datetime_class: Value = ruby.eval("require 'date'; DateTime")?;

    // Convert to string and parse in Ruby (simplest approach)
    let iso_string = dt.to_rfc3339();
    datetime_class.funcall("parse", (iso_string,))
}

/// Convert Ruby DateTime/Time/String to Rust DateTime<Utc> with enhanced validation
pub fn ruby_to_datetime(value: Value) -> Result<DateTime<Utc>, Error> {
    let ruby = magnus::Ruby::get().map_err(|e| Error::new(magnus::exception::runtime_error(), e.to_string()))?;

    // If it's a string, parse it
    if let Ok(s) = RString::try_convert(value) {
        let s = unsafe { s.as_str()? };
        DateTime::parse_from_rfc3339(s)
            .map(|dt| dt.with_timezone(&Utc))
            .or_else(|_| DateTime::parse_from_str(s, "%Y-%m-%d %H:%M:%S %z")
                .map(|dt| dt.with_timezone(&Utc)))
            .map_err(|_| Error::new(
                validation_error(),
                format!("Invalid datetime format: '{}'. Expected ISO 8601 format (e.g., '2023-01-01T12:00:00Z') or '%Y-%m-%d %H:%M:%S %z'", s)
            ))
    } else {
        // Check if it's a Time object first (Time doesn't have iso8601 method)
        let class = value.class();
        let class_name = unsafe { class.name() };
        let iso_string = if class_name == "Time" {
            // For Time objects, use strftime to get ISO 8601-like format
            value.funcall::<_, (&str,), String>("strftime", ("%Y-%m-%dT%H:%M:%S%z",))?
        } else {
            // For DateTime objects, use iso8601 method
            match value.funcall::<_, (), String>("iso8601", ()) {
                Ok(s) => s,
                Err(_) => return Err(Error::new(
                    validation_error(),
                    format!("Cannot convert value to datetime. Expected Time, DateTime, or String, got: {}", class_name)
                ))
            }
        };
        
        DateTime::parse_from_rfc3339(&iso_string)
            .map(|dt| dt.with_timezone(&Utc))
            .or_else(|_| {
                // Try parsing the Time strftime format (%z gives +HHMM instead of +HH:MM)
                DateTime::parse_from_str(&iso_string, "%Y-%m-%dT%H:%M:%S%z")
                    .map(|dt| dt.with_timezone(&Utc))
            })
            .map_err(|_| Error::new(
                validation_error(),
                format!("Invalid datetime from Ruby object: '{}'. Unable to parse as ISO 8601", iso_string)
            ))
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
