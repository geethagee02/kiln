import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/models/recipe.dart';
import '../../core/models/studio_types.dart';
import '../../core/providers.dart';
import '../../core/theme/kiln_colors.dart';
import 'batch_math.dart';

class RecipeFormScreen extends ConsumerStatefulWidget {
  const RecipeFormScreen({super.key, this.recipeId});

  final String? recipeId;

  @override
  ConsumerState<RecipeFormScreen> createState() => _RecipeFormScreenState();
}

class _IngredientField {
  _IngredientField({String name = '', String percent = '', this.role = IngredientRole.base})
      : name = TextEditingController(text: name),
        percent = TextEditingController(text: percent);

  final TextEditingController name;
  final TextEditingController percent;
  IngredientRole role;

  void dispose() {
    name.dispose();
    percent.dispose();
  }
}

class _RecipeFormScreenState extends ConsumerState<RecipeFormScreen> {
  final _name = TextEditingController();
  final _author = TextEditingController();
  final _description = TextEditingController();
  final _notes = TextEditingController();
  final _colorName = TextEditingController(text: _presets.first.$2);
  RecipeKind _kind = RecipeKind.glaze;
  String _coneMin = '6';
  String _coneMax = '6';
  Atmosphere _atmosphere = Atmosphere.oxidation;
  Surface _surface = Surface.satin;
  String _hex = _presets.first.$1;
  bool _tested = false;
  final _fields = <_IngredientField>[_IngredientField()];
  String? _error;
  bool _saving = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final id = widget.recipeId;
    if (id == null) return;
    _loading = true;
    Future.microtask(() async {
      final recipe = await ref.read(recipeRepositoryProvider).byId(id);
      if (!mounted) return;
      if (recipe == null) {
        setState(() => _loading = false);
        return;
      }
      _apply(recipe);
      setState(() => _loading = false);
    });
  }

  void _apply(Recipe recipe) {
    _name.text = recipe.name;
    _author.text = recipe.author;
    _description.text = recipe.description;
    _notes.text = recipe.firingNotes;
    _colorName.text = recipe.colorName;
    _kind = recipe.kind;
    _coneMin = recipe.coneMin;
    _coneMax = recipe.coneMax;
    _atmosphere = recipe.atmosphere;
    _surface = recipe.surface;
    _hex = recipe.colorHex;
    _tested = recipe.tested;
    for (final field in _fields) {
      field.dispose();
    }
    _fields
      ..clear()
      ..addAll(
        recipe.ingredients.map(
          (item) => _IngredientField(
            name: item.name,
            percent: formatPercent(item.percentage),
            role: item.role,
          ),
        ),
      );
  }

  @override
  void dispose() {
    _name.dispose();
    _author.dispose();
    _description.dispose();
    _notes.dispose();
    _colorName.dispose();
    for (final field in _fields) {
      field.dispose();
    }
    super.dispose();
  }

  List<Ingredient> _ingredients() {
    final items = <Ingredient>[];
    for (var index = 0; index < _fields.length; index++) {
      final field = _fields[index];
      final name = field.name.text.trim();
      final raw = field.percent.text.trim();
      if (name.isEmpty && raw.isEmpty) continue;
      final percentage = double.tryParse(raw);
      if (name.isEmpty || percentage == null) {
        throw RecipeInvalid(
          name.isEmpty ? 'Every material needs a name.' : 'Enter a percentage for each material.',
        );
      }
      items.add(
        Ingredient(
          id: '',
          name: name,
          percentage: percentage,
          role: field.role,
          sortOrder: index,
        ),
      );
    }
    return items;
  }

  double _baseSoFar() {
    var total = 0.0;
    for (final field in _fields) {
      if (field.role != IngredientRole.base) continue;
      final value = double.tryParse(field.percent.text.trim());
      if (value != null) total += value;
    }
    return total;
  }

  Future<void> _save() async {
    late final RecipeDraft draft;
    try {
      draft = RecipeDraft(
        name: _name.text,
        kind: _kind,
        coneMin: _coneMin,
        coneMax: _coneMax,
        atmosphere: _atmosphere,
        colorHex: _hex,
        colorName: _colorName.text,
        surface: _surface,
        description: _description.text,
        firingNotes: _notes.text,
        author: _author.text,
        tested: _tested,
        ingredients: _ingredients(),
      );
    } on RecipeInvalid catch (error) {
      setState(() => _error = error.message);
      return;
    }
    final error = BatchMath.validateDraft(draft);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final repository = ref.read(recipeRepositoryProvider);
      final id = widget.recipeId;
      if (id == null) {
        await repository.create(draft);
      } else {
        await repository.update(id, draft);
      }
      await ref.read(syncControllerProvider.notifier).refresh();
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: Text('Opening the batch…')));
    }
    final base = _baseSoFar();
    final baseOk = (base - 100).abs() <= 0.15;
    return Scaffold(
      appBar: AppBar(title: Text(widget.recipeId == null ? 'New recipe' : 'Edit batch')),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                TextField(
                  key: const Key('recipe-name'),
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Recipe name'),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('recipe-author'),
                  controller: _author,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Your name'),
                ),
                const SizedBox(height: 16),
                const _Label('Kind'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final kind in RecipeKind.values)
                      ChoiceChip(
                        label: Text(kind.label),
                        selected: _kind == kind,
                        onSelected: (_) => setState(() => _kind = kind),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const _Label('Cone min'),
                _ConeWrap(
                  selected: _coneMin,
                  onSelected: (value) => setState(() => _coneMin = value),
                ),
                const SizedBox(height: 12),
                const _Label('Cone max'),
                _ConeWrap(
                  selected: _coneMax,
                  onSelected: (value) => setState(() => _coneMax = value),
                ),
                const SizedBox(height: 12),
                const _Label('Atmosphere'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final atmosphere in Atmosphere.values)
                      ChoiceChip(
                        label: Text(atmosphere.label),
                        selected: _atmosphere == atmosphere,
                        onSelected: (_) => setState(() => _atmosphere = atmosphere),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const _Label('Surface'),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final surface in Surface.values)
                      ChoiceChip(
                        label: Text(surface.label),
                        selected: _surface == surface,
                        onSelected: (_) => setState(() => _surface = surface),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                const _Label('Studio palette'),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final preset in _presets)
                      GestureDetector(
                        onTap: () => setState(() {
                          _hex = preset.$1;
                          _colorName.text = preset.$2;
                        }),
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: colorFromHex(preset.$1),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _hex.toUpperCase() == preset.$1
                                  ? Theme.of(context).colorScheme.onSurface
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _colorName,
                  decoration: const InputDecoration(labelText: 'Color name'),
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Tested on a tile'),
                  value: _tested,
                  onChanged: (value) => setState(() => _tested = value),
                ),
                TextField(
                  controller: _description,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'What it does'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notes,
                  minLines: 2,
                  maxLines: 4,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Firing notes'),
                ),
                const SizedBox(height: 18),
                const _Label('Materials'),
                for (var index = 0; index < _fields.length; index++)
                  _IngredientEditor(
                    index: index,
                    field: _fields[index],
                    onChanged: () => setState(() {}),
                    onRemove: () {
                      setState(() {
                        _fields.removeAt(index).dispose();
                      });
                    },
                  ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _fields.add(_IngredientField())),
                    icon: const Icon(Icons.add),
                    label: const Text('Add material'),
                  ),
                ),
                Text(
                  baseOk
                      ? 'Base totals ${formatPercent(base)}%.'
                      : 'Base is ${formatPercent(base)}%. It needs to total 100%.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: baseOk
                            ? Theme.of(context).colorScheme.secondary
                            : Theme.of(context).colorScheme.error,
                      ),
                ),
              ],
            ),
          ),
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      Text(
                        _error!,
                        key: const Key('form-error'),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                      ),
                      const SizedBox(height: 8),
                    ],
                    FilledButton(
                      key: const Key('save-recipe'),
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Saving…' : 'Save recipe'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IngredientEditor extends StatelessWidget {
  const _IngredientEditor({
    required this.index,
    required this.field,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final _IngredientField field;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 4, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: Key('ingredient-name-$index'),
                      controller: field.name,
                      onChanged: (_) => onChanged(),
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'Material'),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove material',
                    onPressed: onRemove,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 6,
                      children: [
                        for (final role in IngredientRole.values)
                          ChoiceChip(
                            label: Text(role.label),
                            selected: field.role == role,
                            onSelected: (_) {
                              field.role = role;
                              onChanged();
                            },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 88,
                    child: TextField(
                      key: Key('ingredient-percent-$index'),
                      controller: field.percent,
                      onChanged: (_) => onChanged(),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                      decoration: const InputDecoration(labelText: '%'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConeWrap extends StatelessWidget {
  const _ConeWrap({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final cone in coneLabels)
          ChoiceChip(
            label: Text(cone),
            selected: selected == cone,
            onSelected: (_) => onSelected(cone),
          ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(letterSpacing: 1.1),
      ),
    );
  }
}

const _presets = [
  ('#6E9A84', 'soft celadon'),
  ('#241816', 'iron black'),
  ('#E4B5A4', 'shino blush'),
  ('#6E9E8C', 'foggy copper green'),
  ('#1E6A45', 'deep oribe'),
  ('#E4D0B0', 'warm oatmeal'),
  ('#2A4E86', 'cobalt blue'),
  ('#E2C15A', 'rutile yellow'),
  ('#F3EEE6', 'covering white'),
  ('#8C3A2F', 'iron red'),
];
