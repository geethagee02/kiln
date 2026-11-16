import 'package:material_ui/material_ui.dart';

import 'kiln_colors.dart';

abstract final class KilnTheme {
  static ThemeData light() => _theme(Brightness.light);
  static ThemeData dark() => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: KilnColors.clay,
      brightness: brightness,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
      primary: dark ? KilnColors.ember : KilnColors.clayDeep,
      onPrimary: dark ? KilnColors.ink : const Color(0xFFFFF8F4),
      secondary: dark ? KilnColors.mist : KilnColors.celadon,
      onSecondary: dark ? KilnColors.ink : const Color(0xFFF3FBF6),
      surface: dark ? KilnColors.night : KilnColors.paper,
      onSurface: dark ? const Color(0xFFF3EBE3) : KilnColors.ink,
      surfaceContainerLowest: dark ? const Color(0xFF16110F) : const Color(0xFFFFFBF7),
      surfaceContainerLow: dark ? const Color(0xFF221C19) : const Color(0xFFF3EBE3),
      surfaceContainer: dark ? KilnColors.nightRaised : const Color(0xFFEFE4DA),
      surfaceContainerHigh: dark ? const Color(0xFF342B26) : const Color(0xFFE7D9CC),
      surfaceContainerHighest: dark ? const Color(0xFF3E342E) : const Color(0xFFE0D0C2),
    );
    final typography = Typography.material2021(platform: TargetPlatform.android);
    final base = (dark ? typography.white : typography.black).apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );
    final text = _text(base);
    final radius = BorderRadius.circular(16);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainerLowest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        labelStyle: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
        border: OutlineInputBorder(borderRadius: radius, borderSide: BorderSide(color: scheme.outline)),
        enabledBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: radius,
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        selectedColor: scheme.primary,
        disabledColor: scheme.surfaceContainer,
        labelStyle: text.labelLarge?.copyWith(color: scheme.onSurface),
        secondaryLabelStyle: text.labelLarge?.copyWith(color: scheme.onPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: const StadiumBorder(),
        side: BorderSide.none,
        showCheckmark: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: radius),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        extendedTextStyle: text.labelLarge?.copyWith(color: scheme.onPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        height: 68,
        labelTextStyle: WidgetStatePropertyAll(
          text.labelMedium?.copyWith(letterSpacing: 0, color: scheme.onSurface),
        ),
      ),
    );
  }

  static TextTheme _text(TextTheme base) {
    TextStyle fraunces(TextStyle? style) {
      return (style ?? const TextStyle()).copyWith(
        fontFamily: 'Fraunces',
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
        height: 1.05,
      );
    }

    TextStyle outfit(TextStyle? style, {FontWeight weight = FontWeight.w400}) {
      return (style ?? const TextStyle()).copyWith(
        fontFamily: 'Outfit',
        fontWeight: weight,
        letterSpacing: 0,
      );
    }

    return base.copyWith(
      displayLarge: fraunces(base.displayLarge),
      displayMedium: fraunces(base.displayMedium),
      displaySmall: fraunces(base.displaySmall),
      headlineLarge: fraunces(base.headlineLarge),
      headlineMedium: fraunces(base.headlineMedium),
      headlineSmall: fraunces(base.headlineSmall),
      titleLarge: outfit(base.titleLarge, weight: FontWeight.w600),
      titleMedium: outfit(base.titleMedium, weight: FontWeight.w600),
      titleSmall: outfit(base.titleSmall, weight: FontWeight.w600),
      bodyLarge: outfit(base.bodyLarge),
      bodyMedium: outfit(base.bodyMedium),
      bodySmall: outfit(base.bodySmall),
      labelLarge: outfit(base.labelLarge, weight: FontWeight.w600),
      labelMedium: outfit(base.labelMedium, weight: FontWeight.w600),
      labelSmall: outfit(base.labelSmall, weight: FontWeight.w600),
    );
  }
}
