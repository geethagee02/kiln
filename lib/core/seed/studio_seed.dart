import 'dart:convert';

import 'package:flutter/services.dart';

import '../db/kiln_database.dart';
import '../format.dart';
import '../models/firing.dart';
import '../models/recipe.dart';
import '../models/studio_types.dart';
import '../runtime.dart';

class StudioSnapshot {
  const StudioSnapshot({required this.recipes, required this.firings});

  final List<Recipe> recipes;
  final List<Firing> firings;
}

String isoWeekKey(DateTime localDate) {
  final date = DateTime.utc(localDate.year, localDate.month, localDate.day);
  final thursday = date.add(Duration(days: 4 - date.weekday));
  final yearStart = DateTime.utc(thursday.year, 1, 1);
  final week = ((thursday.difference(yearStart).inDays + 1) / 7).ceil();
  return '${thursday.year}-W${week.toString().padLeft(2, '0')}';
}

StudioSnapshot expandStudio(String raw, DateTime nowLocal) {
  final document = jsonDecode(raw) as Map<String, dynamic>;
  final stamp = parseIso(seedStampIso);
  final recipes = <Recipe>[];
  for (final entry in document['recipes'] as List) {
    final json = (entry as Map).cast<String, dynamic>();
    final id = json['id'] as String;
    final ingredientJson = json['ingredients'] as List;
    final ingredients = <Ingredient>[
      for (var index = 0; index < ingredientJson.length; index++)
        Ingredient(
          id: '$id:$index',
          name: (ingredientJson[index] as Map)['name'] as String,
          percentage: ((ingredientJson[index] as Map)['percentage'] as num).toDouble(),
          role: enumByName(
            IngredientRole.values,
            (ingredientJson[index] as Map)['role'],
            'role',
          ),
          sortOrder: index,
        ),
    ];
    recipes.add(
      Recipe(
        id: id,
        name: json['name'] as String,
        kind: enumByName(RecipeKind.values, json['kind'], 'kind'),
        coneMin: json['coneMin'] as String,
        coneMax: json['coneMax'] as String,
        atmosphere: enumByName(Atmosphere.values, json['atmosphere'], 'atmosphere'),
        colorHex: (json['colorHex'] as String).toUpperCase(),
        colorName: json['colorName'] as String,
        surface: enumByName(Surface.values, json['surface'], 'surface'),
        description: json['description'] as String,
        firingNotes: json['firingNotes'] as String,
        author: json['author'] as String,
        tested: json['tested'] == true,
        source: RecordSource.seed,
        createdAt: stamp,
        updatedAt: stamp,
        deletedAt: null,
        ingredients: ingredients,
      ),
    );
  }

  final monday = mondayOf(nowLocal);
  final firings = <Firing>[];
  for (final entry in document['firingTemplates'] as List) {
    final template = (entry as Map).cast<String, dynamic>();
    final start = DateTime(
      monday.year,
      monday.month,
      monday.day + (template['dayOffset'] as num).toInt(),
      (template['startHour'] as num).toInt(),
    );
    final end = start.add(Duration(hours: (template['durationHours'] as num).toInt()));
    firings.add(
      Firing(
        id: 'firing-${isoWeekKey(start)}-${template['idSuffix']}',
        title: template['title'] as String,
        kiln: template['kiln'] as String,
        startsAt: start.toUtc(),
        endsAt: end.toUtc(),
        cone: template['cone'] as String,
        atmosphere: enumByName(Atmosphere.values, template['atmosphere'], 'atmosphere'),
        status: statusForWindow(start: start, end: end, now: nowLocal),
        lead: template['lead'] as String,
        notes: template['notes'] as String,
        capacity: (template['capacity'] as num).toInt(),
        booked: (template['booked'] as num).toInt(),
        source: RecordSource.seed,
        createdAt: stamp,
        updatedAt: stamp,
        deletedAt: null,
      ),
    );
  }
  return StudioSnapshot(recipes: recipes, firings: firings);
}

Future<void> ensureSeed(
  KilnDatabase db, {
  required StudioClock clock,
  String? raw,
}) async {
  final source = raw ?? await rootBundle.loadString('assets/seed/studio.json');
  final studio = expandStudio(source, clock.now().toLocal());
  await db.insertMissing(recipes: studio.recipes, firings: studio.firings);
}
