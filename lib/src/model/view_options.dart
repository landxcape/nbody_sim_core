/// Camera behavior mode for view-layer consumers.
enum CameraMode { fit, free, followSelected }

/// Render quality profile.
enum RenderQuality { low, medium, high }

/// View/render option bundle.
class RenderOptions {
  /// Creates render options.
  const RenderOptions({
    this.showVelocityVectors = true,
    this.showTrails = true,
    this.showFieldOverlay = false,
    this.showLensingOverlay = false,
    this.quality = RenderQuality.medium,
  });

  /// Whether velocity vectors should be shown.
  final bool showVelocityVectors;

  /// Whether trails should be shown.
  final bool showTrails;

  /// Whether field overlay should be shown.
  final bool showFieldOverlay;

  /// Whether lensing overlay should be shown.
  final bool showLensingOverlay;

  /// Quality preset used for derived view parameters.
  final RenderQuality quality;

  /// Returns a copy with selected values replaced.
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

  /// Suggested trail length for this quality profile.
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

  /// Suggested glow alpha for this quality profile.
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

  /// Suggested field sample density for this quality profile.
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
