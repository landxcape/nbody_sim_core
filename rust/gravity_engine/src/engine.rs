use std::collections::HashSet;
use std::time::Instant;

use crate::collision::resolve_collisions;
use crate::config::EngineConfig;
use crate::errors::{EngineError, Result};
use crate::integrator::integrate_step;
use crate::types::{
    Body, BodyEdit, BodyUpdate, Scenario, ScenarioMetadata, SimulationState, Snapshot, StepSummary,
    deterministic_timestamp_iso8601,
};

#[derive(Clone, Debug)]
pub struct SimulationEngine {
    config: EngineConfig,
    bodies: Vec<Body>,
    tick: u64,
    sim_time: f64,
}

impl SimulationEngine {
    pub fn initialize(config: EngineConfig) -> Result<Self> {
        config.validate()?;
        Ok(Self {
            config,
            bodies: Vec::new(),
            tick: 0,
            sim_time: 0.0,
        })
    }

    pub fn with_bodies(config: EngineConfig, bodies: Vec<Body>) -> Result<Self> {
        config.validate()?;
        validate_unique_body_ids(&bodies)?;
        for body in &bodies {
            body.validate()?;
        }
        Ok(Self {
            config,
            bodies,
            tick: 0,
            sim_time: 0.0,
        })
    }

    pub fn config(&self) -> &EngineConfig {
        &self.config
    }

    pub fn bodies(&self) -> &[Body] {
        &self.bodies
    }

    pub fn set_config(&mut self, config: EngineConfig) -> Result<()> {
        config.validate()?;
        self.config = config;
        Ok(())
    }

    pub fn apply_edit(&mut self, edit: BodyEdit) -> Result<()> {
        match edit {
            BodyEdit::Create(body) => self.create_body(body),
            BodyEdit::Update(update) => self.update_body(update),
            BodyEdit::Delete { id } => self.delete_body(&id),
        }
    }

    pub fn step(&mut self, ticks: u32) -> Result<StepSummary> {
        let mut summary = StepSummary::default();
        summary.max_body_count = self.bodies.len();

        if ticks == 0 {
            summary.final_tick = self.tick;
            summary.sim_time = self.sim_time;
            return Ok(summary);
        }

        let wall_start = Instant::now();

        for _ in 0..ticks {
            let integration_stats = integrate_step(&mut self.bodies, &self.config)?;
            let collision_stats = resolve_collisions(&mut self.bodies, self.config.collision_mode);

            summary.collision_events += collision_stats.collisions;
            summary.merged_events += collision_stats.merges;
            summary.ticks_applied += 1;
            summary.max_body_count = summary.max_body_count.max(self.bodies.len());

            if integration_stats.used_barnes_hut {
                summary.barnes_hut_ticks += 1;
                summary.last_solver_mode = "barnesHut".to_string();
            } else {
                summary.pairwise_ticks += 1;
                summary.last_solver_mode = "pairwise".to_string();
            }

            self.tick += 1;
            self.sim_time += integration_stats.dt_used;
        }

        summary.step_wall_time_micros = wall_start.elapsed().as_micros() as u64;
        if summary.ticks_applied > 0 {
            summary.average_tick_micros =
                summary.step_wall_time_micros / (summary.ticks_applied as u64);
        }

        for body in &self.bodies {
            if !body.position.is_finite() || !body.velocity.is_finite() {
                return Err(EngineError::NumericalInstability(format!(
                    "body '{}' produced non-finite values after stepping",
                    body.id
                )));
            }
        }

        summary.final_tick = self.tick;
        summary.sim_time = self.sim_time;
        Ok(summary)
    }

    pub fn get_state(&self) -> SimulationState {
        SimulationState {
            tick: self.tick,
            sim_time: self.sim_time,
            config: self.config.clone(),
            bodies: self.bodies.clone(),
        }
    }

    pub fn load_scenario(&mut self, scenario: Scenario) -> Result<()> {
        if !scenario.schema_version.starts_with('1') {
            return Err(EngineError::SchemaValidationFailed(
                "only scenario schema v1.x is supported".to_string(),
            ));
        }

        scenario.engine_config.validate()?;
        validate_unique_body_ids(&scenario.bodies)?;
        for body in &scenario.bodies {
            body.validate()?;
        }

        self.config = scenario.engine_config;
        self.bodies = scenario.bodies;
        self.tick = 0;
        self.sim_time = 0.0;
        Ok(())
    }

    pub fn save_scenario(&self) -> Scenario {
        Scenario {
            schema_version: "1.0".to_string(),
            metadata: ScenarioMetadata {
                name: "Untitled".to_string(),
                description: None,
                author: None,
                created_at: deterministic_timestamp_iso8601(),
                tags: Vec::new(),
            },
            engine_config: self.config.clone(),
            bodies: self.bodies.clone(),
        }
    }

    pub fn snapshot(&self) -> Snapshot {
        Snapshot {
            schema_version: "1.0".to_string(),
            created_at: deterministic_timestamp_iso8601(),
            tick: self.tick,
            sim_time: self.sim_time,
            config_hash: self.config.stable_hash(),
            bodies: self.bodies.clone(),
        }
    }

    pub fn restore_snapshot(&mut self, snapshot: Snapshot) -> Result<()> {
        if !snapshot.schema_version.starts_with('1') {
            return Err(EngineError::SchemaValidationFailed(
                "only snapshot schema v1.x is supported".to_string(),
            ));
        }

        validate_unique_body_ids(&snapshot.bodies)?;
        for body in &snapshot.bodies {
            body.validate()?;
        }

        self.tick = snapshot.tick;
        self.sim_time = snapshot.sim_time;
        self.bodies = snapshot.bodies;
        Ok(())
    }

    fn create_body(&mut self, body: Body) -> Result<()> {
        body.validate()?;
        if self.bodies.iter().any(|existing| existing.id == body.id) {
            return Err(EngineError::DuplicateBodyId(body.id));
        }
        self.bodies.push(body);
        Ok(())
    }

    fn update_body(&mut self, update: BodyUpdate) -> Result<()> {
        let body = self
            .bodies
            .iter_mut()
            .find(|body| body.id == update.id)
            .ok_or_else(|| EngineError::BodyNotFound(update.id.clone()))?;

        if let Some(mass) = update.mass {
            body.mass = mass;
        }
        if let Some(radius) = update.radius {
            body.radius = radius;
        }
        if let Some(position) = update.position {
            body.position = position;
        }
        if let Some(velocity) = update.velocity {
            body.velocity = velocity;
        }
        if let Some(alive) = update.alive {
            body.alive = alive;
        }
        if let Some(metadata) = update.metadata {
            body.metadata = Some(metadata);
        }

        body.validate()
    }

    fn delete_body(&mut self, id: &str) -> Result<()> {
        let initial_count = self.bodies.len();
        self.bodies.retain(|body| body.id != id);
        if self.bodies.len() == initial_count {
            return Err(EngineError::BodyNotFound(id.to_string()));
        }
        Ok(())
    }
}

fn validate_unique_body_ids(bodies: &[Body]) -> Result<()> {
    let mut ids = HashSet::new();
    for body in bodies {
        if !ids.insert(body.id.clone()) {
            return Err(EngineError::DuplicateBodyId(body.id.clone()));
        }
    }
    Ok(())
}
