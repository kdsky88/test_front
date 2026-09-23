import 'package:flutter/material.dart';

/// 앱 디자인 시스템 — 여행 감성·따뜻한 톤(코럴 + 샌드/크림).
/// 라이트: 크림 배경 + 흰 카드 + 어두운 텍스트. 다크: M3 톤 서피스.
class AppTheme {
  static const Color seed = Color(0xFFEC6A4C); // 따뜻한 코럴
  static const double radius = 24;

  static ThemeData build(Brightness brightness) {
    final light = brightness == Brightness.light;
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness)
        .copyWith(
          primary: light ? const Color(0xFFB84932) : const Color(0xFFFFB5A1),
          onPrimary: light ? Colors.white : const Color(0xFF5C2013),
          primaryContainer: light
              ? const Color(0xFFFCE4DB)
              : const Color(0xFF653628),
          onPrimaryContainer: light
              ? const Color(0xFF76331F)
              : const Color(0xFFFFDBCF),
          secondary: light ? const Color(0xFF355E52) : const Color(0xFFA8CCBC),
          secondaryContainer: light
              ? const Color(0xFFE5EEE7)
              : const Color(0xFF2B443B),
          onSecondaryContainer: light
              ? const Color(0xFF274B3F)
              : const Color(0xFFD5EADD),
          surface: light ? const Color(0xFFFFFDF9) : const Color(0xFF191E1C),
          onSurface: light ? const Color(0xFF233A32) : const Color(0xFFE5E9E3),
          onSurfaceVariant: light
              ? const Color(0xFF68736B)
              : const Color(0xFFB2BDB5),
          outlineVariant: light
              ? const Color(0xFFE4E7DF)
              : const Color(0xFF39443D),
        );
    final bg = light ? const Color(0xFFF6F6F0) : const Color(0xFF131815);
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final type = base.textTheme.copyWith(
      headlineLarge: TextStyle(
        fontSize: 32,
        height: 1.25,
        letterSpacing: -1.0,
        fontWeight: FontWeight.w800,
        color: scheme.onSurface,
      ),
      headlineSmall: TextStyle(
        fontSize: 26,
        height: 1.3,
        letterSpacing: -0.7,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      titleLarge: TextStyle(
        fontSize: 22,
        height: 1.3,
        letterSpacing: -0.5,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      titleMedium: TextStyle(
        fontSize: 17,
        height: 1.4,
        letterSpacing: -0.3,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.55, color: scheme.onSurface),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: scheme.onSurface),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: scheme.onSurface,
      ),
    );
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
    return base.copyWith(
      textTheme: type,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
        },
      ),
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 20,
        titleTextStyle: type.titleLarge,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: shape.copyWith(side: BorderSide(color: scheme.outlineVariant)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        extendedTextStyle: type.labelLarge?.copyWith(color: scheme.onPrimary),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: scheme.secondaryContainer,
        elevation: 0,
        height: 76,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onSecondaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? scheme.onSurface
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: type.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          foregroundColor: scheme.onSurface,
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 44),
          textStyle: type.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: light ? Colors.white : scheme.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.5),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: shape,
        titleTextStyle: type.titleLarge,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: scheme.outlineVariant,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      expansionTileTheme: ExpansionTileThemeData(
        shape: const Border(),
        collapsedShape: const Border(),
        textColor: scheme.onSurface,
        iconColor: scheme.onSurfaceVariant,
      ),
    );
  }

  // 여행 커버 팔레트(따뜻한 톤). 제목/ID 해시로 안정 배정.
  static const List<Color> _covers = [
    Color(0xFFEC6A4C), // coral
    Color(0xFFE9973F), // amber
    Color(0xFFCC7A29), // ochre
    Color(0xFF7C9A6B), // sage
    Color(0xFF4E8D9C), // teal
    Color(0xFFB5654A), // terracotta
    Color(0xFFC96B86), // rose
  ];

  static Color coverFor(String key) {
    var h = 7;
    for (final c in key.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return _covers[h % _covers.length];
  }

  // 목적지/제목 첫 글자를 커버 이모지 대용으로. (이모지 라이브러리 없이 기본 아이콘 매핑)
  static const List<String> _emojis = [
    '🏖️',
    '🏔️',
    '🏙️',
    '🗺️',
    '🎒',
    '✈️',
    '🌅',
  ];
  static String emojiFor(String key) {
    var h = 3;
    for (final c in key.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return _emojis[h % _emojis.length];
  }
}
