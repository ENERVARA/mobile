/// A single lat/long snapshot captured on-device and stored locally when the
/// app is granted location access.
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

/// Represents the backend's /location response payload.
class LocationBackendState {
  final double? latitude;
  final double? longitude;
  final String consent;
  final bool hasCoordinates;
  final bool shouldPrompt;
  final DateTime? consentAt;
  final DateTime? updatedAt;

  const LocationBackendState({
    required this.latitude,
    required this.longitude,
    required this.consent,
    required this.hasCoordinates,
    required this.shouldPrompt,
    required this.consentAt,
    required this.updatedAt,
  });

  factory LocationBackendState.fromJson(Map<String, dynamic> json) {
    final rawLat = json['latitude'];
    final rawLng = json['longitude'];
    final hasCoordinates = json['hasCoordinates'] as bool? ??
        (rawLat != null && rawLng != null);

    DateTime? parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value)?.toUtc();
      }
      return null;
    }

    return LocationBackendState(
      latitude: rawLat is num ? rawLat.toDouble() : null,
      longitude: rawLng is num ? rawLng.toDouble() : null,
      consent: (json['consent'] as String?) ?? 'denied',
      hasCoordinates: hasCoordinates,
      shouldPrompt: json['shouldPrompt'] as bool? ?? false,
      consentAt: parseDate(json['consentAt']),
      updatedAt: parseDate(json['updatedAt']),
    );
  }
}
