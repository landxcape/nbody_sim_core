use std::collections::HashMap;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::sync::Mutex;
use std::sync::atomic::{AtomicU64, Ordering};

use once_cell::sync::Lazy;
use serde::de::DeserializeOwned;
use serde_json::{Value, json};

use crate::config::EngineConfig;
use crate::engine::SimulationEngine;
use crate::types::{Body, BodyEdit, Scenario, Snapshot};

static ENGINES: Lazy<Mutex<HashMap<u64, SimulationEngine>>> =
    Lazy::new(|| Mutex::new(HashMap::new()));
static NEXT_HANDLE: AtomicU64 = AtomicU64::new(1);

#[unsafe(no_mangle)]
pub extern "C" fn gs_initialize(
    config_json: *const c_char,
    bodies_json: *const c_char,
) -> *mut c_char {
    let result = (|| {
        let config: EngineConfig = parse_json_arg(config_json, "config")?;
        let bodies: Vec<Body> = parse_json_arg(bodies_json, "bodies")?;

        let engine =
            SimulationEngine::with_bodies(config, bodies).map_err(|error| error.to_string())?;

        let handle = NEXT_HANDLE.fetch_add(1, Ordering::Relaxed);
        let state = engine.get_state();

        let mut engines = ENGINES
            .lock()
            .map_err(|_| "engine registry lock poisoned".to_string())?;
        engines.insert(handle, engine);

        Ok(json!({
            "handle": handle,
            "state": state,
        }))
    })();

    response_to_ptr(result)
}

#[unsafe(no_mangle)]
pub extern "C" fn gs_dispose(handle: u64) -> *mut c_char {
    let result = (|| {
        let mut engines = ENGINES
            .lock()
            .map_err(|_| "engine registry lock poisoned".to_string())?;
        let removed = engines.remove(&handle).is_some();
        Ok(json!({ "removed": removed }))
    })();

    response_to_ptr(result)
}

#[unsafe(no_mangle)]
pub extern "C" fn gs_set_config(handle: u64, config_json: *const c_char) -> *mut c_char {
    let result = with_engine_mut(handle, |engine| {
        let config: EngineConfig = parse_json_arg(config_json, "config")?;
        engine
            .set_config(config)
            .map_err(|error| error.to_string())?;
        Ok(json!({ "state": engine.get_state() }))
    });

    response_to_ptr(result)
}

#[unsafe(no_mangle)]
pub extern "C" fn gs_apply_edit(handle: u64, edit_json: *const c_char) -> *mut c_char {
    let result = with_engine_mut(handle, |engine| {
        let edit: BodyEdit = parse_json_arg(edit_json, "edit")?;
        engine.apply_edit(edit).map_err(|error| error.to_string())?;
        Ok(json!({ "state": engine.get_state() }))
    });

    response_to_ptr(result)
}

#[unsafe(no_mangle)]
pub extern "C" fn gs_step(handle: u64, ticks: u32) -> *mut c_char {
    let result = with_engine_mut(handle, |engine| {
        let summary = engine.step(ticks).map_err(|error| error.to_string())?;
        Ok(json!({
            "summary": summary,
            "state": engine.get_state(),
        }))
    });

    response_to_ptr(result)
}

#[unsafe(no_mangle)]
pub extern "C" fn gs_get_state(handle: u64) -> *mut c_char {
    let result = with_engine(handle, |engine| Ok(json!({ "state": engine.get_state() })));
    response_to_ptr(result)
}

#[unsafe(no_mangle)]
pub extern "C" fn gs_load_scenario(handle: u64, scenario_json: *const c_char) -> *mut c_char {
    let result = with_engine_mut(handle, |engine| {
        let scenario: Scenario = parse_json_arg(scenario_json, "scenario")?;
        engine
            .load_scenario(scenario)
            .map_err(|error| error.to_string())?;
        Ok(json!({ "state": engine.get_state() }))
    });

    response_to_ptr(result)
}

#[unsafe(no_mangle)]
pub extern "C" fn gs_save_scenario(handle: u64) -> *mut c_char {
    let result = with_engine(handle, |engine| {
        Ok(json!({ "scenario": engine.save_scenario() }))
    });
    response_to_ptr(result)
}

#[unsafe(no_mangle)]
pub extern "C" fn gs_snapshot(handle: u64) -> *mut c_char {
    let result = with_engine(handle, |engine| {
        Ok(json!({ "snapshot": engine.snapshot() }))
    });
    response_to_ptr(result)
}

#[unsafe(no_mangle)]
pub extern "C" fn gs_restore_snapshot(handle: u64, snapshot_json: *const c_char) -> *mut c_char {
    let result = with_engine_mut(handle, |engine| {
        let snapshot: Snapshot = parse_json_arg(snapshot_json, "snapshot")?;
        engine
            .restore_snapshot(snapshot)
            .map_err(|error| error.to_string())?;
        Ok(json!({ "state": engine.get_state() }))
    });

    response_to_ptr(result)
}

#[unsafe(no_mangle)]
pub extern "C" fn gs_string_free(ptr: *mut c_char) {
    if ptr.is_null() {
        return;
    }

    // SAFETY: `ptr` was allocated by `CString::into_raw` in this module.
    unsafe {
        let _ = CString::from_raw(ptr);
    }
}

fn with_engine<F>(handle: u64, action: F) -> std::result::Result<Value, String>
where
    F: FnOnce(&SimulationEngine) -> std::result::Result<Value, String>,
{
    let engines = ENGINES
        .lock()
        .map_err(|_| "engine registry lock poisoned".to_string())?;
    let engine = engines
        .get(&handle)
        .ok_or_else(|| format!("engine handle not found: {handle}"))?;
    action(engine)
}

fn with_engine_mut<F>(handle: u64, action: F) -> std::result::Result<Value, String>
where
    F: FnOnce(&mut SimulationEngine) -> std::result::Result<Value, String>,
{
    let mut engines = ENGINES
        .lock()
        .map_err(|_| "engine registry lock poisoned".to_string())?;
    let engine = engines
        .get_mut(&handle)
        .ok_or_else(|| format!("engine handle not found: {handle}"))?;
    action(engine)
}

fn parse_json_arg<T>(arg_ptr: *const c_char, name: &str) -> std::result::Result<T, String>
where
    T: DeserializeOwned,
{
    let json_str = c_char_to_string(arg_ptr)?;
    serde_json::from_str::<T>(&json_str)
        .map_err(|error| format!("failed to parse {name} json: {error}"))
}

fn c_char_to_string(ptr: *const c_char) -> std::result::Result<String, String> {
    if ptr.is_null() {
        return Err("received null c-string pointer".to_string());
    }

    // SAFETY: caller guarantees the pointer is valid and NUL-terminated.
    let c_str = unsafe { CStr::from_ptr(ptr) };
    c_str
        .to_str()
        .map(|value| value.to_string())
        .map_err(|error| format!("invalid utf-8 in c-string: {error}"))
}

fn response_to_ptr(result: std::result::Result<Value, String>) -> *mut c_char {
    let payload = match result {
        Ok(data) => json!({ "ok": true, "data": data }),
        Err(error) => json!({ "ok": false, "error": error }),
    };

    let json_string = payload.to_string();
    match CString::new(json_string) {
        Ok(c_string) => c_string.into_raw(),
        Err(_) => CString::new("{\"ok\":false,\"error\":\"response contains interior null\"}")
            .expect("static fallback response must be valid")
            .into_raw(),
    }
}
