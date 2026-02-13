use std::time::Instant;

use gravity_engine::{
    Body, CollisionMode, DtPolicy, EngineConfig, GravitySolver, IntegratorKind, SimulationEngine,
    Vec2,
};

fn main() {
    let cases = [
        BenchmarkCase {
            name: "small_pairwise",
            body_count: 128,
            ticks: 3000,
            gravity_solver: GravitySolver::Pairwise,
            theta: 0.6,
            threshold: 256,
        },
        BenchmarkCase {
            name: "medium_pairwise",
            body_count: 512,
            ticks: 1000,
            gravity_solver: GravitySolver::Pairwise,
            theta: 0.6,
            threshold: 256,
        },
        BenchmarkCase {
            name: "medium_auto",
            body_count: 512,
            ticks: 1500,
            gravity_solver: GravitySolver::Auto,
            theta: 0.6,
            threshold: 256,
        },
        BenchmarkCase {
            name: "large_auto",
            body_count: 2000,
            ticks: 600,
            gravity_solver: GravitySolver::Auto,
            theta: 0.6,
            threshold: 256,
        },
    ];

    println!(
        "name,solver,body_count,ticks,elapsed_ms,body_steps_per_sec,pairwise_ticks,barnes_hut_ticks,avg_tick_us"
    );

    for case in cases {
        let result = run_case(case);
        println!(
            "{},{},{},{},{:.3},{:.2},{},{},{}",
            result.name,
            result.solver,
            result.body_count,
            result.ticks,
            result.elapsed_ms,
            result.body_steps_per_sec,
            result.pairwise_ticks,
            result.barnes_hut_ticks,
            result.avg_tick_us,
        );
    }
}

#[derive(Clone, Copy)]
struct BenchmarkCase {
    name: &'static str,
    body_count: usize,
    ticks: u32,
    gravity_solver: GravitySolver,
    theta: f64,
    threshold: usize,
}

struct BenchmarkResult {
    name: &'static str,
    solver: &'static str,
    body_count: usize,
    ticks: u32,
    elapsed_ms: f64,
    body_steps_per_sec: f64,
    pairwise_ticks: u32,
    barnes_hut_ticks: u32,
    avg_tick_us: u64,
}

fn run_case(case: BenchmarkCase) -> BenchmarkResult {
    let config = EngineConfig {
        gravity_constant: 1.0,
        softening_epsilon: 1e-4,
        dt: 0.002,
        dt_policy: DtPolicy::Fixed,
        integrator: IntegratorKind::VelocityVerlet,
        collision_mode: CollisionMode::Ignore,
        deterministic: true,
        gravity_solver: case.gravity_solver,
        barnes_hut_theta: case.theta,
        barnes_hut_threshold: case.threshold,
    };

    let bodies = generate_orbital_system(case.body_count, config.gravity_constant);
    let mut engine =
        SimulationEngine::with_bodies(config, bodies).expect("benchmark engine should initialize");

    // Warm-up to avoid including first-step initialization effects.
    engine.step(200).expect("warm-up step should succeed");

    let start = Instant::now();
    let summary = engine
        .step(case.ticks)
        .expect("benchmark stepping should succeed");
    let elapsed = start.elapsed();

    let elapsed_ms = elapsed.as_secs_f64() * 1_000.0;
    let body_steps = (case.body_count as f64) * (case.ticks as f64);
    let body_steps_per_sec = body_steps / elapsed.as_secs_f64();

    BenchmarkResult {
        name: case.name,
        solver: match case.gravity_solver {
            GravitySolver::Pairwise => "pairwise",
            GravitySolver::BarnesHut => "barnesHut",
            GravitySolver::Auto => "auto",
        },
        body_count: case.body_count,
        ticks: case.ticks,
        elapsed_ms,
        body_steps_per_sec,
        pairwise_ticks: summary.pairwise_ticks,
        barnes_hut_ticks: summary.barnes_hut_ticks,
        avg_tick_us: summary.average_tick_micros,
    }
}

fn generate_orbital_system(body_count: usize, gravity_constant: f64) -> Vec<Body> {
    let mut bodies = Vec::with_capacity(body_count);

    let central_mass = 5000.0;
    bodies.push(Body::new("star", central_mass, 3.0, Vec2::ZERO, Vec2::ZERO));

    let orbiters = body_count.saturating_sub(1);
    for i in 0..orbiters {
        let idx = i as f64;
        let angle = (idx * 2.399963229728653) % std::f64::consts::TAU;
        let band = (i % 64) as f64;
        let radius = 20.0 + band * 1.2 + (idx / 256.0);

        let position = Vec2::new(radius * angle.cos(), radius * angle.sin());
        let tangent = Vec2::new(-angle.sin(), angle.cos());

        let mass = 0.2 + ((i % 11) as f64) * 0.05;
        let speed = (gravity_constant * central_mass / radius).sqrt();
        let velocity = tangent * speed;

        bodies.push(Body::new(
            format!("body_{i}"),
            mass,
            0.25,
            position,
            velocity,
        ));
    }

    bodies
}
