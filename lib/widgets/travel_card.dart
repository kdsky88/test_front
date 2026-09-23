import 'package:flutter/material.dart';
import '../theme.dart';
import 'cover_image.dart';

/// Shared travel cover: image, destination, then readable itinerary details.
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
            Stack(
              children: [
                Positioned.fill(
                  child: CoverImage(
                    destination: imageDestination,
                    fallback: cover,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (status != null)
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(30),
                                ),
                                child: Text(
                                  status!,
                                  style: const TextStyle(
                                    color: Color(0xFF294A3E),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          if (status == null) const SizedBox.shrink(),
                          if (onEdit != null || onDelete != null)
                            PopupMenuButton<String>(
                              tooltip: '$title 옵션',
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0x33FFFFFF),
                                foregroundColor: Colors.white,
                              ),
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
                      const SizedBox(height: 42),
                      const Icon(
                        Icons.near_me_outlined,
                        color: Color(0xCCFFFFFF),
                        size: 20,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        destination,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: theme.textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
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
                                  color: scheme.onSurfaceVariant,
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
                        borderRadius: BorderRadius.circular(AppTheme.radius),
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
            ),
          ],
        ),
      ),
    );
  }
}
