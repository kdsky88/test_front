import 'package:flutter/material.dart';

/// 지명 키워드로 고르는 커버 이모지. 맞으면 분위기가 살고, 못 맞혀도 기본 ✈️면 무난하다.
/// 더 구체적인 지명이 먼저 와야 한다(예: '부산'이 '해변'보다 앞). 반대로 '산' 같은
/// 한 글자 키는 두지 않는다 — 부산·울산·군산까지 산으로 잡아버린다.
const _emojiByKeyword = <String, String>{
  '제주': '🏝️', '하와이': '🏝️', '발리': '🏝️', '오키나와': '🏝️', '푸켓': '🏝️',
  '세부': '🏝️', '보라카이': '🏝️', '몰디브': '🏝️', '괌': '🏝️', '사이판': '🏝️',
  '부산': '🌊', '강릉': '🌊', '속초': '🌊', '여수': '🌊', '포항': '🌊',
  '해운대': '🌊', '해변': '🌊', '바다': '🌊', 'beach': '🌊',
  '삿포로': '❄️', '홋카이도': '❄️', '스키': '❄️', '눈꽃': '❄️',
  '설악': '🏔️', '한라': '🏔️', '지리산': '🏔️', '알프스': '🏔️', '스위스': '🏔️',
  '네팔': '🏔️', '융프라우': '🏔️',
  '온천': '♨️', '벳푸': '♨️', '하코네': '♨️', '유후인': '♨️',
  '교토': '⛩️', '나라': '⛩️', '닛코': '⛩️',
  '경주': '🏯', '전주': '🏯', '안동': '🏯',
  '도쿄': '🏙️', '서울': '🏙️', '오사카': '🏙️', '뉴욕': '🏙️', '홍콩': '🏙️',
  '상하이': '🏙️', '싱가포르': '🏙️', '후쿠오카': '🏙️', '타이베이': '🏙️',
  '파리': '🗼', '런던': '🎡', '로마': '🏛️',
};

String coverEmoji(String? destination) {
  final d = destination?.trim().toLowerCase();
  if (d == null || d.isEmpty) return '✈️';
  for (final entry in _emojiByKeyword.entries) {
    if (d.contains(entry.key)) return entry.value;
  }
  return '✈️';
}

/// 커버 배경: 목적지에서 뽑은 색 그라데이션 + 등고선 패턴 + 큰 이모지.
///
/// 사진(위키)은 쓰지 않는다 — 카드 영역이 작아 큰 사진이 잘려 들어가면 어디인지
/// 알아보기 어려웠다. 대신 지명으로 색·이모지를 결정해 항상 또렷하게 보이고,
/// 네트워크도 타지 않는다. Stack 안 Positioned.fill로 쓴다.
class CoverImage extends StatelessWidget {
  const CoverImage({
    super.key,
    required this.destination,
    required this.fallback,
  });

  final String? destination;
  final Color fallback;

  String? get _key {
    final d = destination?.trim();
    return (d == null || d.isEmpty) ? null : d;
  }

  /// 지명 → 색(같은 여행지는 항상 같은 색). String.hashCode는 런타임마다 달라질 수
  /// 있어서 직접 계산한다.
  static int _hash(String s) {
    var h = 0;
    for (final c in s.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return h;
  }

  List<Color> get _colors {
    final d = _key;
    if (d == null) {
      return [
        Color.lerp(fallback, const Color(0xFF355E52), .45)!,
        const Color(0xFF203F38),
      ];
    }
    // 흰 글씨가 얹히므로 명도는 낮게 고정하고 색상(hue)만 지명에서 가져온다.
    final hue = (_hash(d) % 360).toDouble();
    return [
      HSLColor.fromAHSL(1, hue, .36, .38).toColor(),
      HSLColor.fromAHSL(1, (hue + 28) % 360, .45, .20).toColor(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _colors,
            ),
          ),
          child: CustomPaint(painter: _Contours()),
        ),
        // 카드든 히어로든 비슷한 비중으로 보이게 높이에 맞춰 키운다.
        LayoutBuilder(
          builder: (context, c) => Align(
            alignment: const Alignment(.82, -.25),
            child: Opacity(
              opacity: .9,
              child: Text(
                coverEmoji(destination),
                style: TextStyle(
                  fontSize: (c.maxHeight * .42).clamp(40.0, 104.0),
                  height: 1,
                ),
              ),
            ),
          ),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x16000000), Color(0x880D241C)],
            ),
          ),
        ),
      ],
    );
  }
}

class _Contours extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    final paint = Paint()
      ..color = const Color(0x30FFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (var i = 0; i < 8; i++) {
      final offset = i * size.height * .13;
      final path = Path()
        ..moveTo(size.width * .3, -size.height * .4 + offset)
        ..cubicTo(
          size.width * .75,
          size.height * .05 + offset,
          size.width * .45,
          size.height * .65 + offset,
          size.width * 1.2,
          size.height * .8 + offset,
        );
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_Contours oldDelegate) => false;
}
