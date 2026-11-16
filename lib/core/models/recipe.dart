import '../format.dart';
import '../runtime.dart';
import 'studio_types.dart';

class Ingredient {
  const Ingredient({
    required this.id,
    required this.name,
    required this.percentage,
    required this.role,
    required this.sortOrder,
  });

  final String id;
  final String name;
  final double percentage;
  final IngredientRole role;
  final int sortOrder;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'percentage': percentage,
        'role': role.name,
        'sortOrder': sortOrder,
      };

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      id: jsonText(json, 'id'),
      name: jsonText(json, 'name'),
      percentage: jsonDouble(json, 'percentage'),
      role: enumByName(IngredientRole.values, json['role'], 'role'),
      sortOrder: jsonInt(json, 'sortOrder'),
    );
  }

  Map<String, Object?> toRow(String recipeId) => {
        'id': id,
        'recipe_id': recipeId,
        'name': name,
        'percentage': percentage,
        'role': role.name,
        'sort_order': sortOrder,
      };

  factory Ingredient.fromRow(Map<String, Object?> row) {
    return Ingredient(
      id: row['id']! as String,
      name: row['name']! as String,
      percentage: (row['percentage']! as num).toDouble(),
      role: enumByName(IngredientRole.values, row['role'], 'role'),
      sortOrder: (row['sort_order']! as num).toInt(),
    );
  }
}

class Recipe {
  const Recipe({
    required this.id,
    required this.name,
    required this.kind,
    required this.coneMin,
    required this.coneMax,
    required this.atmosphere,
    required this.colorHex,
    required this.colorName,
    required this.surface,
    required this.description,
    required this.firingNotes,
    required this.author,
    required this.tested,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
    required this.deletedAt,
    required this.ingredients,
    this.pendingSync = false,
  });

  final String id;
  final String name;
  final RecipeKind kind;
  final String coneMin;
  final String coneMax;
  final Atmosphere atmosphere;
  final String colorHex;
  final String colorName;
  final Surface surface;
  final String description;
  final String firingNotes;
  final String author;
  final bool tested;
  final RecordSource source;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final List<Ingredient> ingredients;
  final bool pendingSync;

