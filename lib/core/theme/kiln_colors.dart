import 'package:material_ui/material_ui.dart';

abstract final class KilnColors {
  static const clay = Color(0xFFC4785A);
  static const clayDeep = Color(0xFF8C4634);
  static const ink = Color(0xFF241816);
  static const paper = Color(0xFFF6F1EA);
  static const celadon = Color(0xFF2F6B52);
  static const night = Color(0xFF1C1614);
  static const nightRaised = Color(0xFF2A221E);
  static const ember = Color(0xFFE2A48C);
  static const mist = Color(0xFF9BC7AA);
}

Color inkOn(Color background) {
  return background.computeLuminance() > 0.55 ? KilnColors.ink : const Color(0xFFF6F1EA);
}

Color colorFromHex(String hex) {
  final match = RegExp(r'^#([0-9A-Fa-f]{6})$').firstMatch(hex.trim());
  if (match == null) return KilnColors.clay;
  return Color(0xFF000000 | int.parse(match.group(1)!, radix: 16));
}

Color onClayBody(Color glaze, double thickness) {
  const clay = Color(0xFFC4A484);
  return Color.lerp(clay, glaze, thickness.clamp(0, 1))!;
}
