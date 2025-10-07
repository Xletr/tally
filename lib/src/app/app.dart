import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../domain/providers/settings_providers.dart';
import '../presentation/onboarding/onboarding_flow.dart';
import '../presentation/shell/app_shell.dart';

class TallyApp extends ConsumerWidget {
  const TallyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeController = ref.watch(themeControllerProvider);
    final settingsAsync = ref.watch(settingsControllerProvider);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final lightTheme = buildAppTheme(
          brightness: Brightness.light,
          dynamicScheme: themeController.useDynamicColor ? lightDynamic : null,
          highContrast: themeController.highContrast,
        );
        final darkTheme = buildAppTheme(
          brightness: Brightness.dark,
          dynamicScheme: themeController.useDynamicColor ? darkDynamic : null,
          highContrast: themeController.highContrast,
        );

        final onboardingPending = settingsAsync.maybeWhen(
          data: (value) => !value.onboardingCompleted,
          orElse: () => false,
        );

        return MaterialApp(
          title: 'Tally',
          debugShowCheckedModeBanner: false,
          restorationScopeId: 'tally',
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeController.mode,
          home: onboardingPending ? const OnboardingFlow() : const AppShell(),
        );
      },
    );
  }
}
