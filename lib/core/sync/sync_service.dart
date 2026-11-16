import '../db/kiln_database.dart';
import '../models/sync_models.dart';
import '../network/kiln_api.dart';
import '../runtime.dart';

class SyncService {
  SyncService({required this.db, required this.api, required this.bus});

  final KilnDatabase db;
  final KilnApi api;
  final ChangeBus bus;

  /// Push the outbox, then pull the server delta. Screens never call [api]
  /// themselves; they read SQLite and ask this service to catch up.
  Future<SyncSnapshot> sync({bool forceNotify = false}) async {
    final pending = await db.pendingCount();
    if (!await api.ping()) {
      if (forceNotify) bus.ping();
      return SyncSnapshot(phase: SyncPhase.offline, pending: pending);
    }
    try {
      final cursor = await db.meta('sync_cursor');
      final payloads = await db.outboxPayloads();
      final response = await api.pushAndPull(
        since: cursor,
        recipes: payloads.recipes,
        firings: payloads.firings,
      );
      await db.applySync(
        sentRecipeIds: payloads.recipes.map((recipe) => recipe.id).toSet(),
        sentFiringIds: payloads.firings.map((firing) => firing.id).toSet(),
        response: response,
      );
      bus.ping();
      return SyncSnapshot(phase: SyncPhase.ready, pending: await db.pendingCount());
    } on ApiException catch (error) {
      if (forceNotify) bus.ping();
      return SyncSnapshot(
        phase: SyncPhase.error,
        pending: await db.pendingCount(),
        message: error.message,
      );
    }
  }
}
