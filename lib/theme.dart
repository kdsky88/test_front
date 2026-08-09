import 'package:flutter/material.dart';

/// 앱 디자인 시스템 — 여행 감성·따뜻한 톤(코럴 + 샌드/크림).
/// 라이트: 크림 배경 + 흰 카드 + 어두운 텍스트. 다크: M3 톤 서피스.
class AppTheme {
  static const Color seed = Color(0xFFEC6A4C); // 따뜻한 코럴
  static const Color _cream = Color(0xFFF5F4F2); // 중립 오프화이트 배경
  static const double radius = 18;

  static ThemeData build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    final scheme = ColorScheme.fromSeed(seedColor: seed, brightness: brightness);
    final bg = isLight ? _cream : scheme.surface;
    final card = isLight ? Colors.white : scheme.surfaceContainerHigh;

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(
        backgroundColor: bg,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: scheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: card,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: card,
        indicatorColor: scheme.primaryContainer,
        elevation: 3,
        height: 66,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        thickness: 1,
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
  static const List<String> _emojis = ['🏖️', '🏔️', '🏙️', '🗺️', '🎒', '✈️', '🌅'];
  static String emojiFor(String key) {
    var h = 3;
    for (final c in key.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return _emojis[h % _emojis.length];
  }
}
