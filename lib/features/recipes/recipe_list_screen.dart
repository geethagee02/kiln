import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/models/recipe.dart';
import '../../core/models/studio_types.dart';
import '../../core/providers.dart';
import '../../core/theme/kiln_colors.dart';
import '../../widgets/glaze_swatch.dart';
import 'recipe_providers.dart';

class RecipeListScreen extends ConsumerWidget {
  const RecipeListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(recipeQueryProvider);
    final recipes = ref.watch(filteredRecipesProvider);
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () => ref.read(syncControllerProvider.notifier).refresh(),
      child: recipes.when(
        skipLoadingOnReload: true,
        loading: () => const _MessageList(text: 'Opening the glaze book…'),
        error: (error, stack) => const _MessageList(
          text: 'The glaze book on this phone could not be read.',
        ),
        data: (items) {
          return ListView(
            key: const Key('recipe-list'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 108),
            children: [
              Text('Glaze book', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 4),
              Text(
                'Recipes on the shelf, with the tests that proved them.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              _SearchBox(
                onChanged: ref.read(recipeQueryProvider.notifier).setSearch,
              ),
              const SizedBox(height: 12),
              _ChipScroller(
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: query.kind == null,
                    onSelected: (_) => ref.read(recipeQueryProvider.notifier).setKind(null),
                  ),
                  for (final kind in RecipeKind.values)
                    ChoiceChip(
                      label: Text(kind.plural),
                      selected: query.kind == kind,
                      onSelected: (_) => ref.read(recipeQueryProvider.notifier).setKind(kind),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              _ChipScroller(
                children: [
                  ChoiceChip(
                    label: const Text('Any heat'),
                    selected: query.coneBand == null && query.atmosphere == null,
                    onSelected: (_) {
                      ref.read(recipeQueryProvider.notifier).setConeBand(null);
                      ref.read(recipeQueryProvider.notifier).setAtmosphere(null);
                    },
                  ),
                  for (final band in ConeBand.values)
                    ChoiceChip(
                      label: Text(band.label),
                      selected: query.coneBand == band,
                      onSelected: (_) => ref.read(recipeQueryProvider.notifier).setConeBand(
                            query.coneBand == band ? null : band,
                          ),
                    ),
                  for (final atmosphere in Atmosphere.values)
                    ChoiceChip(
                      label: Text(atmosphere.label),
                      selected: query.atmosphere == atmosphere,
                      onSelected: (_) => ref.read(recipeQueryProvider.notifier).setAtmosphere(
                            query.atmosphere == atmosphere ? null : atmosphere,
                          ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              if (items.isEmpty)
                Text(
                  'No recipes match. Clear the search, or add the batch before it lives on a sticky note.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant),
                )
              else
                for (final recipe in items) ...[
                  _RecipeCard(
                    recipe: recipe,
                    onTap: () => context.push('/recipe/${recipe.id}'),
                  ),
                  const SizedBox(height: 10),
                ],
            ],
          );
        },
      ),
    );
  }
}

class _SearchBox extends StatefulWidget {
  const _SearchBox({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  State<_SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<_SearchBox> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      key: const Key('recipe-search'),
      controller: _controller,
      onChanged: widget.onChanged,
      textCapitalization: TextCapitalization.none,
      decoration: const InputDecoration(
        hintText: 'Search glazes, materials, authors',
        prefixIcon: Icon(Icons.search),
      ),
    );
  }
}

class _ChipScroller extends StatelessWidget {
  const _ChipScroller({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: children.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) => children[index],
      ),
    );
  }
}

class _RecipeCard extends StatelessWidget {
  const _RecipeCard({required this.recipe, required this.onTap});

  final Recipe recipe;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                height: 88,
                child: GlazeSwatch(
                  color: colorFromHex(recipe.colorHex),
                  label: recipe.colorName,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(recipe.name, style: text.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      '${coneLabel(recipe.coneMin, recipe.coneMax)} · ${recipe.atmosphere.label}',
                      style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${recipe.surface.label} · ${recipe.author}',
                      style: text.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      recipe.pendingSync
                          ? 'Not synced yet'
                          : recipe.tested
                              ? 'Tested'
                              : 'Untested',
                      style: text.labelMedium?.copyWith(
                        color: recipe.pendingSync
                            ? scheme.primary
                            : recipe.tested
                                ? scheme.secondary
                                : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          text,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
