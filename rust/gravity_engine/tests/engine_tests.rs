use gravity_engine::{
    Body, CollisionMode, DtPolicy, EngineConfig, GravitySolver, IntegratorKind, SimulationEngine,
    Vec2,
};

fn base_config() -> EngineConfig {
    EngineConfig {
        gravity_constant: 1.0,
        softening_epsilon: 1e-6,
        dt: 0.001,
        dt_policy: DtPolicy::Fixed,
        integrator: IntegratorKind::VelocityVerlet,
        collision_mode: CollisionMode::Ignore,
        deterministic: true,
        gravity_solver: GravitySolver::Pairwise,
        barnes_hut_theta: 0.6,
        barnes_hut_threshold: 256,
    }
}

fn approx_eq(a: f64, b: f64, tol: f64) {
    let diff = (a - b).abs();
    assert!(
        diff <= tol,
        "expected |{} - {}| <= {}, got {}",
        a,
        b,
        tol,
        diff
    );
}

fn total_momentum(bodies: &[Body]) -> Vec2 {
    bodies
        .iter()
        .filter(|b| b.alive)
        .fold(Vec2::ZERO, |acc, b| acc + b.velocity * b.mass)
}

fn center_of_mass(bodies: &[Body]) -> Vec2 {
    let total_mass = bodies
        .iter()
        .filter(|b| b.alive)
        .map(|b| b.mass)
        .sum::<f64>();
    let weighted_position = bodies
        .iter()
        .filter(|b| b.alive)
        .fold(Vec2::ZERO, |acc, b| acc + b.position * b.mass);
    weighted_position / total_mass
}

fn total_energy(bodies: &[Body], g: f64) -> f64 {
    let kinetic = bodies
        .iter()
        .filter(|b| b.alive)
        .map(|b| 0.5 * b.mass * b.velocity.norm_squared())
        .sum::<f64>();

    let mut potential = 0.0;
    for i in 0..bodies.len() {
        if !bodies[i].alive {
            continue;
        }
        for j in (i + 1)..bodies.len() {
            if !bodies[j].alive {
                continue;
            }
            let r = (bodies[j].position - bodies[i].position).norm().max(1e-9);
            potential -= g * bodies[i].mass * bodies[j].mass / r;
        }
    }

    kinetic + potential
}

#[test]
fn two_body_distance_shrinks_under_gravity() {
    let config = EngineConfig {
        dt: 0.01,
        ..base_config()
    };

    let bodies = vec![
        Body::new("a", 10.0, 0.1, Vec2::new(-1.0, 0.0), Vec2::ZERO),
        Body::new("b", 10.0, 0.1, Vec2::new(1.0, 0.0), Vec2::ZERO),
    ];

    let initial_distance = (bodies[1].position - bodies[0].position).norm();

    let mut engine = SimulationEngine::with_bodies(config, bodies).unwrap();
    engine.step(50).unwrap();

    let final_bodies = engine.bodies();
    let final_distance = (final_bodies[1].position - final_bodies[0].position).norm();
    assert!(final_distance < initial_distance);
}

#[test]
fn momentum_is_conserved_in_closed_system() {
    let config = EngineConfig {
        softening_epsilon: 1e-5,
        ..base_config()
    };

    let bodies = vec![
        Body::new("a", 4.0, 0.05, Vec2::new(-2.0, 0.0), Vec2::new(0.0, 0.3)),
        Body::new("b", 2.0, 0.05, Vec2::new(2.0, 0.0), Vec2::new(0.0, -0.6)),
    ];

    let p0 = total_momentum(&bodies);
    let mut engine = SimulationEngine::with_bodies(config, bodies).unwrap();
    engine.step(4000).unwrap();
    let p1 = total_momentum(engine.bodies());

    approx_eq(p0.x, p1.x, 1e-9);
    approx_eq(p0.y, p1.y, 1e-9);
}

