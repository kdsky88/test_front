import 'package:flutter/material.dart';
import '../services/destination_image_api.dart';

/// 커버 배경: 목적지 사진(Wikipedia)이 있으면 채우고 텍스트 가독성용 스크림을 얹는다.
/// 없거나 로딩·실패면 단색(fallback)으로 폴백. Stack 안 Positioned.fill로 쓴다.
class CoverImage extends StatefulWidget {
  const CoverImage({super.key, required this.destination, required this.fallback});

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
    if (mounted && url != null) setState(() => _url = url);
  }

  @override
  Widget build(BuildContext context) {
    if (_url == null) return ColoredBox(color: widget.fallback);
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          _url!,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => ColoredBox(color: widget.fallback),
          loadingBuilder: (_, child, progress) =>
              progress == null ? child : ColoredBox(color: widget.fallback),
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black26, Colors.black54],
            ),
          ),
        ),
      ],
    );
  }
}
