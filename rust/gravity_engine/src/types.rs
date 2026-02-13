use serde::{Deserialize, Serialize};

use crate::config::EngineConfig;
use crate::errors::{EngineError, Result};
use crate::math::Vec2;

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BodyMetadata {
    pub label: Option<String>,
    pub kind: Option<String>,
    pub color: Option<String>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Body {
    pub id: String,
    pub mass: f64,
    pub radius: f64,
    pub position: Vec2,
    pub velocity: Vec2,
    pub alive: bool,
    pub metadata: Option<BodyMetadata>,
}

impl Body {
    pub fn new(
        id: impl Into<String>,
        mass: f64,
        radius: f64,
        position: Vec2,
        velocity: Vec2,
    ) -> Self {
        Self {
            id: id.into(),
            mass,
            radius,
            position,
            velocity,
            alive: true,
            metadata: None,
        }
    }

    pub fn validate(&self) -> Result<()> {
        if self.id.trim().is_empty() {
            return Err(EngineError::InvalidBody("id must not be empty".to_string()));
        }
        if !self.mass.is_finite() || self.mass <= 0.0 {
            return Err(EngineError::InvalidBody(format!(
                "body '{}' mass must be finite and > 0",
                self.id
            )));
        }
        if !self.radius.is_finite() || self.radius <= 0.0 {
            return Err(EngineError::InvalidBody(format!(
                "body '{}' radius must be finite and > 0",
                self.id
            )));
        }
        if !self.position.is_finite() {
            return Err(EngineError::InvalidBody(format!(
                "body '{}' position must be finite",
                self.id
            )));
        }
        if !self.velocity.is_finite() {
            return Err(EngineError::InvalidBody(format!(
                "body '{}' velocity must be finite",
                self.id
            )));
        }
        Ok(())
    }
}

#[derive(Clone, Debug, Default, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct BodyUpdate {
    pub id: String,
    pub mass: Option<f64>,
    pub radius: Option<f64>,
    pub position: Option<Vec2>,
    pub velocity: Option<Vec2>,
    pub alive: Option<bool>,
    pub metadata: Option<BodyMetadata>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum BodyEdit {
    Create(Body),
    Update(BodyUpdate),
    Delete { id: String },
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct StepSummary {
    pub ticks_applied: u32,
    pub final_tick: u64,
    pub sim_time: f64,
    pub collision_events: u64,
    pub merged_events: u64,
    pub warnings: Vec<String>,
    #[serde(default)]
    pub pairwise_ticks: u32,
    #[serde(default)]
    pub barnes_hut_ticks: u32,
    #[serde(default)]
    pub step_wall_time_micros: u64,
    #[serde(default)]
    pub average_tick_micros: u64,
    #[serde(default)]
    pub max_body_count: usize,
    #[serde(default)]
    pub last_solver_mode: String,
}

impl Default for StepSummary {
    fn default() -> Self {
        Self {
            ticks_applied: 0,
            final_tick: 0,
            sim_time: 0.0,
            collision_events: 0,
            merged_events: 0,
            warnings: Vec::new(),
            pairwise_ticks: 0,
            barnes_hut_ticks: 0,
            step_wall_time_micros: 0,
            average_tick_micros: 0,
            max_body_count: 0,
            last_solver_mode: "pairwise".to_string(),
        }
    }
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct SimulationState {
    pub tick: u64,
    pub sim_time: f64,
    pub config: EngineConfig,
    pub bodies: Vec<Body>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ScenarioMetadata {
    pub name: String,
    pub description: Option<String>,
    pub author: Option<String>,
    pub created_at: String,
    pub tags: Vec<String>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Scenario {
    pub schema_version: String,
    pub metadata: ScenarioMetadata,
    pub engine_config: EngineConfig,
    pub bodies: Vec<Body>,
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct Snapshot {
    pub schema_version: String,
    pub created_at: String,
    pub tick: u64,
    pub sim_time: f64,
    pub config_hash: String,
    pub bodies: Vec<Body>,
}

// Intentionally stable so deterministic replays can compare snapshots byte-for-byte.
pub fn deterministic_timestamp_iso8601() -> String {
    "1970-01-01T00:00:00Z".to_string()
}
