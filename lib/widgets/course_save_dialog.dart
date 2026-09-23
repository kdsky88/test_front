import 'package:flutter/material.dart';
import '../state/course_save_notifier.dart';

class CourseSaveDialog extends StatefulWidget {
  const CourseSaveDialog({super.key, required this.names, required this.save});
  final List<String> names;
  final Future<String?> Function(int) save;
  @override
  State<CourseSaveDialog> createState() => _CourseSaveDialogState();
}

class _CourseSaveDialogState extends State<CourseSaveDialog> {
  late final state = CourseSaveNotifier(widget.names.length, widget.save);
  @override
  void initState() {
    super.initState();
    state.run();
  }

  @override
  void dispose() {
    state.dispose();
    super.dispose();
  }

  Future<void> _retry() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('실패한 장소만 다시 저장할까요?'),
        content: const Text(
          '응답이 끊긴 경우 이미 저장됐을 수 있어요. 확실하지 않다면 취소한 뒤 일정 목록을 먼저 확인해주세요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('다시 저장'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await state.run();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) => PopScope(
      canPop: !state.busy,
      child: AlertDialog(
        title: Text(state.busy ? '일정에 담는 중' : '저장 결과'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                liveRegion: true,
                child: Text('${state.count}곳 중 ${state.saved.length}곳 저장됨'),
              ),
              if (state.busy) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: state.count == 0 ? 0 : state.attempted / state.count,
                ),
              ],
              for (final entry in state.errors.entries) ...[
                const SizedBox(height: 12),
                Text(
                  widget.names[entry.key],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(entry.value),
              ],
              if (!state.busy && state.errors.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text('연결이 끊겼다면 일정 목록에서 저장 여부를 먼저 확인해주세요.'),
              ],
            ],
          ),
        ),
        actions: [
          if (!state.busy && state.errors.isNotEmpty)
            TextButton(onPressed: _retry, child: const Text('실패한 장소만 재시도')),
          FilledButton(
            onPressed: state.busy ? null : () => Navigator.pop(context),
            child: const Text('일정 확인'),
          ),
        ],
      ),
    ),
  );
}
