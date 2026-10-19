import 'royal_design.dart';

import 'package:flutter/material.dart';

const snapCream = Color(0xFFFFF8EA);
const snapForest = Color(0xFF193C37);
const snapTerracotta = Color(0xFFAA843D);
const snapPeach = Color(0xFFF6DCB7);

ThemeData snapWearTheme({String? fontFamily}) {
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(18),
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
      },
    ),
    scaffoldBackgroundColor: snapCream,
    colorScheme: ColorScheme.fromSeed(
      seedColor: snapForest,
      primary: snapForest,
      onPrimary: snapCream,
      secondary: snapForest,
      onSecondary: Colors.white,
      surface: snapCream,
      onSurface: const Color(0xFF24362D),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: snapCream,
      foregroundColor: snapForest,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: 'SnapSerif',
        fontSize: 22,
        color: snapForest,
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFF0DED0)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: snapForest,
        foregroundColor: snapCream,
        minimumSize: const Size(0, 52),
        shape: rounded,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: snapForest,
        foregroundColor: snapCream,
        elevation: 0,
        minimumSize: const Size(0, 52),
        shape: rounded,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: snapForest,
        minimumSize: const Size(0, 48),
        side: const BorderSide(color: snapForest),
        shape: rounded,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.all(18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFDCC7B8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: snapTerracotta, width: 2),
      ),
    ),
    chipTheme: const ChipThemeData(
      selectedColor: snapPeach,
      side: BorderSide(color: Color(0xFFDCC7B8)),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: snapPeach,
      elevation: 0,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: snapForest,
      foregroundColor: snapCream,
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: snapForest,
    ),
  );
}

class SnapWearHero extends StatelessWidget {
  final String eyebrow, title, subtitle;
  final IconData icon;
  const SnapWearHero({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.icon,
  });
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final wide = bounds.maxWidth >= 760;
      return Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: snapPeach,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Stack(
          children: [
            if (wide)
              Positioned.fill(
                child: Image.asset('assets/royal-hero.webp', fit: BoxFit.cover),
              ),
            Padding(
              padding: const EdgeInsets.all(26),
              child: SizedBox(
                width: wide ? bounds.maxWidth * .49 : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, color: royalGold, size: 22),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            eyebrow,
                            style: const TextStyle(
                              color: royalGold,
                              fontSize: 10,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      style: const TextStyle(
                        fontFamily: 'SnapSerif',
                        color: snapForest,
                        fontSize: 31,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF695642),
                        fontSize: 14,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
