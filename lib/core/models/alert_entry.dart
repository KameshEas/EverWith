/// The type of alert logged for the caregiver.
enum AlertEntryType { missedMedicine, emergency }

/// A single alert entry stored in Firestore at
/// `/users/{elderUid}/alerts/{id}`.
class AlertEntry {
  const AlertEntry({
    required this.id,
    required this.type,
    required this.message,
    required this.timestamp,
    this.medicineName,
    this.acknowledged = false,
  });

  final String id;
  final AlertEntryType type;
  final String? medicineName;
  final String message;
  final DateTime timestamp;
  final bool acknowledged;

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'medicineName': medicineName,
        'message': message,
        'timestamp': timestamp.toIso8601String(),
        'acknowledged': acknowledged,
      };

  factory AlertEntry.fromJson(Map<String, dynamic> json) => AlertEntry(
        id: json['id'] as String,
        type: AlertEntryType.values.firstWhere(
          (t) => t.name == json['type'],
          orElse: () => AlertEntryType.missedMedicine,
        ),
        medicineName: json['medicineName'] as String?,
        message: json['message'] as String? ?? '',
        timestamp: DateTime.parse(json['timestamp'] as String),
        acknowledged: json['acknowledged'] as bool? ?? false,
      );
}
