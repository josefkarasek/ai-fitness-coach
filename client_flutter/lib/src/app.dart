import 'package:flutter/material.dart';

import 'app_dependencies.dart';
import 'home/home_screen.dart';

class AiFitnessCoachApp extends StatelessWidget {
  const AiFitnessCoachApp({
    super.key,
    required this.dependencies,
    this.home,
  });

  final AppDependencies dependencies;
  final Widget? home;

  @override
  Widget build(BuildContext context) {
    const Color background = Color(0xFF0B0D10);
    const Color surface = Color(0xFF171A1F);
    const Color outline = Color(0xFF2A2F37);
    const Color primary = Color(0xFFEEF3F8);
    const Color accent = Color(0xFF42D392);

    return MaterialApp(
      title: 'Forge',
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: accent,
          secondary: Color(0xFF5EA4FF),
          surface: surface,
          onPrimary: Color(0xFF09110E),
          onSecondary: Colors.white,
          onSurface: primary,
          error: Color(0xFFFF7E73),
        ),
        scaffoldBackgroundColor: background,
        canvasColor: background,
        dividerColor: Colors.transparent,
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF11151A),
          labelStyle: const TextStyle(color: Color(0xFF96A0AD)),
          helperStyle: const TextStyle(color: Color(0xFF77808C)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: outline),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: accent, width: 1.2),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: const BorderSide(color: outline),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor: const Color(0xFF09110E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            side: const BorderSide(color: outline),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xFFB4C2D2),
          ),
        ),
        checkboxTheme: CheckboxThemeData(
          shape: const CircleBorder(),
          side: const BorderSide(color: outline, width: 1.4),
          fillColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
              if (states.contains(WidgetState.selected)) {
                return accent;
              }
              return Colors.transparent;
            },
          ),
          checkColor: WidgetStateProperty.all(const Color(0xFF09110E)),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFF101318),
          modalBackgroundColor: Color(0xFF101318),
          surfaceTintColor: Colors.transparent,
        ),
        useMaterial3: true,
      ),
      home: home ??
          HomeScreen(
            preferences: dependencies.preferences,
            localCacheRepository: dependencies.localCacheRepository,
          ),
    );
  }
}
