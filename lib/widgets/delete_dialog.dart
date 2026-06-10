import 'package:flutter/material.dart';

class DeleteDialog extends StatefulWidget {
  final String todoTitle;
  final Future<bool> Function() onDelete;

  const DeleteDialog({super.key, required this.todoTitle, required this.onDelete});

  @override
  State<DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<DeleteDialog> {
  bool _deleting = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: const Text('Todo 삭제'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text.rich(
            TextSpan(children: [
              TextSpan(
                text: '"${widget.todoTitle}"',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const TextSpan(text: ' 항목을 삭제합니다.'),
            ]),
          ),
          const SizedBox(height: 8),
          Text(
            '삭제한 Todo는 복구할 수 없습니다.',
            style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _deleting ? null : () => Navigator.of(context).pop(),
          child: const Text('취소'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
          onPressed: _deleting ? null : _handleDelete,
          child: _deleting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('삭제'),
        ),
      ],
    );
  }

  Future<void> _handleDelete() async {
    setState(() => _deleting = true);
    final ok = await widget.onDelete();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _deleting = false);
    }
  }
}
