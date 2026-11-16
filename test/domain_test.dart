import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiln/core/db/kiln_database.dart';
import 'package:kiln/core/models/recipe.dart';
import 'package:kiln/core/models/studio_types.dart';
import 'package:kiln/core/models/sync_models.dart';
import 'package:kiln/core/runtime.dart';
import 'package:kiln/core/seed/studio_seed.dart';
import 'package:kiln/core/sync/sync_service.dart';
import 'package:kiln/features/recipes/batch_math.dart';
import 'package:kiln/features/recipes/recipe_repository.dart';

import 'support/fake_kiln_api.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Ingredient material(String name, double percentage, [IngredientRole role = IngredientRole.base]) {
    return Ingredient(id: name, name: name, percentage: percentage, role: role, sortOrder: 0);
  }

  test('base materials must total 100 and additions sit outside the batch', () {
    expect(
      BatchMath.validate([material('Silica', 80)]),
      contains('100%'),
    );
    expect(
      BatchMath.validate([
        material('Feldspar', 60),
        material('Silica', 40),
        material('Copper carbonate', 3, IngredientRole.colorant),
      ]),
      isNull,
    );
    expect(BatchMath.extraTotal([material('Copper carbonate', 3, IngredientRole.colorant)]), 3);
  });

  test('Monday 16 Nov 2026 seeds the bisque as loading', () {
    final raw = File('assets/seed/studio.json').readAsStringSync();
    final now = DateTime(2026, 11, 16, 9);
    final studio = expandStudio(raw, now);
    final bisque = studio.firings.firstWhere((firing) => firing.id.endsWith('skutt-bisque'));
    expect(isoWeekKey(now), '2026-W47');
    expect(bisque.id, 'firing-2026-W47-skutt-bisque');
    expect(bisque.status, FiringStatus.loading);
    expect(bisque.startsAt.toLocal(), DateTime(2026, 11, 16, 8));
    for (final recipe in studio.recipes) {
      expect(BatchMath.baseTotal(recipe.ingredients), 100, reason: recipe.name);
    }
  });

  test('a recipe written offline is readable before any network call', () async {
    final db = await KilnDatabase.openMemory();
    final bus = ChangeBus();
    final repository = RecipeRepository(
      db: db,
      clock: StudioClock(() => DateTime.utc(2026, 11, 16, 12)),
      ids: _ids(),
      bus: bus,
    );
    await repository.create(_draft('Local Celadon'));
    final listed = await repository.search(const RecipeQuery());
    expect(listed.map((recipe) => recipe.name), contains('Local Celadon'));
    expect(listed.singleWhere((recipe) => recipe.name == 'Local Celadon').pendingSync, isTrue);
    expect(await db.pendingCount(), 1);
    await db.close();
  });

  test('sync pushes the outbox and a stale write loses to the server', () async {
    final db = await KilnDatabase.openMemory();
    final bus = ChangeBus();
    final api = FakeKilnApi();
    final repository = RecipeRepository(
      db: db,
      clock: StudioClock(() => DateTime.utc(2026, 11, 16, 12)),
      ids: _ids(),
      bus: bus,
    );
    final sync = SyncService(db: db, api: api, bus: bus);
    await repository.create(_draft('Local Celadon'));
    api.online = false;
    final offline = await sync.sync();
    expect(offline.phase, SyncPhase.offline);
    expect(offline.pending, 1);
    expect(api.pushes, 0);

    api.online = true;
    final local = (await repository.search(const RecipeQuery())).single;
    api.remoteRecipes.add(
      local.copyWith(
        name: 'Server Tenmoku',
        updatedAt: DateTime.utc(2026, 11, 16, 13),
      ),
    );
    final synced = await sync.sync();
    expect(synced.phase, SyncPhase.ready);
    expect(synced.pending, 0);
    final after = await repository.byId(local.id);
    expect(after?.name, 'Server Tenmoku');
    await db.close();
  });
}

IdGen _ids() {
  var n = 0;
  return IdGen(() => 'id-${n++}');
}

RecipeDraft _draft(String name) {
  return RecipeDraft(
    name: name,
    kind: RecipeKind.glaze,
    coneMin: '9',
    coneMax: '10',
    atmosphere: Atmosphere.reduction,
    colorHex: '#6E9A84',
    colorName: 'soft celadon',
    surface: Surface.glossy,
    description: 'A test batch.',
    firingNotes: 'Cone 10.',
    author: 'Mara Chen',
    tested: true,
    ingredients: const [
      Ingredient(
        id: '',
        name: 'Feldspar',
        percentage: 60,
        role: IngredientRole.base,
        sortOrder: 0,
      ),
      Ingredient(
        id: '',
        name: 'Silica',
        percentage: 40,
        role: IngredientRole.base,
        sortOrder: 1,
      ),
    ],
  );
}
