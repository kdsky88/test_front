import 'package:flutter/material.dart';
import '../services/destination_image_api.dart';

/// 커버 배경: 목적지 사진(Wikipedia)이 있으면 채우고 텍스트 가독성용 스크림을 얹는다.
/// 없거나 로딩·실패면 단색(fallback)으로 폴백. Stack 안 Positioned.fill로 쓴다.
class CoverImage extends StatefulWidget {
  const CoverImage({
    super.key,
    required this.destination,
    required this.fallback,
  });

  final String? destination;
  final Color fallback;

  @override
  State<CoverImage> createState() => _CoverImageState();
}

class _CoverImageState extends State<CoverImage> {
  String? _url;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(CoverImage old) {
    super.didUpdateWidget(old);
    if (old.destination != widget.destination) {
      _url = null;
      _fetch();
    }
  }

  Future<void> _fetch() async {
    final d = widget.destination?.trim();
    if (d == null || d.isEmpty) return;
    final url = await DestinationImageApi.imageUrl(d);
    if (mounted && widget.destination?.trim() == d && url != null) {
      setState(() => _url = url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(widget.fallback, const Color(0xFF355E52), .45)!,
            const Color(0xFF203F38),
          ],
        ),
      ),
      child: CustomPaint(painter: _Contours()),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        fallback,
        if (_url != null)
          Image.network(
            _url!,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => fallback,
            loadingBuilder: (_, child, progress) =>
                progress == null ? child : fallback,
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
