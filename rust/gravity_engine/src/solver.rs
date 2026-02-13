use crate::config::{EngineConfig, GravitySolver};
use crate::math::Vec2;
use crate::types::Body;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) enum SolverRuntimeMode {
    Pairwise,
    BarnesHut,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct SolverStats {
    pub mode: SolverRuntimeMode,
}

pub(crate) fn compute_accelerations(
    bodies: &[Body],
    config: &EngineConfig,
) -> (Vec<Vec2>, SolverStats) {
    let positions = bodies.iter().map(|body| body.position).collect::<Vec<_>>();
    compute_accelerations_with_config(bodies, &positions, config)
}

pub(crate) fn compute_accelerations_with_config(
    bodies: &[Body],
    positions: &[Vec2],
    config: &EngineConfig,
) -> (Vec<Vec2>, SolverStats) {
    let alive_count = bodies.iter().filter(|body| body.alive).count();
    let mode = choose_runtime_mode(alive_count, config);

    match mode {
        SolverRuntimeMode::Pairwise => (
            pairwise_accelerations_from_positions(
                bodies,
                positions,
                config.gravity_constant,
                config.softening_epsilon,
            ),
            SolverStats {
                mode: SolverRuntimeMode::Pairwise,
            },
        ),
        SolverRuntimeMode::BarnesHut => (
            barnes_hut_accelerations_from_positions(
                bodies,
                positions,
                config.gravity_constant,
                config.softening_epsilon,
                config.barnes_hut_theta,
            ),
            SolverStats {
                mode: SolverRuntimeMode::BarnesHut,
            },
        ),
    }
}

fn choose_runtime_mode(alive_count: usize, config: &EngineConfig) -> SolverRuntimeMode {
    match config.gravity_solver {
        GravitySolver::Pairwise => SolverRuntimeMode::Pairwise,
        GravitySolver::BarnesHut => {
            if alive_count >= 2 {
                SolverRuntimeMode::BarnesHut
            } else {
                SolverRuntimeMode::Pairwise
            }
        }
        GravitySolver::Auto => {
            if alive_count >= config.barnes_hut_threshold {
                SolverRuntimeMode::BarnesHut
            } else {
                SolverRuntimeMode::Pairwise
            }
        }
    }
}

fn pairwise_accelerations_from_positions(
    bodies: &[Body],
    positions: &[Vec2],
    gravity_constant: f64,
    softening_epsilon: f64,
) -> Vec<Vec2> {
    let count = bodies.len();
    let mut accelerations = vec![Vec2::ZERO; count];
    let epsilon2 = softening_epsilon * softening_epsilon;

    for i in 0..count {
        if !bodies[i].alive {
            continue;
        }
        for j in (i + 1)..count {
            if !bodies[j].alive {
                continue;
            }

            let delta = positions[j] - positions[i];
            let dist_sq = delta.norm_squared() + epsilon2;
            if dist_sq <= 0.0 {
                continue;
            }

            let inv_dist = dist_sq.sqrt().recip();
            let inv_dist3 = inv_dist * inv_dist * inv_dist;
            let scale = gravity_constant * inv_dist3;

            accelerations[i] += delta * (scale * bodies[j].mass);
            accelerations[j] -= delta * (scale * bodies[i].mass);
        }
    }

    accelerations
}

fn barnes_hut_accelerations_from_positions(
    bodies: &[Body],
    positions: &[Vec2],
    gravity_constant: f64,
    softening_epsilon: f64,
    theta: f64,
) -> Vec<Vec2> {
    let count = bodies.len();
    let mut accelerations = vec![Vec2::ZERO; count];

    let alive_indices = bodies
        .iter()
        .enumerate()
        .filter_map(|(index, body)| body.alive.then_some(index))
        .collect::<Vec<_>>();

    if alive_indices.len() < 2 {
        return accelerations;
    }

    let masses = bodies.iter().map(|body| body.mass).collect::<Vec<_>>();
    let Some(root) = build_quadtree(positions, &alive_indices, &masses) else {
        return accelerations;
    };

    let epsilon2 = softening_epsilon * softening_epsilon;

    for &index in &alive_indices {
        let mut acceleration = Vec2::ZERO;
        accumulate_force_from_node(
            &root,
            index,
            positions[index],
            gravity_constant,
            epsilon2,
            theta,
            &mut acceleration,
        );
        accelerations[index] = acceleration;
    }

    accelerations
}

fn build_quadtree(positions: &[Vec2], alive_indices: &[usize], masses: &[f64]) -> Option<QuadNode> {
    if alive_indices.is_empty() {
        return None;
    }

    let mut min_x = f64::INFINITY;
    let mut max_x = -f64::INFINITY;
    let mut min_y = f64::INFINITY;
    let mut max_y = -f64::INFINITY;

    for &index in alive_indices {
        let position = positions[index];
        min_x = min_x.min(position.x);
        max_x = max_x.max(position.x);
        min_y = min_y.min(position.y);
        max_y = max_y.max(position.y);
    }

    let span = (max_x - min_x).abs().max((max_y - min_y).abs()).max(1e-6);
    let half_size = 0.5 * span + 1e-6;
    let center = Vec2::new(0.5 * (min_x + max_x), 0.5 * (min_y + max_y));

    let mut root = QuadNode::new(center, half_size);
    let min_half = (half_size * 1e-6).max(1e-9);

    for &index in alive_indices {
        root.insert(index, positions, masses, min_half);
    }

    Some(root)
}

fn accumulate_force_from_node(
    node: &QuadNode,
    body_index: usize,
    body_position: Vec2,
    gravity_constant: f64,
    epsilon2: f64,
    theta: f64,
    out_acceleration: &mut Vec2,
) {
    if node.count == 0 || node.mass <= 0.0 {
        return;
    }

    if node.count == 1 && node.body_index == Some(body_index) {
        return;
    }

    let delta = node.com - body_position;
    let dist_sq = delta.norm_squared() + epsilon2;
    if dist_sq <= 0.0 {
        return;
    }

    let distance = dist_sq.sqrt();
    let size = node.half_size * 2.0;

    if node.is_leaf() || (size / distance) < theta {
        let inv_dist = distance.recip();
        let inv_dist3 = inv_dist * inv_dist * inv_dist;
        *out_acceleration += delta * (gravity_constant * node.mass * inv_dist3);
        return;
    }

    for child in node.children.iter().flatten() {
        accumulate_force_from_node(
            child,
            body_index,
            body_position,
            gravity_constant,
            epsilon2,
            theta,
            out_acceleration,
        );
    }
}

#[derive(Clone, Debug)]
struct QuadNode {
    center: Vec2,
    half_size: f64,
    mass: f64,
    com: Vec2,
    count: usize,
    body_index: Option<usize>,
    children: [Option<Box<QuadNode>>; 4],
}

impl QuadNode {
    fn new(center: Vec2, half_size: f64) -> Self {
        Self {
            center,
            half_size,
            mass: 0.0,
            com: Vec2::ZERO,
            count: 0,
            body_index: None,
            children: Default::default(),
        }
    }

    fn is_leaf(&self) -> bool {
        self.children.iter().all(|child| child.is_none())
    }

    fn insert(&mut self, index: usize, positions: &[Vec2], masses: &[f64], min_half: f64) {
        let position = positions[index];
        let mass = masses[index];

        if self.count == 0 {
            self.count = 1;
            self.mass = mass;
            self.com = position;
            self.body_index = Some(index);
            return;
        }

        let previous_mass = self.mass;
        let next_mass = previous_mass + mass;
        if next_mass > 0.0 {
            self.com = (self.com * previous_mass + position * mass) / next_mass;
        }
        self.mass = next_mass;
        self.count += 1;

        if self.is_leaf() {
            if let Some(existing_index) = self.body_index.take() {
                let same_spot = (positions[existing_index] - position).norm_squared() <= 1e-18;
                if self.half_size <= min_half || same_spot {
                    self.body_index = None;
                    return;
                }

                self.ensure_children();
                self.insert_into_child(existing_index, positions, masses, min_half);
                self.insert_into_child(index, positions, masses, min_half);
                return;
            }

            // Aggregated leaf already stores multiple bodies and cannot subdivide further.
            return;
        }

        self.insert_into_child(index, positions, masses, min_half);
    }

    fn insert_into_child(
        &mut self,
        index: usize,
        positions: &[Vec2],
        masses: &[f64],
        min_half: f64,
    ) {
        if self.is_leaf() {
            self.ensure_children();
        }

        let child_index = self.child_index(positions[index]);
        if let Some(child) = self.children[child_index].as_mut() {
            child.insert(index, positions, masses, min_half);
        }
    }

    fn ensure_children(&mut self) {
        if !self.is_leaf() {
            return;
        }

        let child_half = self.half_size * 0.5;
        for index in 0..4 {
            let center = child_center(self.center, child_half, index);
            self.children[index] = Some(Box::new(QuadNode::new(center, child_half)));
        }
    }

    fn child_index(&self, position: Vec2) -> usize {
        let x = usize::from(position.x >= self.center.x);
        let y = if position.y >= self.center.y { 2 } else { 0 };
        x + y
    }
}

fn child_center(center: Vec2, child_half: f64, index: usize) -> Vec2 {
    let x_offset = if index % 2 == 0 {
        -child_half
    } else {
        child_half
    };
    let y_offset = if index < 2 { -child_half } else { child_half };
    Vec2::new(center.x + x_offset, center.y + y_offset)
}
