import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../models/alert.dart';

class AlertCard extends StatelessWidget {
  const AlertCard({super.key, required this.alert, required this.onMarkRead});

  final Alert        alert;
  final VoidCallback onMarkRead;

  static const _sourceIcon = {
    AlertSource.email:    Icons.email_outlined,
    AlertSource.calendar: Icons.event_outlined,
    AlertSource.tasks:    Icons.check_circle_outline,
    AlertSource.github:   Icons.code_rounded,
    AlertSource.discord:  Icons.chat_bubble_outline,
    AlertSource.rss:      Icons.rss_feed_rounded,
    AlertSource.ha:       Icons.home_outlined,
    AlertSource.system:   Icons.info_outline,
  };

  static const _sourceLabel = {
    AlertSource.email:    'Email',
    AlertSource.calendar: 'Agenda',
    AlertSource.tasks:    'Tâche',
    AlertSource.github:   'GitHub',
    AlertSource.discord:  'Discord',
    AlertSource.rss:      'RSS',
    AlertSource.ha:       'HA',
    AlertSource.system:   'Système',
  };

  Color _priorityColor(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return switch (alert.priority) {
      AlertPriority.urgent => colors.error,
      AlertPriority.normal => colors.primary,
      AlertPriority.info   => colors.outline,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors    = Theme.of(context).colorScheme;
    final priColor  = _priorityColor(context);
    final isUnread  = !alert.read;

    return InkWell(
      onTap: alert.url != null ? () {/* open URL */} : null,
      child: Container(
        decoration: BoxDecoration(
          color: isUnread ? colors.surfaceContainerHigh : colors.surface,
          border: Border(left: BorderSide(color: priColor, width: 3)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Source icon
            Icon(
              _sourceIcon[alert.source] ?? Icons.info_outline,
              size: 20,
              color: priColor,
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Chip(
                        label: Text(
                          _sourceLabel[alert.source] ?? 'Autre',
                          style: const TextStyle(fontSize: 10),
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      const Spacer(),
                      Text(
                        timeago.format(alert.ts, locale: 'fr'),
                        style: TextStyle(fontSize: 11, color: colors.outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    alert.title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                      color: colors.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (alert.body != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      alert.body!,
                      style: TextStyle(fontSize: 12, color: colors.outline),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            // Quick action
            if (isUnread)
              IconButton(
                icon: const Icon(Icons.mark_email_read_outlined, size: 18),
                onPressed: onMarkRead,
                tooltip: 'Marquer comme lu',
                color: colors.primary,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }
}
