use serde::{Deserialize, Serialize};
use std::collections::hash_map::DefaultHasher;
use std::hash::{Hash, Hasher};

use crate::errors::{EngineError, Result};

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum IntegratorKind {
    SemiImplicitEuler,
    VelocityVerlet,
    Rk4,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum CollisionMode {
    Elastic,
    InelasticMerge,
    Ignore,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum DtPolicy {
    Fixed,
    Adaptive,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub enum GravitySolver {
    Pairwise,
    BarnesHut,
    Auto,
}

fn default_gravity_solver() -> GravitySolver {
    GravitySolver::Auto
}

fn default_barnes_hut_theta() -> f64 {
    0.6
}

fn default_barnes_hut_threshold() -> usize {
    256
}

#[derive(Clone, Debug, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct EngineConfig {
    pub gravity_constant: f64,
    pub softening_epsilon: f64,
    pub dt: f64,
    pub dt_policy: DtPolicy,
    pub integrator: IntegratorKind,
    pub collision_mode: CollisionMode,
    pub deterministic: bool,
    #[serde(default = "default_gravity_solver")]
    pub gravity_solver: GravitySolver,
    #[serde(default = "default_barnes_hut_theta")]
    pub barnes_hut_theta: f64,
    #[serde(default = "default_barnes_hut_threshold")]
    pub barnes_hut_threshold: usize,
}

impl Default for EngineConfig {
    fn default() -> Self {
        Self {
            gravity_constant: 6.67430e-11,
            softening_epsilon: 1e-3,
            dt: 1.0,
            dt_policy: DtPolicy::Fixed,
            integrator: IntegratorKind::VelocityVerlet,
            collision_mode: CollisionMode::InelasticMerge,
            deterministic: true,
            gravity_solver: default_gravity_solver(),
            barnes_hut_theta: default_barnes_hut_theta(),
            barnes_hut_threshold: default_barnes_hut_threshold(),
        }
    }
}

impl EngineConfig {
    pub fn validate(&self) -> Result<()> {
        if !self.gravity_constant.is_finite() || self.gravity_constant <= 0.0 {
            return Err(EngineError::InvalidConfig(
                "gravity_constant must be finite and > 0".to_string(),
            ));
        }
        if !self.softening_epsilon.is_finite() || self.softening_epsilon < 0.0 {
            return Err(EngineError::InvalidConfig(
                "softening_epsilon must be finite and >= 0".to_string(),
            ));
        }
        if !self.dt.is_finite() || self.dt <= 0.0 {
            return Err(EngineError::InvalidConfig(
                "dt must be finite and > 0".to_string(),
            ));
        }
        if self.deterministic && matches!(self.dt_policy, DtPolicy::Adaptive) {
            return Err(EngineError::InvalidConfig(
                "adaptive dt is not allowed in deterministic mode".to_string(),
            ));
        }
        if !self.barnes_hut_theta.is_finite()
            || self.barnes_hut_theta <= 0.0
            || self.barnes_hut_theta > 2.0
        {
            return Err(EngineError::InvalidConfig(
                "barnes_hut_theta must be finite and in (0, 2]".to_string(),
            ));
        }
        if self.barnes_hut_threshold == 0 {
            return Err(EngineError::InvalidConfig(
                "barnes_hut_threshold must be >= 1".to_string(),
            ));
        }
        Ok(())
    }

    pub fn stable_hash(&self) -> String {
        let mut hasher = DefaultHasher::new();
        self.integrator.hash(&mut hasher);
        self.collision_mode.hash(&mut hasher);
        self.dt_policy.hash(&mut hasher);
        self.deterministic.hash(&mut hasher);
        self.gravity_solver.hash(&mut hasher);
        self.barnes_hut_threshold.hash(&mut hasher);
        self.gravity_constant.to_bits().hash(&mut hasher);
        self.softening_epsilon.to_bits().hash(&mut hasher);
        self.dt.to_bits().hash(&mut hasher);
        self.barnes_hut_theta.to_bits().hash(&mut hasher);
        format!("{:016x}", hasher.finish())
    }
}
