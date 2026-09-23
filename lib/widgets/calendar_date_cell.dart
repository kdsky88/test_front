import 'package:flutter/material.dart';

class CalendarDateCell extends StatelessWidget {
  const CalendarDateCell({
    super.key,
    required this.date,
    required this.count,
    required this.selected,
    required this.enabled,
    required this.today,
    required this.onTap,
  });
  final DateTime date;
  final int count;
  final bool selected, enabled, today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      onTap: enabled ? onTap : null,
      button: true,
      selected: selected,
      enabled: enabled,
      label: '${date.month}월 ${date.day}일${today ? ', 오늘' : ''}, 일정 $count개',
      child: ExcludeSemantics(
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 72),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: selected && enabled ? scheme.primary : null,
                      borderRadius: BorderRadius.circular(12),
                      border: today && !selected
                          ? Border.all(color: scheme.primary)
                          : null,
                    ),
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: today || selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: !enabled
                            ? scheme.outline
                            : selected
                            ? scheme.onPrimary
                            : scheme.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      enabled && count > 0 ? '$count건' : ' ',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
