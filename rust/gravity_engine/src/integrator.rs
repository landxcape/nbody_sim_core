use crate::config::{DtPolicy, EngineConfig, IntegratorKind};
use crate::errors::{EngineError, Result};
use crate::solver::{SolverRuntimeMode, compute_accelerations, compute_accelerations_with_config};
use crate::types::Body;

#[derive(Clone, Copy, Debug, PartialEq)]
pub(crate) struct IntegratorStepStats {
    pub used_barnes_hut: bool,
    pub dt_used: f64,
}

pub(crate) fn integrate_step(
    bodies: &mut [Body],
    config: &EngineConfig,
) -> Result<IntegratorStepStats> {
    let dt = effective_dt(bodies, config);
    let used_barnes_hut = match config.integrator {
        IntegratorKind::SemiImplicitEuler => semi_implicit_euler_step(bodies, config, dt)?,
        IntegratorKind::VelocityVerlet => velocity_verlet_step(bodies, config, dt)?,
        IntegratorKind::Rk4 => rk4_step(bodies, config, dt)?,
    };

    Ok(IntegratorStepStats {
        used_barnes_hut,
        dt_used: dt,
    })
}

fn effective_dt(bodies: &[Body], config: &EngineConfig) -> f64 {
    if !matches!(config.dt_policy, DtPolicy::Adaptive) {
        return config.dt;
    }

    let mut max_speed = 0.0_f64;
    for body in bodies.iter().filter(|body| body.alive) {
        max_speed = max_speed.max(body.velocity.norm());
    }

    let mut min_distance = f64::INFINITY;
    for i in 0..bodies.len() {
        if !bodies[i].alive {
            continue;
        }
        for j in (i + 1)..bodies.len() {
            if !bodies[j].alive {
                continue;
            }
            let distance = (bodies[j].position - bodies[i].position).norm();
            if distance > 0.0 {
                min_distance = min_distance.min(distance);
            }
        }
    }

    if !min_distance.is_finite() || max_speed == 0.0 {
        return config.dt;
    }

    let suggested = 0.05 * min_distance / max_speed;
    suggested.clamp(config.dt * 0.05, config.dt)
}

fn semi_implicit_euler_step(bodies: &mut [Body], config: &EngineConfig, dt: f64) -> Result<bool> {
    let (accelerations, stats) = compute_accelerations(bodies, config);

    for (index, body) in bodies.iter_mut().enumerate() {
        if !body.alive {
            continue;
        }
        body.velocity += accelerations[index] * dt;
        body.position += body.velocity * dt;
        ensure_finite_body(body)?;
    }

    Ok(matches!(stats.mode, SolverRuntimeMode::BarnesHut))
}

fn velocity_verlet_step(bodies: &mut [Body], config: &EngineConfig, dt: f64) -> Result<bool> {
    let original_positions = bodies.iter().map(|body| body.position).collect::<Vec<_>>();
    let (accelerations_0, stats_0) =
        compute_accelerations_with_config(bodies, &original_positions, config);

    let mut predicted_positions = original_positions.clone();
    for (index, body) in bodies.iter().enumerate() {
        if !body.alive {
            continue;
        }
        predicted_positions[index] =
            body.position + body.velocity * dt + accelerations_0[index] * (0.5 * dt * dt);
    }

    let (accelerations_1, stats_1) =
        compute_accelerations_with_config(bodies, &predicted_positions, config);

    for (index, body) in bodies.iter_mut().enumerate() {
        if !body.alive {
            continue;
        }
        body.position = predicted_positions[index];
        body.velocity += (accelerations_0[index] + accelerations_1[index]) * (0.5 * dt);
        ensure_finite_body(body)?;
    }

    Ok(matches!(stats_0.mode, SolverRuntimeMode::BarnesHut)
        || matches!(stats_1.mode, SolverRuntimeMode::BarnesHut))
}

fn rk4_step(bodies: &mut [Body], config: &EngineConfig, dt: f64) -> Result<bool> {
    let count = bodies.len();
    let p0 = bodies.iter().map(|body| body.position).collect::<Vec<_>>();
    let v0 = bodies.iter().map(|body| body.velocity).collect::<Vec<_>>();

    let (a1, stats_1) = compute_accelerations_with_config(bodies, &p0, config);
    let k1p = v0.clone();
    let k1v = a1;

    let p2 = (0..count)
        .map(|i| p0[i] + k1p[i] * (0.5 * dt))
        .collect::<Vec<_>>();
    let v2 = (0..count)
        .map(|i| v0[i] + k1v[i] * (0.5 * dt))
        .collect::<Vec<_>>();
    let (k2v, stats_2) = compute_accelerations_with_config(bodies, &p2, config);
    let k2p = v2;

    let p3 = (0..count)
        .map(|i| p0[i] + k2p[i] * (0.5 * dt))
        .collect::<Vec<_>>();
    let v3 = (0..count)
        .map(|i| v0[i] + k2v[i] * (0.5 * dt))
        .collect::<Vec<_>>();
    let (k3v, stats_3) = compute_accelerations_with_config(bodies, &p3, config);
    let k3p = v3;

    let p4 = (0..count).map(|i| p0[i] + k3p[i] * dt).collect::<Vec<_>>();
    let v4 = (0..count).map(|i| v0[i] + k3v[i] * dt).collect::<Vec<_>>();
    let (k4v, stats_4) = compute_accelerations_with_config(bodies, &p4, config);
    let k4p = v4;

    for i in 0..count {
        if !bodies[i].alive {
            continue;
        }
        let dp = (k1p[i] + k2p[i] * 2.0 + k3p[i] * 2.0 + k4p[i]) * (dt / 6.0);
        let dv = (k1v[i] + k2v[i] * 2.0 + k3v[i] * 2.0 + k4v[i]) * (dt / 6.0);
        bodies[i].position += dp;
        bodies[i].velocity += dv;
        ensure_finite_body(&bodies[i])?;
    }

    Ok(matches!(stats_1.mode, SolverRuntimeMode::BarnesHut)
        || matches!(stats_2.mode, SolverRuntimeMode::BarnesHut)
        || matches!(stats_3.mode, SolverRuntimeMode::BarnesHut)
        || matches!(stats_4.mode, SolverRuntimeMode::BarnesHut))
}

fn ensure_finite_body(body: &Body) -> Result<()> {
    if !body.position.is_finite() || !body.velocity.is_finite() {
        return Err(EngineError::NumericalInstability(format!(
            "body '{}' produced non-finite state",
            body.id
        )));
    }
    Ok(())
}
