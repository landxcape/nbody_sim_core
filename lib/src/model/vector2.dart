import 'dart:math' as math;

class Vec2 {
  const Vec2(this.x, this.y);

  static const Vec2 zero = Vec2(0, 0);

  final double x;
  final double y;

  Vec2 operator +(Vec2 other) => Vec2(x + other.x, y + other.y);
  Vec2 operator -(Vec2 other) => Vec2(x - other.x, y - other.y);
  Vec2 operator *(double scalar) => Vec2(x * scalar, y * scalar);
  Vec2 operator /(double scalar) => Vec2(x / scalar, y / scalar);

  double dot(Vec2 other) => (x * other.x) + (y * other.y);

  double get normSquared => dot(this);
  double get norm => math.sqrt(normSquared);

  bool get isFinite => x.isFinite && y.isFinite;

  Vec2 normalizedOr(Vec2 fallback) {
    final length = norm;
    if (length > 0) {
      return this / length;
    }
    return fallback;
  }

  Map<String, dynamic> toJson() {
    return {'x': x, 'y': y};
  }

  factory Vec2.fromJson(Map<String, dynamic> json) {
    return Vec2((json['x'] as num).toDouble(), (json['y'] as num).toDouble());
  }
}
