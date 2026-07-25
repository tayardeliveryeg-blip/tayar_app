/// Shared thresholds for the profile-photo face check, used by both the
/// mobile (ML Kit) and web (face-api.js) implementations. Tune here.
class PhotoCheckThresholds {
  PhotoCheckThresholds._();

  /// Minimum ratio of (face width / image width) to count as "close-up".
  static const double minFaceWidthRatio = 0.35;

  /// Maximum allowed offset of the face center from the image center,
  /// as a ratio of image width/height.
  static const double maxCenterOffsetRatio = 0.22;

  // ---- Mobile (ML Kit) ----
  // ML Kit gives real 3D head-pose angles in degrees.
  static const double maxYawDegrees = 20;
  static const double maxRollDegrees = 20;

  // ---- Web (face-api.js landmarks) ----
  // face-api.js's 68-point landmark model has no true 3D head-pose output,
  // so yaw is approximated from left/right eye-to-nose distance asymmetry
  // (0 = perfectly symmetric/forward, higher = turned more to one side).
  static const double maxYawAsymmetryRatio = 0.18;

  // Roll (head tilt) IS a real degree measurement on web too — computed
  // from the angle of the eye-to-eye line — so it reuses maxRollDegrees.

  /// Eye-aspect-ratio (EAR) below which an eye is considered closed.
  /// Only used by the web check (mobile uses ML Kit's own probability).
  static const double minEyeAspectRatio = 0.16;
}
