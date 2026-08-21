import 'dart:math';
import 'package:flutter/material.dart';
import '../theme.dart';

/// 시작 스플래시: 비행기가 곡선 경로로 날아가며(기수 회전) 점선 비행운을 남기고,
/// 이어서 앱 이름이 페이드업. 끝나면 onDone.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

  @override
  void initState() {
    super.initState();
    _c.forward();
    Future.delayed(const Duration(milliseconds: 2750), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.seed,
      body: LayoutBuilder(
        builder: (context, cons) {
          final w = cons.maxWidth, h = cons.maxHeight;
          // 왼쪽 아래(화면 밖) → 위쪽 가운데(제어점) → 오른쪽 위(화면 밖)로 아치.
          final p0 = Offset(-0.05 * w, 0.85 * h);
          final p1 = Offset(0.50 * w, 0.34 * h);
          final p2 = Offset(1.12 * w, -0.06 * h);
          return AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final v = _c.value;
              // 비행기: 앞 72% 동안 경로 비행(easeInOut).
              final fly = Curves.easeInOut.transform((v / 0.72).clamp(0.0, 1.0));
              final pt = _bezier(fly, p0, p1, p2);
              final tan = _bezierTangent(fly, p0, p1, p2);
              final angle = atan2(tan.dy, tan.dx);
              // 제목: 45% 지점부터 페이드업.
              final titleT = Curves.easeOut.transform(((v - 0.45) / 0.55).clamp(0.0, 1.0));
              return Stack(
                children: [
                  Positioned.fill(
                    child: CustomPaint(painter: _TrailPainter(fly, p0, p1, p2)),
                  ),
                  Positioned(
                    left: pt.dx - 34,
                    top: pt.dy - 34,
                    child: Transform.rotate(
                      angle: angle + pi / 2, // Icons.flight는 위(북)를 향함 → 경로 접선에 맞춤.
                      child: const Icon(Icons.flight, size: 68, color: Colors.white),
                    ),
                  ),
                  Align(
                    alignment: const Alignment(0, 0.22),
                    child: Opacity(
                      opacity: titleT,
                      child: Transform.translate(
                        offset: Offset(0, (1 - titleT) * 18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text('P의 여행 플래너',
                                style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
                            SizedBox(height: 6),
                            Text('가볍게 떠나는 여행',
                                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

Offset _bezier(double t, Offset p0, Offset p1, Offset p2) {
  final u = 1 - t;
  return p0 * (u * u) + p1 * (2 * u * t) + p2 * (t * t);
}

Offset _bezierTangent(double t, Offset p0, Offset p1, Offset p2) {
  return (p1 - p0) * (2 * (1 - t)) + (p2 - p1) * (2 * t);
}

/// 비행기 뒤 점선 비행운(현재 위치까지).
class _TrailPainter extends CustomPainter {
  _TrailPainter(this.progress, this.p0, this.p1, this.p2);
  final double progress;
  final Offset p0, p1, p2;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.02) return;
    final path = Path()..moveTo(p0.dx, p0.dy);
    const steps = 64;
    final upTo = (steps * progress).round();
    for (int i = 1; i <= upTo; i++) {
      final o = _bezier(i / steps, p0, p1, p2);
      path.lineTo(o.dx, o.dy);
    }
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    const dash = 11.0, gap = 9.0;
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, min(d + dash, metric.length)), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_TrailPainter old) => old.progress != progress;
}
