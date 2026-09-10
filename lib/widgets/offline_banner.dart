import 'package:flutter/material.dart';

/// 네트워크가 안 될 때 캐시된 내용을 보여주는 중임을 알리는 얇은 배너.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.cloud_off_outlined, size: 16, color: scheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Text(
            '오프라인 · 저장된 내용을 표시 중',
            style: TextStyle(fontSize: 13, color: scheme.onSecondaryContainer),
          ),
        ],
      ),
    );
  }
}
