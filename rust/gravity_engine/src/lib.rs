pub mod collision;
pub mod config;
pub mod engine;
pub mod errors;
pub mod ffi;
pub mod integrator;
pub mod math;
pub mod solver;
pub mod types;

pub use config::{CollisionMode, DtPolicy, EngineConfig, GravitySolver, IntegratorKind};
pub use engine::SimulationEngine;
pub use errors::{EngineError, Result};
pub use math::Vec2;
pub use types::{
    Body, BodyEdit, BodyMetadata, BodyUpdate, Scenario, ScenarioMetadata, SimulationState,
    Snapshot, StepSummary,
};
