import '../../core/format.dart';
import '../../core/models/recipe.dart';
import '../../core/models/studio_types.dart';

/// Studio batch rule: materials with role [IngredientRole.base] are the
/// unity batch and must total 100. Colorants, opacifiers, and additives sit
/// on top, the way a bucket recipe is written on the studio wall.
/// This is not a Seger unity calculation.
class BatchMath {
  static double baseTotal(List<Ingredient> items) {
    return items
        .where((item) => item.role == IngredientRole.base)
        .fold(0, (sum, item) => sum + item.percentage);
  }

  static double extraTotal(List<Ingredient> items) {
    return items
        .where((item) => item.role != IngredientRole.base)
        .fold(0, (sum, item) => sum + item.percentage);
  }

  static String? validate(List<Ingredient> items) {
    if (items.isEmpty) return 'Add at least one material.';
    for (final item in items) {
      if (item.name.trim().isEmpty) return 'Every material needs a name.';
      if (item.percentage <= 0 || item.percentage > 200) {
        return 'Percentages have to be greater than zero.';
      }
    }
    final base = baseTotal(items);
    if ((base - 100).abs() > 0.15) {
      return 'Base materials must total 100%. They total ${formatPercent(base)}%.';
    }
    return null;
  }

  static String? validateDraft(RecipeDraft draft) {
    if (draft.name.trim().isEmpty) return 'Name the recipe.';
    if (draft.author.trim().isEmpty) return 'Add your name so the studio knows who tested it.';
    if (draft.colorName.trim().isEmpty) return 'Name the color.';
    if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(draft.colorHex.trim())) {
      return 'Use a hex color like #6E9A84.';
    }
    if (!coneLabels.contains(draft.coneMin) || !coneLabels.contains(draft.coneMax)) {
      return 'Choose a cone range.';
    }
    if (coneValue(draft.coneMin) > coneValue(draft.coneMax)) {
      return 'Cone min has to be lower than cone max.';
    }
    return validate(draft.ingredients);
  }
}
