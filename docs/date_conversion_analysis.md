# Date Format Conversion in `task.set_due`

## Overview

When `task.set_due` is invoked in the TaskChampion Ruby gem, there **is** a format conversion from various Ruby date/time formats to a Unix timestamp for storage.

## Conversion Flow

The conversion follows this path: **Ruby date/time → UTC DateTime → Unix timestamp (stored as string)**

### 1. Ruby Input Processing
**Location**: `ext/taskchampion/src/task.rs:258-264`

The `set_due` method accepts a Ruby `Value` which can be:
- `nil` (to clear the due date)
- A Ruby `Time` object
- A Ruby `DateTime` object
- A String in ISO 8601 format (e.g., "2023-01-01T12:00:00Z")
- A String in the format "%Y-%m-%d %H:%M:%S %z"

```rust
fn set_due(&self, due: Value, operations: &crate::operations::Operations) -> Result<(), Error> {
    let mut task = self.0.get_mut()?;
    let due_datetime = ruby_to_option(due, ruby_to_datetime)?;
    operations.with_inner_mut(|ops| {
        task.set_due(due_datetime, ops)
    })?;
    Ok(())
}
```

### 2. Conversion to Rust DateTime
**Location**: `ext/taskchampion/src/util.rs:33-77`

The `ruby_to_datetime` function converts the Ruby value to a Rust `DateTime<Utc>`:

- **For `Time` objects**: Uses `strftime("%Y-%m-%dT%H:%M:%S%z")` to get ISO format, then parses it
- **For `DateTime` objects**: Calls the `iso8601()` method, then parses the result
- **For Strings**: Attempts to parse as RFC3339 first, then falls back to "%Y-%m-%d %H:%M:%S %z" format
- **All dates are converted to UTC timezone**

```rust
pub fn ruby_to_datetime(value: Value) -> Result<DateTime<Utc>, Error> {
    // String parsing
    if let Ok(s) = RString::try_convert(value) {
        let s = unsafe { s.as_str()? };
        DateTime::parse_from_rfc3339(s)
            .map(|dt| dt.with_timezone(&Utc))
            .or_else(|_| DateTime::parse_from_str(s, "%Y-%m-%d %H:%M:%S %z")
                .map(|dt| dt.with_timezone(&Utc)))
            // ... error handling
    } else {
        // Ruby Time/DateTime object handling
        let class_name = unsafe { value.class().name() };
        let iso_string = if class_name == "Time" {
            value.funcall::<_, (&str,), String>("strftime", ("%Y-%m-%dT%H:%M:%S%z",))?
        } else {
            value.funcall::<_, (), String>("iso8601", ())?
        };
        // Parse the ISO string...
    }
}
```

### 3. Storage as Unix Timestamp
**Location**: `/home/tcase/Sites/reference/taskchampion/src/task/task.rs`

The underlying TaskChampion library stores the date as a Unix timestamp:

```rust
pub fn set_due(&mut self, due: Option<Timestamp>, ops: &mut Operations) -> Result<()> {
    self.set_timestamp(Prop::Due.as_ref(), due, ops)
}

pub fn set_timestamp(
    &mut self,
    property: &str,
    value: Option<Timestamp>,
    ops: &mut Operations,
) -> Result<()> {
    self.set_value(property, value.map(|v| v.timestamp().to_string()), ops)
}
```

Where `Timestamp` is defined as:
```rust
pub(crate) type Timestamp = DateTime<Utc>;
```

The `.timestamp()` method converts the `DateTime<Utc>` to Unix timestamp (seconds since epoch), which is then converted to a string for storage (e.g., "1704067200").

### 4. Retrieval Process
**Location**: `ext/taskchampion/src/task.rs`

When retrieving the due date, it's converted back from Unix timestamp to a Ruby DateTime object:

```rust
fn due(&self) -> Result<Value, Error> {
    let task = self.0.get()?;
    option_to_ruby(task.get_due(), datetime_to_ruby)
}
```

## Summary

The `task.set_due` method performs comprehensive date format conversion:

1. **Input**: Accepts various Ruby date/time formats and strings
2. **Normalization**: Converts all inputs to UTC `DateTime<Utc>`
3. **Storage**: Stores as Unix timestamp string in the underlying TaskChampion database
4. **Retrieval**: Converts back to Ruby DateTime objects when accessed

This ensures consistent date handling across different input formats while maintaining precision and timezone normalization.