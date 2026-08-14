/// A single lat/long snapshot captured on-device. This is the local "field"
/// the daily background task writes into — not yet sent anywhere. Once the
/// backend grows a location field/endpoint, [LocationService.captureAndPersist]
/// is the one place that needs a `dio.patch(...)` call added.
class UserLocationSnapshot {
  final double latitude;
  final double longitude;
  final DateTime capturedAt;

  const UserLocationSnapshot({
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
  });

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'capturedAt': capturedAt.toIso8601String(),
      };
}
