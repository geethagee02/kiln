import 'package:kiln/core/models/firing.dart';
import 'package:kiln/core/models/recipe.dart';
import 'package:kiln/core/models/sync_models.dart';
import 'package:kiln/core/network/kiln_api.dart';

class FakeKilnApi implements KilnApi {
  FakeKilnApi({this.online = true});

  bool online;
  final List<Recipe> remoteRecipes = [];
  final List<Firing> remoteFirings = [];
  int pushes = 0;

  @override
  Future<bool> ping() async => online;

  @override
  Future<SyncResponse> pushAndPull({
    required String? since,
    required List<Recipe> recipes,
    required List<Firing> firings,
  }) async {
    if (!online) throw ApiException('offline');
    pushes += 1;
    final recipeConflicts = <Recipe>[];
    var applied = 0;
    for (final recipe in recipes) {
      final index = remoteRecipes.indexWhere((item) => item.id == recipe.id);
      if (index >= 0 && remoteRecipes[index].updatedAt.isAfter(recipe.updatedAt)) {
        recipeConflicts.add(remoteRecipes[index]);
        continue;
      }
      if (index >= 0) {
        remoteRecipes[index] = recipe;
      } else {
        remoteRecipes.add(recipe);
      }
      applied += 1;
    }
    for (final firing in firings) {
      final index = remoteFirings.indexWhere((item) => item.id == firing.id);
      if (index >= 0 && remoteFirings[index].updatedAt.isAfter(firing.updatedAt)) {
        continue;
      }
      if (index >= 0) {
        remoteFirings[index] = firing;
      } else {
        remoteFirings.add(firing);
      }
      applied += 1;
    }
    return SyncResponse(
      serverTime: DateTime.utc(2026, 11, 16, 18),
      applied: applied,
      recipeConflicts: recipeConflicts,
      firingConflicts: const [],
      recipes: [
        for (final recipe in remoteRecipes)
          if (since != null || recipe.deletedAt == null) recipe,
      ],
      firings: remoteFirings,
    );
  }
}
