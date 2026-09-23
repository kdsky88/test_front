import 'package:flutter/material.dart';
import '../theme.dart';
import 'cover_image.dart';

/// A bounded photo area keeps scenery independent of text size and card width.
class TravelCard extends StatelessWidget {
  const TravelCard({
    super.key,
    required this.title,
    required this.destination,
    required this.dateLabel,
    required this.cover,
    this.status,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.imageDestination,
  });
  final String title, destination, dateLabel;
  final String? status, imageDestination;
  final Color cover;
  final VoidCallback? onTap, onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: CoverImage(
                destination: imageDestination ?? destination,
                fallback: cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          destination,
                          style: theme.textTheme.headlineSmall,
                        ),
                      ),
                      if (onEdit != null || onDelete != null)
                        PopupMenuButton<String>(
                          tooltip: '$title 옵션',
                          onSelected: (value) {
                            if (value == 'edit') onEdit?.call();
                            if (value == 'delete') onDelete?.call();
                          },
                          itemBuilder: (_) => [
                            if (onEdit != null)
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('여행 수정'),
                              ),
                            if (onDelete != null)
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text('여행 삭제'),
                              ),
                          ],
                        ),
                    ],
                  ),
                  if (status != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status!,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (title != destination) ...[
                              Text(title, style: theme.textTheme.titleMedium),
                              const SizedBox(height: 8),
                            ],
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 16,
                                  color: scheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    dateLabel,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (onTap != null) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: scheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(
                              AppTheme.radius,
                            ),
                          ),
                          child: Icon(
                            Icons.arrow_outward,
                            size: 18,
                            color: scheme.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
