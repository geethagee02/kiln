import '../../core/db/kiln_database.dart';
import '../../core/models/recipe.dart';
import '../../core/models/studio_types.dart';
import '../../core/runtime.dart';
import 'batch_math.dart';

class RecipeQuery {
  const RecipeQuery({
    this.search = '',
    this.kind,
    this.atmosphere,
    this.coneBand,
  });

  final String search;
  final RecipeKind? kind;
  final Atmosphere? atmosphere;
  final ConeBand? coneBand;

  bool matches(Recipe recipe) {
    if (kind != null && recipe.kind != kind) return false;
    if (atmosphere != null && recipe.atmosphere != atmosphere) return false;
    if (coneBand != null && !coneBand!.overlaps(recipe.coneMin, recipe.coneMax)) {
      return false;
    }
    final needle = search.trim().toLowerCase();
    if (needle.isEmpty) return true;
    final haystack = [
      recipe.name,
      recipe.author,
      recipe.description,
      recipe.colorName,
      recipe.kind.label,
      recipe.atmosphere.label,
      for (final ingredient in recipe.ingredients) ingredient.name,
    ].join(' ').toLowerCase();
    return haystack.contains(needle);
  }
}

class RecipeRepository {
  RecipeRepository({
    required this.db,
    required this.clock,
    required this.ids,
    required this.bus,
  });

  final KilnDatabase db;
  final StudioClock clock;
  final IdGen ids;
  final ChangeBus bus;

  Future<List<Recipe>> search(RecipeQuery query) async {
    final recipes = await db.listRecipes();
    return recipes.where(query.matches).toList();
  }

  Future<Recipe?> byId(String id) => db.recipeById(id);

  Future<Recipe> create(RecipeDraft draft) async {
    final error = BatchMath.validateDraft(draft);
    if (error != null) throw RecipeInvalid(error);
    final now = clock.now();
    final recipe = _withIngredientIds(
      draft.toRecipe(
        id: ids.next(),
        createdAt: now,
        updatedAt: now,
        source: RecordSource.member,
      ),
    );
    await db.saveRecipe(recipe, enqueue: true);
    bus.ping();
    return recipe;
  }

  Future<Recipe> update(String id, RecipeDraft draft) async {
    final error = BatchMath.validateDraft(draft);
    if (error != null) throw RecipeInvalid(error);
    final existing = await db.recipeById(id, includeDeleted: true);
    if (existing == null || existing.deletedAt != null) {
      throw RecipeInvalid('That recipe is no longer on this phone.');
    }
    final recipe = draft.toRecipe(
      id: id,
      createdAt: existing.createdAt,
      updatedAt: clock.now(),
      source: RecordSource.member,
    );
    final stored = _withIngredientIds(recipe);
    await db.saveRecipe(stored, enqueue: true);
    bus.ping();
    return stored;
  }

  Future<void> delete(String id) async {
    final existing = await db.recipeById(id);
    if (existing == null) return;
    final now = clock.now();
    final deleted = existing.copyWith(
      updatedAt: now,
      deletedAt: now,
      source: RecordSource.member,
      pendingSync: true,
    );
    await db.saveRecipe(deleted, enqueue: true);
    bus.ping();
  }

  Recipe _withIngredientIds(Recipe recipe) {
    return recipe.copyWith(
      ingredients: [
        for (var index = 0; index < recipe.ingredients.length; index++)
          Ingredient(
            id: ids.next(),
            name: recipe.ingredients[index].name.trim(),
            percentage: recipe.ingredients[index].percentage,
            role: recipe.ingredients[index].role,
            sortOrder: index,
          ),
      ],
    );
  }
}
