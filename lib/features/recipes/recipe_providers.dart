import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/recipe.dart';
import '../../core/models/studio_types.dart';
import '../../core/providers.dart';
import 'recipe_repository.dart';

class RecipeQueryController extends Notifier<RecipeQuery> {
  @override
  RecipeQuery build() => const RecipeQuery();

  void setSearch(String value) => state = _copy(search: value);

  void setKind(RecipeKind? kind) => state = _copy(kind: kind, clearKind: kind == null);

  void setAtmosphere(Atmosphere? atmosphere) {
    state = _copy(atmosphere: atmosphere, clearAtmosphere: atmosphere == null);
  }

  void setConeBand(ConeBand? coneBand) {
    state = _copy(coneBand: coneBand, clearConeBand: coneBand == null);
  }

  RecipeQuery _copy({
    String? search,
    RecipeKind? kind,
    bool clearKind = false,
    Atmosphere? atmosphere,
    bool clearAtmosphere = false,
    ConeBand? coneBand,
    bool clearConeBand = false,
  }) {
    return RecipeQuery(
      search: search ?? state.search,
      kind: clearKind ? null : kind ?? state.kind,
      atmosphere: clearAtmosphere ? null : atmosphere ?? state.atmosphere,
      coneBand: clearConeBand ? null : coneBand ?? state.coneBand,
    );
  }
}

final recipeQueryProvider =
    NotifierProvider<RecipeQueryController, RecipeQuery>(RecipeQueryController.new);

final filteredRecipesProvider = FutureProvider<List<Recipe>>((ref) async {
  ref.watch(revisionProvider);
  final query = ref.watch(recipeQueryProvider);
  return ref.watch(recipeRepositoryProvider).search(query);
});

final recipeProvider = FutureProvider.family<Recipe?, String>((ref, id) async {
  ref.watch(revisionProvider);
  return ref.watch(recipeRepositoryProvider).byId(id);
});
