import 'dart:math' as math;

import '../format.dart';
import '../runtime.dart';
import 'studio_types.dart';

class Firing {
  const Firing({
    required this.id,
    required this.title,
    required this.kiln,
    required this.startsAt,
    required this.endsAt,
    required this.cone,
    required this.atmosphere,
    required this.status,
    required this.lead,
    required this.notes,
    required this.capacity,
    required this.booked,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
    this.pendingSync = false,
  });

  final String id;
  final String title;
  final String kiln;
  final DateTime startsAt;
  final DateTime endsAt;
  final String cone;
  final Atmosphere atmosphere;
  final FiringStatus status;
  final String lead;
  final String notes;
  final int capacity;
  final int booked;
  final RecordSource source;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final bool pendingSync;

  bool overlapsDay(DateTime day) {
    final start = dateOnly(day);
    final end = start.add(const Duration(days: 1));
    return startsAt.toLocal().isBefore(end) && endsAt.toLocal().isAfter(start);
  }

  Firing copyWith({
    FiringStatus? status,
    RecordSource? source,
    DateTime? updatedAt,
    Object? deletedAt = unset,
    bool? pendingSync,
  }) {
    return Firing(
      id: id,
      title: title,
      kiln: kiln,
      startsAt: startsAt,
      endsAt: endsAt,
      cone: cone,
      atmosphere: atmosphere,
      status: status ?? this.status,
      lead: lead,
      notes: notes,
      capacity: capacity,
      booked: booked,
      source: source ?? this.source,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: identical(deletedAt, unset) ? this.deletedAt : deletedAt as DateTime?,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }

  /// Seed rows keep a fixed [updatedAt] so a sync does not fight the clock.
  /// Their status is derived when the board is read. A member's edit sticks.
  Firing presented(DateTime now) {
    if (source != RecordSource.seed || deletedAt != null) return this;
    return copyWith(status: statusForWindow(start: startsAt, end: endsAt, now: now));
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'title': title,
        'kiln': kiln,
        'startsAt': isoMillis(startsAt),
        'endsAt': isoMillis(endsAt),
        'cone': cone,
        'atmosphere': atmosphere.name,
        'status': status.name,
        'lead': lead,
        'notes': notes,
        'capacity': capacity,
        'booked': booked,
        'source': source.name,
        'createdAt': isoMillis(createdAt),
        'updatedAt': isoMillis(updatedAt),
        'deletedAt': deletedAt == null ? null : isoMillis(deletedAt!),
      };

  factory Firing.fromJson(Map<String, dynamic> json) {
    final deleted = json['deletedAt'];
    return Firing(
      id: jsonText(json, 'id'),
      title: jsonText(json, 'title'),
      kiln: jsonText(json, 'kiln'),
      startsAt: parseIso(jsonText(json, 'startsAt')),
      endsAt: parseIso(jsonText(json, 'endsAt')),
      cone: jsonText(json, 'cone'),
      atmosphere: enumByName(Atmosphere.values, json['atmosphere'], 'atmosphere'),
      status: enumByName(FiringStatus.values, json['status'], 'status'),
      lead: jsonText(json, 'lead'),
      notes: jsonText(json, 'notes', allowEmpty: true),
      capacity: jsonInt(json, 'capacity'),
      booked: jsonInt(json, 'booked'),
      source: enumByName(RecordSource.values, json['source'], 'source'),
      createdAt: parseIso(jsonText(json, 'createdAt')),
      updatedAt: parseIso(jsonText(json, 'updatedAt')),
      deletedAt: deleted == null ? null : parseIso(deleted as String),
    );
  }

  Map<String, Object?> toRow() => {
        'id': id,
        'title': title,
        'kiln': kiln,
        'starts_at': isoMillis(startsAt),
        'ends_at': isoMillis(endsAt),
        'cone': cone,
        'atmosphere': atmosphere.name,
        'status': status.name,
        'lead': lead,
        'notes': notes,
        'capacity': capacity,
        'booked': booked,
        'source': source.name,
        'created_at': isoMillis(createdAt),
        'updated_at': isoMillis(updatedAt),
        'deleted_at': deletedAt == null ? null : isoMillis(deletedAt!),
      };

  factory Firing.fromRow(Map<String, Object?> row, {required bool pendingSync}) {
    final deleted = row['deleted_at'] as String?;
    return Firing(
      id: row['id']! as String,
      title: row['title']! as String,
      kiln: row['kiln']! as String,
      startsAt: parseIso(row['starts_at']! as String),
      endsAt: parseIso(row['ends_at']! as String),
      cone: row['cone']! as String,
      atmosphere: enumByName(Atmosphere.values, row['atmosphere'], 'atmosphere'),
      status: enumByName(FiringStatus.values, row['status'], 'status'),
      lead: row['lead']! as String,
      notes: row['notes']! as String,
      capacity: (row['capacity']! as num).toInt(),
      booked: (row['booked']! as num).toInt(),
      source: enumByName(RecordSource.values, row['source'], 'source'),
      createdAt: parseIso(row['created_at']! as String),
      updatedAt: parseIso(row['updated_at']! as String),
      deletedAt: deleted == null ? null : parseIso(deleted),
      pendingSync: pendingSync,
    );
  }
}

class FiringDraft {
  const FiringDraft({
    required this.title,
    required this.kiln,
    required this.startsAt,
    required this.endsAt,
    required this.cone,
    required this.atmosphere,
    required this.lead,
    required this.notes,
    required this.capacity,
    required this.booked,
  });

