import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Biberon ou tétée. amountMl == null => tétée (sein).
class FeedingEntry {
  final String id;
  final DateTime at;
  final int? amountMl; // multiples de 10 ml ; null si tétée
  final String? side; // 'G' | 'D' | null
  final bool vitaminD;
  final DateTime? nextAt; // prochain biberon/tétée prévu
  final bool synced;

  FeedingEntry({
    String? id,
    required this.at,
    this.amountMl,
    this.side,
    this.vitaminD = false,
    this.nextAt,
    this.synced = false,
  }) : id = id ?? _uuid.v4();

  Map<String, dynamic> toMap() => {
    'id': id,
    'at': at.millisecondsSinceEpoch,
    'amount_ml': amountMl,
    'side': side,
    'vitamin_d': vitaminD ? 1 : 0,
    'next_at': nextAt?.millisecondsSinceEpoch,
    'synced': synced ? 1 : 0,
  };

  factory FeedingEntry.fromMap(Map<String, dynamic> m) => FeedingEntry(
    id: m['id'] as String,
    at: DateTime.fromMillisecondsSinceEpoch(m['at'] as int),
    amountMl: m['amount_ml'] as int?,
    side: m['side'] as String?,
    vitaminD: (m['vitamin_d'] as int) == 1,
    nextAt: m['next_at'] != null
        ? DateTime.fromMillisecondsSinceEpoch(m['next_at'] as int)
        : null,
    synced: (m['synced'] as int) == 1,
  );

  /// Payload pour l'API REST (backend Spring Boot).
  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.toUtc().toIso8601String(),
    'amountMl': amountMl,
    'side': side,
    'vitaminD': vitaminD,
    'nextAt': nextAt?.toUtc().toIso8601String(),
  };
}

enum DiaperType { pipi, caca, mixte }

class DiaperEntry {
  final String id;
  final DateTime at;
  final DiaperType type;
  final bool synced;

  DiaperEntry({
    String? id,
    required this.at,
    required this.type,
    this.synced = false,
  }) : id = id ?? _uuid.v4();

  Map<String, dynamic> toMap() => {
    'id': id,
    'at': at.millisecondsSinceEpoch,
    'type': type.name,
    'synced': synced ? 1 : 0,
  };

  factory DiaperEntry.fromMap(Map<String, dynamic> m) => DiaperEntry(
    id: m['id'] as String,
    at: DateTime.fromMillisecondsSinceEpoch(m['at'] as int),
    type: DiaperType.values.byName(m['type'] as String),
    synced: (m['synced'] as int) == 1,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.toUtc().toIso8601String(),
    'type': type.name,
  };
}

class SleepEntry {
  final String id;
  final DateTime start;
  final DateTime? end; // null => sommeil en cours
  final bool synced;

  SleepEntry({
    String? id,
    required this.start,
    this.end,
    this.synced = false,
  }) : id = id ?? _uuid.v4();

  Duration? get duration => end?.difference(start);

  SleepEntry copyWith({DateTime? end, bool? synced}) => SleepEntry(
    id: id,
    start: start,
    end: end ?? this.end,
    synced: synced ?? this.synced,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'start': start.millisecondsSinceEpoch,
    'end': end?.millisecondsSinceEpoch,
    'synced': synced ? 1 : 0,
  };

  factory SleepEntry.fromMap(Map<String, dynamic> m) => SleepEntry(
    id: m['id'] as String,
    start: DateTime.fromMillisecondsSinceEpoch(m['start'] as int),
    end: m['end'] != null
        ? DateTime.fromMillisecondsSinceEpoch(m['end'] as int)
        : null,
    synced: (m['synced'] as int) == 1,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'start': start.toUtc().toIso8601String(),
    'end': end?.toUtc().toIso8601String(),
  };
}

/// Bain complet ou simple rinçage, avec notes libres des parents.
enum BathType { bain, rincage }

class BathEntry {
  final String id;
  final DateTime at;
  final BathType type;
  final String? notes;
  final bool synced;

  BathEntry({
    String? id,
    required this.at,
    required this.type,
    this.notes,
    this.synced = false,
  }) : id = id ?? _uuid.v4();

  Map<String, dynamic> toMap() => {
    'id': id,
    'at': at.millisecondsSinceEpoch,
    'type': type.name,
    'notes': notes,
    'synced': synced ? 1 : 0,
  };

  factory BathEntry.fromMap(Map<String, dynamic> m) => BathEntry(
    id: m['id'] as String,
    at: DateTime.fromMillisecondsSinceEpoch(m['at'] as int),
    type: BathType.values.byName(m['type'] as String),
    notes: m['notes'] as String?,
    synced: (m['synced'] as int) == 1,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.toUtc().toIso8601String(),
    'type': type.name,
    'notes': notes,
  };
}