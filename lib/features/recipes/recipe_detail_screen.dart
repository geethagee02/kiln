import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/models/recipe.dart';
import '../../core/models/studio_types.dart';
import '../../core/providers.dart';
import '../../core/theme/kiln_colors.dart';
import '../../widgets/glaze_swatch.dart';
import 'batch_math.dart';
import 'recipe_providers.dart';

class RecipeDetailScreen extends ConsumerWidget {
  const RecipeDetailScreen({super.key, required this.id});

  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipe = ref.watch(recipeProvider(id));
    return recipe.when(
      skipLoadingOnReload: true,
      loading: () => const Scaffold(body: Center(child: Text('Opening the recipe…'))),
      error: (error, stack) => const Scaffold(body: Center(child: Text('This recipe could not be read.'))),
      data: (value) {
        if (value == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: Text('This recipe has left the book.')),
          );
        }
        return _RecipeBody(recipe: value);
      },
    );
  }
}

class _RecipeBody extends ConsumerWidget {
  const _RecipeBody({required this.recipe});

  final Recipe recipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glaze = colorFromHex(recipe.colorHex);
    final ink = inkOn(glaze);
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final base = BatchMath.baseTotal(recipe.ingredients);
    final extra = BatchMath.extraTotal(recipe.ingredients);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 220,
            backgroundColor: glaze,
            foregroundColor: ink,
            flexibleSpace: FlexibleSpaceBar(
              background: GlazeSwatch(
                color: glaze,
                label: recipe.colorName,
                borderRadius: BorderRadius.zero,
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(recipe.name, style: text.headlineMedium),
                  const SizedBox(height: 6),
                  Text(recipe.colorName, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Meta(recipe.kind.label),
                      _Meta(coneLabel(recipe.coneMin, recipe.coneMax)),
                      _Meta(recipe.atmosphere.label),
                      _Meta(recipe.surface.label),
                      _Meta(recipe.tested ? 'Tested' : 'Untested'),
                      if (recipe.pendingSync) const _Meta('Not synced yet'),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(recipe.description, style: text.bodyLarge),
                  const SizedBox(height: 22),
                  Text('ON THE STUDIO STONEWARE', style: text.labelMedium?.copyWith(letterSpacing: 1.1)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      for (final coat in const [('Thin', 0.45), ('Dip', 0.78), ('Thick', 1.0)])
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 64,
                                  child: GlazeSwatch(
                                    color: onClayBody(glaze, coat.$2),
                                    label: '${recipe.colorName}, ${coat.$1}',
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(coat.$1, style: text.bodySmall),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Text('BATCH', style: text.labelMedium?.copyWith(letterSpacing: 1.1)),
                  const SizedBox(height: 8),
                  for (final ingredient in recipe.ingredients) _IngredientLine(ingredient: ingredient),
                  const SizedBox(height: 8),
                  Text(
                    'Base ${formatPercent(base)}% · added ${formatPercent(extra)}%',
                    style: text.titleSmall,
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FIRING',
                          style: text.labelMedium?.copyWith(color: scheme.onSecondaryContainer),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          recipe.firingNotes.isEmpty ? 'No firing notes yet.' : recipe.firingNotes,
                          style: text.bodyMedium?.copyWith(color: scheme.onSecondaryContainer),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text('Kept by ${recipe.author}', style: text.bodyMedium),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => context.push('/recipe/${recipe.id}/edit'),
                          child: const Text('Edit batch'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _remove(context, ref),
                          child: const Text('Remove'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove this recipe?'),
        content: const Text(
          'It leaves this phone now, and the shared book the next time Kiln can sync.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Keep')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await ref.read(recipeRepositoryProvider).delete(recipe.id);
    await ref.read(syncControllerProvider.notifier).refresh();
    if (context.mounted) context.pop();
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelLarge),
    );
  }
}

class _IngredientLine extends StatelessWidget {
  const _IngredientLine({required this.ingredient});

  final Ingredient ingredient;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final width = (ingredient.percentage / 100).clamp(0.04, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(ingredient.name)),
              Text(ingredient.role.label, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(width: 12),
              Text('${formatPercent(ingredient.percentage)}%'),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: width,
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: ingredient.role == IngredientRole.base ? scheme.secondary : scheme.primary,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
