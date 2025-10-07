import 'package:flutter/material.dart';

ThemeData buildAppTheme({
  required Brightness brightness,
  ColorScheme? dynamicScheme,
  bool highContrast = false,
}) {
  final baseScheme =
      dynamicScheme ??
      ColorScheme.fromSeed(
        brightness: brightness,
        seedColor: const Color(0xFF246BFD),
      );

  final colorScheme = highContrast
      ? baseScheme.copyWith(
          primary: baseScheme.primaryContainer,
          onPrimary: baseScheme.onPrimaryContainer,
          secondary: baseScheme.secondaryContainer,
          onSecondary: baseScheme.onSecondaryContainer,
          surface: brightness == Brightness.dark
              ? baseScheme.surface
              : baseScheme.surfaceContainerHighest,
          onSurface: baseScheme.onSurface.withValues(alpha: 0.95),
          outline: baseScheme.outline,
        )
      : baseScheme;

  final typography = Typography.material2021(platform: TargetPlatform.android);
  final textTheme = highContrast
      ? typography.black.apply(
          bodyColor: colorScheme.onSurface,
          displayColor: colorScheme.onSurface,
        )
      : (brightness == Brightness.dark ? typography.white : typography.black);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: colorScheme,
    textTheme: textTheme,
    visualDensity: VisualDensity.adaptivePlatformDensity,
    splashFactory: InkSparkle.splashFactory,
    appBarTheme: AppBarTheme(
      elevation: 0,
      backgroundColor: colorScheme.surface,
      foregroundColor: colorScheme.onSurface,
      centerTitle: true,
      titleTextStyle: textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      indicatorColor: colorScheme.secondaryContainer.withValues(alpha: 0.24),
      backgroundColor: colorScheme.surface,
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        final baseStyle = textTheme.labelMedium ?? const TextStyle();
        return baseStyle.copyWith(
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: selected ? colorScheme.primary : colorScheme.onSurfaceVariant,
        );
      }),
    ),
    cardTheme: CardThemeData(
      color: colorScheme.surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
      border: OutlineInputBorder(
        borderSide: BorderSide.none,
        borderRadius: BorderRadius.circular(16),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurfaceVariant,
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: colorScheme.secondaryContainer,
      selectedColor: colorScheme.primaryContainer,
      labelStyle: textTheme.labelLarge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      backgroundColor: colorScheme.surface,
      showDragHandle: true,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    dividerTheme: DividerThemeData(
      thickness: 1,
      space: 1,
      color: colorScheme.outlineVariant,
    ),
  );
}
