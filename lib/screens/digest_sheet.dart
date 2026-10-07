import 'package:flutter/material.dart';

import '../models/digest.dart';

/// The digest on wake (MainShell, via DigestGate) — what is still unread: the urgent items as LunAcedia ranks them
/// (with why), then its summary of the rest. A tap on an urgent item opens it; the model never says what is urgent.
Future<void> showDigestSheet(BuildContext context, Digest digest, {required void Function(String key) onOpen}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => _DigestSheet(
      digest: digest,
      onOpen: (key) {
        Navigator.of(sheetContext).pop();
        onOpen(key);
      },
    ),
  );
}

class _DigestSheet extends StatelessWidget {
  const _DigestSheet({required this.digest, required this.onOpen});

  final Digest digest;
  final void Function(String key) onOpen;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (_, scrollCtrl) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colors.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(Icons.auto_awesome_outlined, color: colors.primary, size: 20),
                const SizedBox(width: 8),
                Text('Digest', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                children: [
                  if (digest.urgent.isNotEmpty) ...[
                    Text('Urgent (${digest.urgent.length})',
                        style: text.labelLarge?.copyWith(color: colors.error, fontWeight: FontWeight.w600)),
                    for (final u in digest.urgent)
                      ListTile(
                        key: ValueKey('digest-urgent-${u.key}'),
                        contentPadding: EdgeInsets.zero,
                        title: Text(u.title),
                        subtitle: u.priorityReason == null ? null : Text(u.priorityReason!),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => onOpen(u.key),
                      ),
                    const SizedBox(height: 12),
                  ],
                  if (digest.summary.trim().isNotEmpty)
                    Text(digest.summary, style: const TextStyle(fontSize: 15, height: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
