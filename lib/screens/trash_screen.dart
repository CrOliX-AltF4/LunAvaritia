import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/box_item.dart';
import '../providers/box_controller.dart';
import '../providers/shell_controller.dart';
import '../services/backend_error.dart';
import '../theme/app_theme.dart';
import '../widgets/box_widgets.dart';

/// Gmail's trash (DA-M4): Gmail keeps each mail 30 days, LunAcedia stores nothing. « Restaurer » puts it back in the
/// inbox at the source; it comes back to the box at LunAcedia's next pass.
class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  List<TrashItem>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final items = await context.read<BoxController>().trash();
      if (mounted) setState(() => _items = items);
    } on BackendError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _restore(TrashItem t) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<BoxController>().restore(t.id);
      if (mounted) setState(() => _items = _items?.where((i) => i.id != t.id).toList());
      messenger.showSnackBar(const SnackBar(content: Text('Restauré — il revient dans la boîte au prochain passage.')));
    } on BackendError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Restaurer : ${e.message}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Retour à la boîte',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.read<ShellController>().go(const BoxDestination()),
        ),
        titleSpacing: 0,
        title: const Text('Corbeille'),
      ),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'La corbeille de Gmail : il garde chaque mail 30 jours. Restaurer le remet dans la boîte de réception, '
              'et il revient ici au prochain passage.',
              style: da(size: 13, color: Palette.lune, height: 1.5),
            ),
          ),
          if (_error != null)
            Padding(padding: const EdgeInsets.all(16), child: Text(_error!, style: da(color: Palette.lune)))
          else if (items == null)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Center(child: Text('La corbeille est vide.', style: da(color: Palette.lune))),
            )
          else
            for (final t in items)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(border: Border(top: BorderSide(color: Palette.filet))),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(senderName(t.from), style: da(size: 13, color: Palette.lune))),
                              Text(boxTime(t.ts), style: da(size: 12, color: Palette.lune)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: da()),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton(onPressed: () => _restore(t), child: const Text('Restaurer')),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}
