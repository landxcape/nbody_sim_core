import 'vector2.dart';

class SimulationBody {
  const SimulationBody({
    required this.id,
    required this.mass,
    required this.radius,
    required this.position,
    required this.velocity,
    required this.colorValue,
    this.label,
    this.kind,
    this.alive = true,
  });

  final String id;
  final String? label;
  final String? kind;
  final double mass;
  final double radius;
  final Vec2 position;
  final Vec2 velocity;
  final int colorValue;
  final bool alive;

  SimulationBody copyWith({
    String? id,
    String? label,
    String? kind,
    double? mass,
    double? radius,
    Vec2? position,
    Vec2? velocity,
    int? colorValue,
    bool? alive,
  }) {
    return SimulationBody(
      id: id ?? this.id,
      label: label ?? this.label,
      kind: kind ?? this.kind,
      mass: mass ?? this.mass,
      radius: radius ?? this.radius,
      position: position ?? this.position,
      velocity: velocity ?? this.velocity,
      colorValue: colorValue ?? this.colorValue,
      alive: alive ?? this.alive,
    );
  }

  String? validate() {
    if (id.trim().isEmpty) {
      return 'body id must not be empty';
    }
    if (!mass.isFinite || mass <= 0) {
      return 'body $id mass must be finite and > 0';
    }
    if (!radius.isFinite || radius <= 0) {
      return 'body $id radius must be finite and > 0';
    }
    if (!position.isFinite) {
      return 'body $id position must be finite';
    }
    if (!velocity.isFinite) {
      return 'body $id velocity must be finite';
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    final metadata = <String, dynamic>{};
    if (label != null && label!.isNotEmpty) {
      metadata['label'] = label;
    }
    if (kind != null && kind!.isNotEmpty) {
      metadata['kind'] = kind;
    }
    metadata['color'] = _toHexColor(colorValue);

    return {
      'id': id,
      'mass': mass,
      'radius': radius,
      'position': position.toJson(),
      'velocity': velocity.toJson(),
      'alive': alive,
      'metadata': metadata,
    };
  }

  factory SimulationBody.fromJson(Map<String, dynamic> json) {
    final metadata = (json['metadata'] as Map?)?.cast<String, dynamic>();
    final label = metadata?['label'] as String?;
    final kind = metadata?['kind'] as String?;
    final colorString = metadata?['color'] as String?;
    final colorValue = _parseColorValue(colorString) ?? 0xFFFFFFFF;

    return SimulationBody(
      id: json['id'] as String,
      mass: (json['mass'] as num).toDouble(),
      radius: (json['radius'] as num).toDouble(),
      position: Vec2.fromJson(
        (json['position'] as Map).cast<String, dynamic>(),
      ),
      velocity: Vec2.fromJson(
        (json['velocity'] as Map).cast<String, dynamic>(),
      ),
      colorValue: colorValue,
      label: label,
      kind: kind,
      alive: json['alive'] as bool? ?? true,
    );
  }

  static String _toHexColor(int value) {
    return '#${value.toRadixString(16).padLeft(8, '0')}';
  }

  static int? _parseColorValue(String? value) {
    if (value == null || value.isEmpty) {
      return null;
    }
    final normalized = value.startsWith('#') ? value.substring(1) : value;
    return int.tryParse(normalized, radix: 16);
  }
}
