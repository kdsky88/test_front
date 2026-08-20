import 'package:flutter/material.dart';
import '../theme.dart';

/// 시작 스플래시: 코럴 배경에 로고(✈️) 팝인 + 앱 이름 페이드업. 끝나면 onDone.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  late final Animation<double> _logoScale =
      Tween<double>(begin: 0.6, end: 1.0).animate(
    CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack)),
  );
  late final Animation<double> _logoFade =
      CurvedAnimation(parent: _c, curve: const Interval(0.0, 0.55, curve: Curves.easeOut));
  late final CurvedAnimation _text =
      CurvedAnimation(parent: _c, curve: const Interval(0.4, 1.0, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    _c.forward();
    // 애니메이션 감상 후 앱으로 전환.
    Future.delayed(const Duration(milliseconds: 1900), () {
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
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _logoFade,
              child: ScaleTransition(
                scale: _logoScale,
                child: Container(
                  width: 116,
                  height: 116,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Text('✈️', style: TextStyle(fontSize: 58)),
                ),
              ),
            ),
            const SizedBox(height: 22),
            FadeTransition(
              opacity: _text,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, 0.35), end: Offset.zero).animate(_text),
                child: Column(
                  children: const [
                    Text('여행 플래너',
                        style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w800)),
                    SizedBox(height: 6),
                    Text('가볍게 떠나는 여행',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