#[test]
fn center_of_mass_is_stable_without_external_force() {
    let config = base_config();

    let bodies = vec![
        Body::new("a", 3.0, 0.05, Vec2::new(-1.0, 0.0), Vec2::new(0.0, 0.4)),
        Body::new("b", 3.0, 0.05, Vec2::new(1.0, 0.0), Vec2::new(0.0, -0.4)),
    ];

    let com0 = center_of_mass(&bodies);
    let mut engine = SimulationEngine::with_bodies(config, bodies).unwrap();
    engine.step(4000).unwrap();
    let com1 = center_of_mass(engine.bodies());

    approx_eq(com0.x, com1.x, 1e-9);
    approx_eq(com0.y, com1.y, 1e-9);
}

#[test]
fn verlet_energy_drift_is_lower_than_euler() {
    let g: f64 = 1.0;
    let dt: f64 = 0.001;
    let star_mass: f64 = 1000.0;
    let planet_mass: f64 = 1.0;
    let radius: f64 = 10.0;
    let orbital_speed = (g * star_mass / radius).sqrt();

    let base_bodies = vec![
        Body::new(
            "star",
            star_mass,
            0.5,
            Vec2::new(0.0, 0.0),
            Vec2::new(0.0, -planet_mass * orbital_speed / star_mass),
        ),
        Body::new(
            "planet",
            planet_mass,
            0.1,
            Vec2::new(radius, 0.0),
            Vec2::new(0.0, orbital_speed),
        ),
    ];

    let mut config_euler = EngineConfig {
        gravity_constant: g,
        dt,
        integrator: IntegratorKind::SemiImplicitEuler,
        ..base_config()
    };

    let config_verlet = EngineConfig {
        integrator: IntegratorKind::VelocityVerlet,
        ..config_euler.clone()
    };

    let e0 = total_energy(&base_bodies, g);

    let mut euler_engine =
        SimulationEngine::with_bodies(config_euler.clone(), base_bodies.clone()).unwrap();
    euler_engine.step(20_000).unwrap();
    let euler_drift = ((total_energy(euler_engine.bodies(), g) - e0) / e0).abs();

    let mut verlet_engine = SimulationEngine::with_bodies(config_verlet, base_bodies).unwrap();
    verlet_engine.step(20_000).unwrap();
    let verlet_drift = ((total_energy(verlet_engine.bodies(), g) - e0) / e0).abs();

    assert!(
        verlet_drift < euler_drift,
        "expected Verlet drift ({}) < Euler drift ({})",
        verlet_drift,
        euler_drift
    );

    config_euler.integrator = IntegratorKind::SemiImplicitEuler;
    assert!(config_euler.validate().is_ok());
}

#[test]
fn deterministic_replay_produces_identical_snapshots() {
    let config = EngineConfig {
        dt: 0.002,
        integrator: IntegratorKind::Rk4,
        ..base_config()
    };

    let bodies = vec![
        Body::new("a", 8.0, 0.2, Vec2::new(-2.0, 0.0), Vec2::new(0.0, 0.4)),
        Body::new("b", 3.0, 0.1, Vec2::new(1.0, 0.0), Vec2::new(0.0, -0.7)),
        Body::new("c", 1.0, 0.1, Vec2::new(0.0, 2.0), Vec2::new(-0.5, 0.0)),
    ];

    let mut engine_a = SimulationEngine::with_bodies(config.clone(), bodies.clone()).unwrap();
    let mut engine_b = SimulationEngine::with_bodies(config, bodies).unwrap();

    engine_a.step(4000).unwrap();
    engine_b.step(4000).unwrap();

    assert_eq!(engine_a.snapshot(), engine_b.snapshot());
}

#[test]
fn inelastic_merge_conserves_mass_and_momentum() {
    let config = EngineConfig {
        collision_mode: CollisionMode::InelasticMerge,
        ..base_config()
    };

    let bodies = vec![
        Body::new("a", 2.0, 1.0, Vec2::new(0.0, 0.0), Vec2::new(1.0, 0.0)),
        Body::new("b", 3.0, 1.0, Vec2::new(0.5, 0.0), Vec2::new(-0.5, 0.0)),
    ];

    let p0 = total_momentum(&bodies);
    let mass0: f64 = bodies.iter().map(|b| b.mass).sum();

    let mut engine = SimulationEngine::with_bodies(config, bodies).unwrap();
    let summary = engine.step(1).unwrap();

    assert_eq!(summary.merged_events, 1);
    assert_eq!(engine.bodies().len(), 1);

    let merged_body = &engine.bodies()[0];
    approx_eq(merged_body.mass, mass0, 1e-12);

    let p1 = total_momentum(engine.bodies());
    approx_eq(p0.x, p1.x, 1e-10);
    approx_eq(p0.y, p1.y, 1e-10);
}

