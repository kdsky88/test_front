import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/destination_cover.dart';

/// Bundled, reviewed photos only. Unknown destinations keep the local gradient.
/// Photos use contain so landmarks are never cropped by a narrow card.
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
    final photo = DestinationCover.find(destination);
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
        if (photo != null) ...[
          Image.asset(
            photo.asset,
            fit: BoxFit.contain,
            alignment: Alignment.center,
            semanticLabel: '${photo.name} · ${photo.landmark}',
            errorBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
          Positioned(
            right: 8,
            bottom: 8,
            child: IconButton.filled(
              tooltip: '사진 출처',
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xEFFFFFFF),
                foregroundColor: const Color(0xFF233A32),
                minimumSize: const Size(48, 48),
              ),
              icon: const Icon(Icons.info_outline, size: 20),
              onPressed: () => _showCredit(context, photo),
            ),
          ),
        ],
      ],
    );
  }

  void _showCredit(BuildContext context, DestinationCover photo) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${photo.name} 커버 사진'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(photo.landmark),
              const SizedBox(height: 12),
              SelectableText(
                '파일: ${photo.file}\n저작자: ${photo.author}\n라이선스: ${photo.license}',
              ),
              const SizedBox(height: 8),
              const Text('Wikimedia Commons 제공 · 크기 축소, 구도 변경 없음'),
              TextButton(
                onPressed: () => _open(context, photo.source),
                child: const Text('원본 및 저작자 보기'),
              ),
              TextButton(
                onPressed: () => _open(context, photo.licenseUrl),
                child: const Text('라이선스 보기'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('닫기'),
          ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, String url) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      /* Keep credit details available when the browser is unavailable. */
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text('링크를 열 수 없습니다. 잠시 후 다시 시도해 주세요.')),
      );
    }
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
