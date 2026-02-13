enum CameraMode { fit, free, followSelected }

enum RenderQuality { low, medium, high }

class RenderOptions {
  const RenderOptions({
    this.showVelocityVectors = true,
    this.showTrails = true,
    this.showFieldOverlay = false,
    this.showLensingOverlay = false,
    this.quality = RenderQuality.medium,
  });

  final bool showVelocityVectors;
  final bool showTrails;
  final bool showFieldOverlay;
  final bool showLensingOverlay;
  final RenderQuality quality;

  RenderOptions copyWith({
    bool? showVelocityVectors,
    bool? showTrails,
    bool? showFieldOverlay,
    bool? showLensingOverlay,
    RenderQuality? quality,
  }) {
    return RenderOptions(
      showVelocityVectors: showVelocityVectors ?? this.showVelocityVectors,
      showTrails: showTrails ?? this.showTrails,
      showFieldOverlay: showFieldOverlay ?? this.showFieldOverlay,
      showLensingOverlay: showLensingOverlay ?? this.showLensingOverlay,
      quality: quality ?? this.quality,
    );
  }

  int get trailLength {
    switch (quality) {
      case RenderQuality.low:
        return 40;
      case RenderQuality.medium:
        return 90;
      case RenderQuality.high:
        return 160;
    }
  }

  double get glowAlpha {
    switch (quality) {
      case RenderQuality.low:
        return 0.14;
      case RenderQuality.medium:
        return 0.22;
      case RenderQuality.high:
        return 0.30;
    }
  }

  int get fieldSamples {
    switch (quality) {
      case RenderQuality.low:
        return 6;
      case RenderQuality.medium:
        return 12;
      case RenderQuality.high:
        return 18;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is RenderOptions &&
        other.showVelocityVectors == showVelocityVectors &&
        other.showTrails == showTrails &&
        other.showFieldOverlay == showFieldOverlay &&
        other.showLensingOverlay == showLensingOverlay &&
        other.quality == quality;
  }

  @override
  int get hashCode {
    return Object.hash(
      showVelocityVectors,
      showTrails,
      showFieldOverlay,
      showLensingOverlay,
      quality,
    );
  }
}
