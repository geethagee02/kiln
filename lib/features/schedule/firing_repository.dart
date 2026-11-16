import '../../core/db/kiln_database.dart';
import '../../core/format.dart';
import '../../core/models/firing.dart';
import '../../core/runtime.dart';

class FiringRepository {
  FiringRepository({
    required this.db,
    required this.clock,
    required this.ids,
    required this.bus,
  });

  final KilnDatabase db;
  final StudioClock clock;
  final IdGen ids;
  final ChangeBus bus;

  Future<List<Firing>> overlapping(DateTime start, DateTime end) async {
    final now = clock.now();
    final firings = await db.firingsOverlapping(start, end);
    return [for (final firing in firings) firing.presented(now)];
  }

  Future<Firing> create(FiringDraft draft) async {
    final error = validateFiringDraft(draft);
    if (error != null) throw FiringInvalid(error);
    final now = clock.now();
    final firing = draft.toFiring(id: ids.next(), createdAt: now, updatedAt: now);
    await db.saveFiring(firing, enqueue: true);
    bus.ping();
    return firing;
  }

  Future<List<Firing>> forWeek(DateTime day) {
    final monday = mondayOf(day);
    return overlapping(monday, monday.add(const Duration(days: 8)));
  }
}