#[test]
fn auto_solver_switches_between_pairwise_and_barnes_hut() {
    let bodies = vec![
        Body::new("a", 2.0, 0.2, Vec2::new(-3.0, 0.0), Vec2::new(0.0, 0.1)),
        Body::new("b", 2.0, 0.2, Vec2::new(3.0, 0.0), Vec2::new(0.0, -0.1)),
        Body::new("c", 2.0, 0.2, Vec2::new(0.0, 3.0), Vec2::new(-0.1, 0.0)),
    ];

    let mut pairwise_engine = SimulationEngine::with_bodies(
        EngineConfig {
            gravity_solver: GravitySolver::Auto,
            barnes_hut_threshold: 100,
            ..base_config()
        },
        bodies.clone(),
    )
    .unwrap();

    let pairwise_summary = pairwise_engine.step(10).unwrap();
    assert_eq!(pairwise_summary.barnes_hut_ticks, 0);
    assert_eq!(pairwise_summary.pairwise_ticks, 10);

    let mut bh_engine = SimulationEngine::with_bodies(
        EngineConfig {
            gravity_solver: GravitySolver::Auto,
            barnes_hut_threshold: 2,
            ..base_config()
        },
        bodies,
    )
    .unwrap();

    let bh_summary = bh_engine.step(10).unwrap();
    assert_eq!(bh_summary.pairwise_ticks, 0);
    assert_eq!(bh_summary.barnes_hut_ticks, 10);
}

#[test]
fn barnes_hut_tracks_pairwise_with_reasonable_tolerance() {
    let mut bodies = Vec::new();
    for i in 0..120 {
        let angle = (i as f64) * 0.173;
        let radius = 20.0 + ((i % 17) as f64);
        let position = Vec2::new(radius * angle.cos(), radius * angle.sin());
        let tangent = Vec2::new(-angle.sin(), angle.cos());
        let speed = (1000.0 / radius).sqrt();
        bodies.push(Body::new(
            format!("b{i}"),
            0.2 + ((i % 9) as f64) * 0.03,
            0.2,
            position,
            tangent * speed,
        ));
    }
    bodies.push(Body::new("star", 1000.0, 1.5, Vec2::ZERO, Vec2::ZERO));

    let mut pairwise_engine = SimulationEngine::with_bodies(
        EngineConfig {
            gravity_solver: GravitySolver::Pairwise,
            ..base_config()
        },
        bodies.clone(),
    )
    .unwrap();

    let mut bh_engine = SimulationEngine::with_bodies(
        EngineConfig {
            gravity_solver: GravitySolver::BarnesHut,
            barnes_hut_theta: 0.6,
            ..base_config()
        },
        bodies,
    )
    .unwrap();

    pairwise_engine.step(120).unwrap();
    bh_engine.step(120).unwrap();

    let com_pairwise = center_of_mass(pairwise_engine.bodies());
    let com_bh = center_of_mass(bh_engine.bodies());

    let momentum_pairwise = total_momentum(pairwise_engine.bodies());
    let momentum_bh = total_momentum(bh_engine.bodies());

    approx_eq(com_pairwise.x, com_bh.x, 1e-3);
    approx_eq(com_pairwise.y, com_bh.y, 1e-3);
    approx_eq(momentum_pairwise.x, momentum_bh.x, 5e-2);
    approx_eq(momentum_pairwise.y, momentum_bh.y, 5e-2);
}

#[test]
fn escape_velocity_threshold_matches_energy_sign() {
    let g: f64 = 1.0;
    let central_mass: f64 = 100.0;
    let r: f64 = 10.0;
    let v_escape = (2.0 * g * central_mass / r).sqrt();

    let specific_energy_below = 0.5 * (0.99 * v_escape).powi(2) - g * central_mass / r;
    let specific_energy_above = 0.5 * (1.01 * v_escape).powi(2) - g * central_mass / r;

    assert!(specific_energy_below < 0.0);
    assert!(specific_energy_above > 0.0);
}
