import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/alert.dart';
import '../providers/alert_provider.dart';
import '../widgets/alert_card.dart';

class AlertFeedScreen extends StatefulWidget {
  const AlertFeedScreen({super.key});

  @override
  State<AlertFeedScreen> createState() => _AlertFeedScreenState();
}

class _AlertFeedScreenState extends State<AlertFeedScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AlertProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AlertProvider>();
    final colors   = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: Row(
          children: [
            const Text('Alertes', style: TextStyle(fontWeight: FontWeight.w600)),
            if (provider.unreadCount > 0) ...[
              const SizedBox(width: 8),
              Badge(label: Text('${provider.unreadCount}')),
            ],
          ],
        ),
        actions: [
          if (provider.unreadCount > 0)
            TextButton.icon(
              onPressed: provider.markAllRead,
              icon: const Icon(Icons.done_all, size: 18),
              label: const Text('Tout lire'),
            ),
        ],
      ),
      body: Column(
        children: [
          _FilterBar(current: provider.filter, onSelected: provider.setFilter),
          Expanded(child: _Body(provider: provider)),
        ],
      ),
    );
  }
}

// ── Filter chips ──────────────────────────────────────────────────────────────

class _FilterBar extends StatelessWidget {
  const _FilterBar({required this.current, required this.onSelected});

  final AlertFilter           current;
  final void Function(AlertFilter) onSelected;

  static const _labels = {
    AlertFilter.all:      ('Tout',      null),
    AlertFilter.urgent:   ('Urgent',    Icons.priority_high),
    AlertFilter.email:    ('Email',     Icons.email_outlined),
    AlertFilter.calendar: ('Agenda',    Icons.event_outlined),
    AlertFilter.tasks:    ('Tâches',    Icons.check_circle_outline),
  };

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: _labels.entries.map((e) {
          final (label, icon) = e.value;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              selected: current == e.key,
              label: Text(label),
              avatar: icon != null ? Icon(icon, size: 16) : null,
              onSelected: (_) => onSelected(e.key),
              visualDensity: VisualDensity.compact,
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _Body extends StatelessWidget {
  const _Body({required this.provider});

  final AlertProvider provider;

  @override
  Widget build(BuildContext context) {
    if (provider.loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(provider.error!, style: const TextStyle(fontSize: 15)),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: provider.refresh,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    final alerts = provider.alerts;
    if (alerts.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_rounded, size: 56, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            const Text('Aucune alerte', style: TextStyle(fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: alerts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 1),
        itemBuilder: (ctx, i) {
          final alert = alerts[i];
          return Dismissible(
            key: ValueKey(alert.id),
            direction: DismissDirection.startToEnd,
            background: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20),
              color: Theme.of(ctx).colorScheme.primaryContainer,
              child: const Icon(Icons.mark_email_read_outlined),
            ),
            onDismissed: (_) => provider.markRead(alert.id),
            child: AlertCard(alert: alert, onMarkRead: () => provider.markRead(alert.id)),
          );
        },
      ),
    );
  }
}