  final String title;
  final String kiln;
  final DateTime startsAt;
  final DateTime endsAt;
  final String cone;
  final Atmosphere atmosphere;
  final String lead;
  final String notes;
  final int capacity;
  final int booked;

  Firing toFiring({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
  }) {
    return Firing(
      id: id,
      title: title.trim(),
      kiln: kiln,
      startsAt: startsAt,
      endsAt: endsAt,
      cone: cone,
      atmosphere: atmosphere,
      status: FiringStatus.scheduled,
      lead: lead.trim(),
      notes: notes.trim(),
      capacity: capacity,
      booked: booked,
      source: RecordSource.member,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: null,
    );
  }
}

class FiringInvalid implements Exception {
  FiringInvalid(this.message);
  final String message;

  @override
  String toString() => message;
}

String? validateFiringDraft(FiringDraft draft) {
  if (draft.title.trim().isEmpty) return 'Name the firing.';
  if (draft.kiln.trim().isEmpty) return 'Choose a kiln.';
  if (draft.lead.trim().isEmpty) return 'Who is leading this firing?';
  if (!draft.endsAt.isAfter(draft.startsAt)) return 'The firing has to end after it starts.';
  if (!coneLabels.contains(draft.cone)) return 'Choose a cone.';
  if (draft.capacity < 1 || draft.capacity > 500) return 'Capacity has to be at least one shelf.';
  if (draft.booked < 0 || draft.booked > draft.capacity) {
    return 'Booked shelves have to fit in the kiln.';
  }
  return null;
}

/// Mirrors server/validate.js `statusForWindow`. Seed rows use this so the
/// board tracks the clock without rewriting `updatedAt`.
FiringStatus statusForWindow({
  required DateTime start,
  required DateTime end,
  required DateTime now,
}) {
  if (!now.isBefore(end)) return FiringStatus.unloaded;
  if (!now.isBefore(start)) {
    final elapsed = now.difference(start);
    if (elapsed <= const Duration(minutes: 90)) return FiringStatus.loading;
    final totalMinutes = end.difference(start).inMinutes;
    final coolingMinutes = math.max(60, (totalMinutes * 0.2).round());
    if (end.difference(now) <= Duration(minutes: coolingMinutes)) {
      return FiringStatus.cooling;
    }
    return FiringStatus.firing;
  }
  if (start.difference(now) <= const Duration(hours: 6)) return FiringStatus.loading;
  return FiringStatus.scheduled;
}
