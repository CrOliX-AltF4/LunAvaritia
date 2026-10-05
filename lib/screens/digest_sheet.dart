import 'package:flutter/material.dart';

/// The digest on wake (MainShell, via DigestGate) — LunAcedia's summary of what came in.
Future<void> showDigestSheet(BuildContext context, String digest) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _DigestSheet(digest: digest),
  );
}

class _DigestSheet extends StatelessWidget {
  const _DigestSheet({required this.digest});

  final String digest;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

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
                Text(
                  'Digest',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                controller: scrollCtrl,
                child: Text(digest, style: const TextStyle(fontSize: 15, height: 1.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
