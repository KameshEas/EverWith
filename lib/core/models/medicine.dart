import 'dart:convert';

/// How frequently a medicine should be taken.
enum MedicineFrequency {
  everyDay,
  twiceADay,
  onlyAsNeeded,
}

extension MedicineFrequencyLabel on MedicineFrequency {
  String get label {
    switch (this) {
      case MedicineFrequency.everyDay:
        return 'Every Day';
      case MedicineFrequency.twiceADay:
        return 'Twice a Day';
      case MedicineFrequency.onlyAsNeeded:
        return 'Only as Needed';
    }
  }
}

/// Status computed at runtime based on the scheduled time and today's taken log.
enum MedicineStatus { taken, upcoming, laterToday, asNeeded }

/// A single medicine entry stored by the user.
class Medicine {
  Medicine({
    required this.id,
    required this.name,
    required this.dosage,
    required this.timeHour,
    required this.timeMinute,
    required this.frequency,
    this.takenDates = const [],
  });

  final String id;
  final String name;
  final String dosage;

  /// Hour of day (0–23) for the first (or only) dose.
  final int timeHour;
  final int timeMinute;

  final MedicineFrequency frequency;

  /// ISO-8601 date strings (yyyy-MM-dd) on which the user marked this taken.
  final List<String> takenDates;

  // ── Derived ──────────────────────────────────────────────────────────────

  String get timeLabel {
    final h = timeHour % 12 == 0 ? 12 : timeHour % 12;
    final m = timeMinute.toString().padLeft(2, '0');
    final ampm = timeHour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }

  MedicineStatus get status {
    if (frequency == MedicineFrequency.onlyAsNeeded) {
      return MedicineStatus.asNeeded;
    }
    final today = _todayKey();
    if (takenDates.contains(today)) return MedicineStatus.taken;

    final now = DateTime.now();
    final scheduled = DateTime(now.year, now.month, now.day, timeHour, timeMinute);
    final diff = scheduled.difference(now).inMinutes;

    if (diff < 0) return MedicineStatus.upcoming; // past but not taken yet
    if (diff <= 60) return MedicineStatus.upcoming; // within the hour
    return MedicineStatus.laterToday;
  }

  static String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Medicine copyWith({
    String? name,
    String? dosage,
    int? timeHour,
    int? timeMinute,
    MedicineFrequency? frequency,
    List<String>? takenDates,
  }) {
    return Medicine(
      id: id,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      timeHour: timeHour ?? this.timeHour,
      timeMinute: timeMinute ?? this.timeMinute,
      frequency: frequency ?? this.frequency,
      takenDates: takenDates ?? this.takenDates,
    );
  }

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'dosage': dosage,
        'timeHour': timeHour,
        'timeMinute': timeMinute,
        'frequency': frequency.index,
        'takenDates': takenDates,
      };

  factory Medicine.fromJson(Map<String, dynamic> json) => Medicine(
        id: json['id'] as String,
        name: json['name'] as String,
        dosage: json['dosage'] as String,
        timeHour: json['timeHour'] as int,
        timeMinute: json['timeMinute'] as int,
        frequency: MedicineFrequency.values[json['frequency'] as int],
        takenDates: List<String>.from(json['takenDates'] as List),
      );

  static List<Medicine> listFromJson(String raw) {
    final list = jsonDecode(raw) as List;
    return list.map((e) => Medicine.fromJson(e as Map<String, dynamic>)).toList();
  }

  static String listToJson(List<Medicine> medicines) =>
      jsonEncode(medicines.map((m) => m.toJson()).toList());
}
