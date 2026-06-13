import 'package:flutter/material.dart';
import '../models/todo.dart';

class PriorityBadge extends StatelessWidget {
  const PriorityBadge({super.key, required this.priority});

  final TodoPriority priority;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = switch (priority) {
      TodoPriority.high => (Colors.red.shade100, Colors.red.shade800),
      TodoPriority.medium => (Colors.orange.shade100, Colors.orange.shade900),
      TodoPriority.low => (Colors.blue.shade100, Colors.blue.shade800),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(4)),
      child: Text(
        priority.label,
        style: TextStyle(fontSize: 11, color: foreground, fontWeight: FontWeight.w600),
      ),
    );
  }
}