  Recipe copyWith({
    String? name,
    bool? tested,
    RecordSource? source,
    DateTime? updatedAt,
    Object? deletedAt = unset,
    List<Ingredient>? ingredients,
    bool? pendingSync,
  }) {
    return Recipe(
      id: id,
      name: name ?? this.name,
      kind: kind,
      coneMin: coneMin,
      coneMax: coneMax,
      atmosphere: atmosphere,
      colorHex: colorHex,
      colorName: colorName,
      surface: surface,
      description: description,
      firingNotes: firingNotes,
      author: author,
      tested: tested ?? this.tested,
      source: source ?? this.source,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: identical(deletedAt, unset) ? this.deletedAt : deletedAt as DateTime?,
      ingredients: ingredients ?? this.ingredients,
      pendingSync: pendingSync ?? this.pendingSync,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'coneMin': coneMin,
        'coneMax': coneMax,
        'atmosphere': atmosphere.name,
        'colorHex': colorHex,
        'colorName': colorName,
        'surface': surface.name,
        'description': description,
        'firingNotes': firingNotes,
        'author': author,
        'tested': tested,
        'source': source.name,
        'createdAt': isoMillis(createdAt),
        'updatedAt': isoMillis(updatedAt),
        'deletedAt': deletedAt == null ? null : isoMillis(deletedAt!),
        'ingredients': ingredients.map((item) => item.toJson()).toList(),
      };

  factory Recipe.fromJson(Map<String, dynamic> json) {
    final rawIngredients = json['ingredients'];
    if (rawIngredients is! List) throw const FormatException('Expected ingredients.');
    return Recipe(
      id: jsonText(json, 'id'),
      name: jsonText(json, 'name'),
      kind: enumByName(RecipeKind.values, json['kind'], 'kind'),
      coneMin: jsonText(json, 'coneMin'),
      coneMax: jsonText(json, 'coneMax'),
      atmosphere: enumByName(Atmosphere.values, json['atmosphere'], 'atmosphere'),
      colorHex: jsonText(json, 'colorHex'),
      colorName: jsonText(json, 'colorName'),
      surface: enumByName(Surface.values, json['surface'], 'surface'),
      description: jsonText(json, 'description', allowEmpty: true),
      firingNotes: jsonText(json, 'firingNotes', allowEmpty: true),
      author: jsonText(json, 'author'),
      tested: jsonBool(json, 'tested'),
      source: enumByName(RecordSource.values, json['source'], 'source'),
      createdAt: parseIso(jsonText(json, 'createdAt')),
      updatedAt: parseIso(jsonText(json, 'updatedAt')),
      deletedAt: json['deletedAt'] == null ? null : parseIso(jsonText(json, 'deletedAt')),
      ingredients: [
        for (final item in rawIngredients)
          Ingredient.fromJson((item as Map).cast<String, dynamic>()),
      ],
    );
  }

  Map<String, Object?> toRow() => {
        'id': id,
        'name': name,
        'kind': kind.name,
        'cone_min': coneMin,
        'cone_max': coneMax,
        'atmosphere': atmosphere.name,
        'color_hex': colorHex,
        'color_name': colorName,
        'surface': surface.name,
        'description': description,
        'firing_notes': firingNotes,
        'author': author,
        'tested': tested ? 1 : 0,
        'source': source.name,
        'created_at': isoMillis(createdAt),
        'updated_at': isoMillis(updatedAt),
        'deleted_at': deletedAt == null ? null : isoMillis(deletedAt!),
      };

  factory Recipe.fromParts({
    required Map<String, Object?> row,
    required List<Ingredient> ingredients,
    required bool pendingSync,
  }) {
    final deleted = row['deleted_at'] as String?;
    return Recipe(
      id: row['id']! as String,
      name: row['name']! as String,
      kind: enumByName(RecipeKind.values, row['kind'], 'kind'),
      coneMin: row['cone_min']! as String,
      coneMax: row['cone_max']! as String,
      atmosphere: enumByName(Atmosphere.values, row['atmosphere'], 'atmosphere'),
      colorHex: row['color_hex']! as String,
      colorName: row['color_name']! as String,
      surface: enumByName(Surface.values, row['surface'], 'surface'),
      description: row['description']! as String,
      firingNotes: row['firing_notes']! as String,
      author: row['author']! as String,
      tested: (row['tested']! as num) == 1,
      source: enumByName(RecordSource.values, row['source'], 'source'),
      createdAt: parseIso(row['created_at']! as String),
      updatedAt: parseIso(row['updated_at']! as String),
      deletedAt: deleted == null ? null : parseIso(deleted),
      ingredients: ingredients,
      pendingSync: pendingSync,
    );
  }
}

class RecipeDraft {
  const RecipeDraft({
    required this.name,
    required this.kind,
    required this.coneMin,
    required this.coneMax,
    required this.atmosphere,
    required this.colorHex,
    required this.colorName,
    required this.surface,
    required this.description,
    required this.firingNotes,
    required this.author,
    required this.tested,
    required this.ingredients,
  });

  final String name;
  final RecipeKind kind;
  final String coneMin;
  final String coneMax;
  final Atmosphere atmosphere;
  final String colorHex;
  final String colorName;
  final Surface surface;
  final String description;
  final String firingNotes;
  final String author;
  final bool tested;
  final List<Ingredient> ingredients;

  Recipe toRecipe({
    required String id,
    required DateTime createdAt,
    required DateTime updatedAt,
    required RecordSource source,
    DateTime? deletedAt,
  }) {
    return Recipe(
      id: id,
      name: name.trim(),
      kind: kind,
      coneMin: coneMin,
      coneMax: coneMax,
      atmosphere: atmosphere,
      colorHex: colorHex,
      colorName: colorName.trim(),
      surface: surface,
      description: description.trim(),
      firingNotes: firingNotes.trim(),
      author: author.trim(),
      tested: tested,
      source: source,
      createdAt: createdAt,
      updatedAt: updatedAt,
      deletedAt: deletedAt,
      ingredients: ingredients,
    );
  }
}

class RecipeInvalid implements Exception {
  RecipeInvalid(this.message);
  final String message;

  @override
  String toString() => message;
}
