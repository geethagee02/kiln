import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../format.dart';
import '../models/firing.dart';
import '../models/recipe.dart';
import '../models/sync_models.dart';

void configureDatabaseFactory() {
  if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = _factory;
  }
}

/// The ffi isolate deadlocks Flutter's test binding on the next [WidgetTester.pump].
/// Widget tests set `FLUTTER_TEST` and use the same-isolate factory.
DatabaseFactory get _factory {
  sqfliteFfiInit();
  final testing = Platform.environment['FLUTTER_TEST'] == 'true';
  return testing ? databaseFactoryFfiNoIsolate : databaseFactoryFfi;
}

class KilnDatabase {
  KilnDatabase(this._db);

  final Database _db;

  static Future<KilnDatabase> openDefault() async {
    configureDatabaseFactory();
    final directory = await getApplicationDocumentsDirectory();
    return openAt(p.join(directory.path, 'kiln.sqlite'));
  }

  static Future<KilnDatabase> openAt(String path) async {
    final db = await openDatabase(
      path,
      version: 1,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) => _create(db),
    );
    return KilnDatabase(db);
  }

  static Future<KilnDatabase> openMemory() async {
    final db = await _factory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: (db, version) => _create(db),
      ),
    );
    return KilnDatabase(db);
  }

  static Future<void> _create(DatabaseExecutor db) async {
    const statements = [
      '''
      CREATE TABLE recipes (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        kind TEXT NOT NULL,
        cone_min TEXT NOT NULL,
        cone_max TEXT NOT NULL,
        atmosphere TEXT NOT NULL,
        color_hex TEXT NOT NULL,
        color_name TEXT NOT NULL,
        surface TEXT NOT NULL,
        description TEXT NOT NULL,
        firing_notes TEXT NOT NULL,
        author TEXT NOT NULL,
        tested INTEGER NOT NULL,
        source TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
      ''',
      '''
      CREATE TABLE ingredients (
        id TEXT PRIMARY KEY,
        recipe_id TEXT NOT NULL,
        name TEXT NOT NULL,
        percentage REAL NOT NULL,
        role TEXT NOT NULL,
        sort_order INTEGER NOT NULL
      )
      ''',
      '''
      CREATE TABLE firings (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        kiln TEXT NOT NULL,
        starts_at TEXT NOT NULL,
        ends_at TEXT NOT NULL,
        cone TEXT NOT NULL,
        atmosphere TEXT NOT NULL,
        status TEXT NOT NULL,
        lead TEXT NOT NULL,
        notes TEXT NOT NULL,
        capacity INTEGER NOT NULL,
        booked INTEGER NOT NULL,
        source TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        deleted_at TEXT
      )
      ''',
      '''
      CREATE TABLE outbox (
        entity TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        payload TEXT NOT NULL,
        PRIMARY KEY (entity, entity_id)
      )
      ''',
      '''
      CREATE TABLE meta (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
      ''',
      'CREATE INDEX idx_recipes_updated ON recipes(updated_at)',
      'CREATE INDEX idx_firings_window ON firings(starts_at, ends_at)',
      'CREATE INDEX idx_ingredients_recipe ON ingredients(recipe_id)',
    ];
    for (final statement in statements) {
      await db.execute(statement);
    }
  }

  Future<void> close() => _db.close();

  Future<void> insertMissing({
    required List<Recipe> recipes,
    required List<Firing> firings,
  }) async {
    await _db.transaction((txn) async {
      for (final recipe in recipes) {
        final existing = await txn.query(
          'recipes',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [recipe.id],
          limit: 1,
        );
        if (existing.isEmpty) {
          await _writeRecipe(txn, recipe, enqueue: false);
        }
      }
      for (final firing in firings) {
        final existing = await txn.query(
          'firings',
          columns: ['id'],
          where: 'id = ?',
          whereArgs: [firing.id],
          limit: 1,
        );
        if (existing.isEmpty) {
          await _writeFiring(txn, firing, enqueue: false);
        }
      }
    });
  }

  Future<List<Recipe>> listRecipes() async {
    final rows = await _db.query(
      'recipes',
      where: 'deleted_at IS NULL',
      orderBy: 'name COLLATE NOCASE',
    );
    final ingredients = await _db.query('ingredients', orderBy: 'sort_order');
    final pending = await _pendingIds(_db, 'recipe');
    final grouped = <String, List<Ingredient>>{};
    for (final row in ingredients) {
      final ingredient = Ingredient.fromRow(row);
      grouped.putIfAbsent(row['recipe_id']! as String, () => []).add(ingredient);
    }
    return [
      for (final row in rows)
        Recipe.fromParts(
          row: row,
          ingredients: grouped[row['id']] ?? const [],
          pendingSync: pending.contains(row['id']),
        ),
    ];
  }

  Future<Recipe?> recipeById(String id, {bool includeDeleted = false}) async {
    final rows = await _db.query('recipes', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    final ingredients = await _db.query(
      'ingredients',
      where: 'recipe_id = ?',
      whereArgs: [id],
      orderBy: 'sort_order',
    );
    final pending = await _pendingIds(_db, 'recipe');
    final recipe = Recipe.fromParts(
      row: rows.first,
      ingredients: ingredients.map(Ingredient.fromRow).toList(),
      pendingSync: pending.contains(id),
    );
    if (!includeDeleted && recipe.deletedAt != null) return null;
    return recipe;
  }

  Future<void> saveRecipe(Recipe recipe, {required bool enqueue}) {
    return _db.transaction((txn) => _writeRecipe(txn, recipe, enqueue: enqueue));
  }

  Future<List<Firing>> firingsOverlapping(DateTime start, DateTime end) async {
    final rows = await _db.query(
      'firings',
      where: 'deleted_at IS NULL AND starts_at < ? AND ends_at > ?',
      whereArgs: [isoMillis(end), isoMillis(start)],
      orderBy: 'starts_at',
    );
    final pending = await _pendingIds(_db, 'firing');
    return [
      for (final row in rows)
        Firing.fromRow(row, pendingSync: pending.contains(row['id'])),
    ];
  }

  Future<void> saveFiring(Firing firing, {required bool enqueue}) {
    return _db.transaction((txn) => _writeFiring(txn, firing, enqueue: enqueue));
  }

  Future<({List<Recipe> recipes, List<Firing> firings})> outboxPayloads() async {
    final rows = await _db.query('outbox');
    final recipes = <Recipe>[];
    final firings = <Firing>[];
    for (final row in rows) {
      final payload = jsonDecode(row['payload']! as String) as Map<String, dynamic>;
      switch (row['entity']) {
        case 'recipe':
          recipes.add(Recipe.fromJson(payload));
        case 'firing':
          firings.add(Firing.fromJson(payload));
      }
    }
    return (recipes: recipes, firings: firings);
  }

  Future<int> pendingCount() async {
    final rows = await _db.rawQuery('SELECT COUNT(*) AS c FROM outbox');
    return (rows.first['c'] as num?)?.toInt() ?? 0;
  }

  Future<String?> meta(String key) async {
    final rows = await _db.query('meta', where: 'key = ?', whereArgs: [key], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['value'] as String?;
  }

  Future<void> applySync({
    required Set<String> sentRecipeIds,
    required Set<String> sentFiringIds,
    required SyncResponse response,
  }) {
    return _db.transaction((txn) async {
      final recipeConflicts = response.recipeConflicts.map((recipe) => recipe.id).toSet();
      final firingConflicts = response.firingConflicts.map((firing) => firing.id).toSet();

      for (final recipe in response.recipeConflicts) {
        await _writeRecipe(txn, recipe, enqueue: false);
      }
      for (final firing in response.firingConflicts) {
        await _writeFiring(txn, firing, enqueue: false);
      }
      for (final id in {...recipeConflicts, ...sentRecipeIds}) {
        await txn.delete(
          'outbox',
          where: 'entity = ? AND entity_id = ?',
          whereArgs: ['recipe', id],
        );
      }
      for (final id in {...firingConflicts, ...sentFiringIds}) {
        await txn.delete(
          'outbox',
          where: 'entity = ? AND entity_id = ?',
          whereArgs: ['firing', id],
        );
      }

      final pendingRecipes = await _pendingIds(txn, 'recipe');
      final pendingFirings = await _pendingIds(txn, 'firing');
      for (final recipe in response.recipes) {
        if (pendingRecipes.contains(recipe.id)) continue;
        final local = await _stamp(txn, 'recipes', recipe.id);
        if (local != null && local.compareTo(isoMillis(recipe.updatedAt)) > 0) continue;
        await _writeRecipe(txn, recipe, enqueue: false);
      }
      for (final firing in response.firings) {
        if (pendingFirings.contains(firing.id)) continue;
        final local = await _stamp(txn, 'firings', firing.id);
        if (local != null && local.compareTo(isoMillis(firing.updatedAt)) > 0) continue;
        await _writeFiring(txn, firing, enqueue: false);
      }
      await txn.insert(
        'meta',
        {'key': 'sync_cursor', 'value': isoMillis(response.serverTime)},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  Future<void> _writeRecipe(
    DatabaseExecutor db,
    Recipe recipe, {
    required bool enqueue,
  }) async {
    await db.delete('ingredients', where: 'recipe_id = ?', whereArgs: [recipe.id]);
    await db.insert('recipes', recipe.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
    for (final ingredient in recipe.ingredients) {
      await db.insert('ingredients', ingredient.toRow(recipe.id));
    }
    if (enqueue) {
      await db.insert(
        'outbox',
        {
          'entity': 'recipe',
          'entity_id': recipe.id,
          'payload': jsonEncode(recipe.toJson()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<void> _writeFiring(
    DatabaseExecutor db,
    Firing firing, {
    required bool enqueue,
  }) async {
    await db.insert('firings', firing.toRow(), conflictAlgorithm: ConflictAlgorithm.replace);
    if (enqueue) {
      await db.insert(
        'outbox',
        {
          'entity': 'firing',
          'entity_id': firing.id,
          'payload': jsonEncode(firing.toJson()),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
  }

  Future<Set<String>> _pendingIds(DatabaseExecutor db, String entity) async {
    final rows = await db.query(
      'outbox',
      columns: ['entity_id'],
      where: 'entity = ?',
      whereArgs: [entity],
    );
    return rows.map((row) => row['entity_id']! as String).toSet();
  }

  Future<String?> _stamp(DatabaseExecutor db, String table, String id) async {
    final rows = await db.query(
      table,
      columns: ['updated_at'],
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return rows.first['updated_at'] as String?;
  }
}
