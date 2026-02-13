use crate::config::CollisionMode;
use crate::math::Vec2;
use crate::types::Body;

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct CollisionStats {
    pub collisions: u64,
    pub merges: u64,
}

pub(crate) fn resolve_collisions(bodies: &mut Vec<Body>, mode: CollisionMode) -> CollisionStats {
    if matches!(mode, CollisionMode::Ignore) {
        return CollisionStats::default();
    }

    let mut stats = CollisionStats::default();
    let count = bodies.len();

    for i in 0..count {
        if !bodies[i].alive {
            continue;
        }
        for j in (i + 1)..count {
            if !bodies[j].alive {
                continue;
            }

            let delta = bodies[j].position - bodies[i].position;
            let distance = delta.norm();
            let collision_distance = bodies[i].radius + bodies[j].radius;

            if distance > collision_distance {
                continue;
            }

            stats.collisions += 1;

            match mode {
                CollisionMode::Elastic => {
                    apply_elastic_collision(bodies, i, j, delta, distance, collision_distance);
                }
                CollisionMode::InelasticMerge => {
                    apply_inelastic_merge(bodies, i, j);
                    stats.merges += 1;
                }
                CollisionMode::Ignore => {}
            }
        }
    }

    if matches!(mode, CollisionMode::InelasticMerge) {
        bodies.retain(|body| body.alive);
    }

    stats
}

fn apply_inelastic_merge(bodies: &mut [Body], i: usize, j: usize) {
    let (first, second) = get_pair_mut(bodies, i, j);
    if !first.alive || !second.alive {
        return;
    }

    let total_mass = first.mass + second.mass;
    if total_mass <= 0.0 {
        return;
    }

    let merged_position =
        (first.position * first.mass + second.position * second.mass) / total_mass;
    let merged_velocity =
        (first.velocity * first.mass + second.velocity * second.mass) / total_mass;
    let merged_radius = (first.radius * first.radius + second.radius * second.radius).sqrt();

    first.mass = total_mass;
    first.position = merged_position;
    first.velocity = merged_velocity;
    first.radius = merged_radius;

    second.alive = false;
}

fn apply_elastic_collision(
    bodies: &mut [Body],
    i: usize,
    j: usize,
    delta: Vec2,
    distance: f64,
    collision_distance: f64,
) {
    let (first, second) = get_pair_mut(bodies, i, j);
    if !first.alive || !second.alive {
        return;
    }

    let normal = if distance > 0.0 {
        delta / distance
    } else {
        Vec2::new(1.0, 0.0)
    };

    let relative_velocity = second.velocity - first.velocity;
    let vel_along_normal = relative_velocity.dot(normal);
    if vel_along_normal <= 0.0 {
        let restitution = 1.0;
        let inverse_mass_sum = (1.0 / first.mass) + (1.0 / second.mass);
        if inverse_mass_sum > 0.0 {
            let impulse_scalar = -((1.0 + restitution) * vel_along_normal) / inverse_mass_sum;
            let impulse = normal * impulse_scalar;
            first.velocity -= impulse / first.mass;
            second.velocity += impulse / second.mass;
        }
    }

    let overlap = (collision_distance - distance).max(0.0);
    if overlap > 0.0 {
        let correction = normal * (0.5 * overlap + 1e-9);
        first.position -= correction;
        second.position += correction;
    }
}

fn get_pair_mut<T>(slice: &mut [T], i: usize, j: usize) -> (&mut T, &mut T) {
    debug_assert!(i < j);
    let (left, right) = slice.split_at_mut(j);
    (&mut left[i], &mut right[0])
}
