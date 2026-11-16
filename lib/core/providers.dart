import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db/kiln_database.dart';
import 'models/sync_models.dart';
import 'network/kiln_api.dart';
import 'runtime.dart';
import 'sync/sync_service.dart';
import '../features/recipes/recipe_repository.dart';
import '../features/schedule/firing_repository.dart';

final databaseProvider = Provider<KilnDatabase>((ref) {
  throw StateError('KilnDatabase was not provided. main() overrides databaseProvider.');
});

final clockProvider = Provider<StudioClock>((ref) => StudioClock());

final idGenProvider = Provider<IdGen>((ref) => IdGen());

final changeBusProvider = Provider<ChangeBus>((ref) {
  final bus = ChangeBus();
  ref.onDispose(bus.dispose);
  return bus;
});

final kilnApiProvider = Provider<KilnApi>((ref) {
  return HttpKilnApi(
    baseUrl: const String.fromEnvironment('KILN_API', defaultValue: 'http://127.0.0.1:8787'),
  );
});

final recipeRepositoryProvider = Provider<RecipeRepository>((ref) {
  return RecipeRepository(
    db: ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
    ids: ref.watch(idGenProvider),
    bus: ref.watch(changeBusProvider),
  );
});

final firingRepositoryProvider = Provider<FiringRepository>((ref) {
  return FiringRepository(
    db: ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
    ids: ref.watch(idGenProvider),
    bus: ref.watch(changeBusProvider),
  );
});

final syncServiceProvider = Provider<SyncService>((ref) {
  return SyncService(
    db: ref.watch(databaseProvider),
    api: ref.watch(kilnApiProvider),
    bus: ref.watch(changeBusProvider),
  );
});

class RevisionNotifier extends Notifier<int> {
  @override
  int build() {
    final subscription = ref.watch(changeBusProvider).stream.listen((_) => state++);
    ref.onDispose(subscription.cancel);
    return 0;
  }
}

final revisionProvider = NotifierProvider<RevisionNotifier, int>(RevisionNotifier.new);

class SyncController extends AsyncNotifier<SyncSnapshot> {
  @override
  Future<SyncSnapshot> build() => _run(notify: false);

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _run(notify: true));
  }

  Future<SyncSnapshot> _run({required bool notify}) {
    return ref.read(syncServiceProvider).sync(forceNotify: notify);
  }
}

final syncControllerProvider =
    AsyncNotifierProvider<SyncController, SyncSnapshot>(SyncController.new);
