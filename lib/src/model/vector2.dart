import 'dart:math' as math;

/// Immutable 2D vector.
class Vec2 {
  /// Creates a vector from x/y components.
  const Vec2(this.x, this.y);

  /// Zero vector constant.
  static const Vec2 zero = Vec2(0, 0);

  /// X-axis component.
  final double x;

  /// Y-axis component.
  final double y;

  /// Vector addition.
  Vec2 operator +(Vec2 other) => Vec2(x + other.x, y + other.y);

  /// Vector subtraction.
  Vec2 operator -(Vec2 other) => Vec2(x - other.x, y - other.y);

  /// Scalar multiplication.
  Vec2 operator *(double scalar) => Vec2(x * scalar, y * scalar);

  /// Scalar division.
  Vec2 operator /(double scalar) => Vec2(x / scalar, y / scalar);

  /// Dot product.
  double dot(Vec2 other) => (x * other.x) + (y * other.y);

  /// Squared magnitude.
  double get normSquared => dot(this);

  /// Magnitude.
  double get norm => math.sqrt(normSquared);

  /// Whether both components are finite.
  bool get isFinite => x.isFinite && y.isFinite;

  /// Normalized vector, or [fallback] if magnitude is zero.
  Vec2 normalizedOr(Vec2 fallback) {
    final length = norm;
    if (length > 0) {
      return this / length;
    }
    return fallback;
  }

  /// Serializes this vector to JSON.
  Map<String, dynamic> toJson() {
    return {'x': x, 'y': y};
  }

  /// Deserializes a vector from JSON.
  factory Vec2.fromJson(Map<String, dynamic> json) {
    return Vec2((json['x'] as num).toDouble(), (json['y'] as num).toDouble());
  }
}
