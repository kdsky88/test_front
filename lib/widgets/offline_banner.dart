import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OfflineBanner extends StatelessWidget {
  const OfflineBanner({
    super.key,
    this.lastSynced,
    this.onRetry,
    this.retrying = false,
  });
  final DateTime? lastSynced;
  final VoidCallback? onRetry;
  final bool retrying;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final time = lastSynced == null
        ? '저장 시각을 알 수 없어요'
        : '마지막 저장 ${DateFormat('M/d HH:mm').format(lastSynced!.toLocal())}';
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity,
        color: scheme.secondaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(
              Icons.cloud_off_outlined,
              size: 20,
              color: scheme.onSecondaryContainer,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '오프라인 · 조회만 가능\n$time',
                style: TextStyle(color: scheme.onSecondaryContainer),
              ),
            ),
            if (onRetry != null)
              TextButton(
                onPressed: retrying ? null : onRetry,
                child: Text(retrying ? '연결 중' : '다시 연결'),
              ),
          ],
        ),
      ),
    );
  }
}
