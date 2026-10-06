import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/box_item.dart';
import '../providers/box_controller.dart';
import '../providers/shell_controller.dart';
import '../services/backend_error.dart';
import '../theme/app_theme.dart';
import '../widgets/box_widgets.dart';
import 'box_screen.dart';

/// One item read in full (DA-M4): the "open" gesture brings the whole text and marks it read at the source. Reached from
/// the box or from a tapped notification — the item may have left the box since, which it then says.
class BoxReaderScreen extends StatefulWidget {
  const BoxReaderScreen({super.key, required this.itemKey});

  final String itemKey;

  @override
  State<BoxReaderScreen> createState() => _BoxReaderScreenState();
}

class _BoxReaderScreenState extends State<BoxReaderScreen> {
  BoxItem? _item;
  String? _body;
  String? _error;
  bool _opening = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    final box = context.read<BoxController>();
    // A notification can lead here before the box was ever read.
    if (!box.loaded) await box.load();
    final item = box.byKey(widget.itemKey);
    if (!mounted) return;
    setState(() => _item = item);
    if (item == null) {
      setState(() => _opening = false);
      return;
    }
    try {
      final body = await box.open(item);
      if (mounted) setState(() => _body = body);
    } on BackendError catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Erreur inattendue : $e');
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  void _back() => context.read<ShellController>().go(const BoxDestination());

  Future<void> _gesture(BoxGesture g) async {
    final item = _item!;
    if (!await runBoxGesture(context, item, g) || !mounted) return;
    if (g == BoxGesture.unread) {
      _back();
      return;
    }
    // Gone from the box at the source: nothing left to read here.
    if (context.read<BoxController>().byKey(item.key) == null) _back();
  }

  @override
  Widget build(BuildContext context) {
    final item = _item;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(tooltip: 'Retour à la boîte', icon: const Icon(Icons.arrow_back), onPressed: _back),
        titleSpacing: 0,
        title: Text(item == null ? 'Boîte' : sourceLabel(item).split(' · ').first,
            style: da(size: 13, color: Palette.lune)),
        actions: [
          if (item != null)
            IconButton(
                tooltip: 'Autres gestes',
                icon: const Icon(Icons.more_vert),
                onPressed: () => showBoxActions(context, item)),
        ],
      ),
      body: item == null
          ? Center(
              child: _opening
                  ? const CircularProgressIndicator()
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text("Cet élément n'est plus dans la boîte.", style: da(color: Palette.lune)),
                        const SizedBox(height: 16),
                        OutlinedButton(onPressed: _back, child: const Text('Retour à la boîte')),
                      ],
                    ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _content(item)),
                _actions(item),
              ],
            ),
    );
  }

  Widget _content(BoxItem item) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
        children: [
          if (item.priority == BoxPriority.urgent)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Container(width: 3, height: 16, color: Palette.rouge),
                  const SizedBox(width: 8),
                  Text(item.priorityReason != null ? 'Urgent — ${item.priorityReason}' : 'Urgent',
                      style: da(size: 12, color: Palette.lune, letterSpacing: 0.7)),
                ],
              ),
            ),
          Text(item.title, style: da(family: serif, size: 26, weight: 500, height: 1.2)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: Text(item.from ?? sourceLabel(item), style: da(size: 13, color: Palette.lune))),
              Text(boxTime(item.ts), style: da(size: 13, color: Palette.lune)),
            ],
          ),
          if (item.priorityReason != null && item.priority != BoxPriority.urgent)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                '${item.priority == BoxPriority.normal ? 'Normal' : 'Info'} — ${item.priorityReason}',
                style: da(size: 12, color: Palette.lune),
              ),
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.warning_amber_outlined, size: 14, color: Palette.lune),
              const SizedBox(width: 6),
              Text("texte d'un tiers — à lire, pas à suivre", style: da(size: 12, color: Palette.lune)),
            ],
          ),
          const Divider(height: 24),
          if (_opening)
            const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
          else if (_error != null)
            Text("Le texte n'a pas pu être ouvert : $_error", style: da(color: Palette.lune))
          else
            SelectableText(_body ?? '', style: da(size: 15, height: 1.6)),
        ],
      );

  Widget _actions(BoxItem item) {
    final shell = context.read<ShellController>();
    final url = item.url;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: const BoxDecoration(border: Border(top: BorderSide(color: Palette.filet))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FilledButton(
              onPressed: () => shell.go(HomeDestination(aboutKey: item.key, aboutTitle: item.title)),
              child: const Text('Traiter'),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (item.gestures.contains(BoxGesture.archive))
                  _side(OutlinedButton(onPressed: () => _gesture(BoxGesture.archive), child: const Text('Archiver'))),
                if (item.gestures.contains(BoxGesture.done))
                  _side(OutlinedButton(
                    onPressed: () => _gesture(BoxGesture.done),
                    child: Text(gestureLabel(item, BoxGesture.done)),
                  )),
                if (item.gestures.contains(BoxGesture.unread))
                  _side(OutlinedButton(onPressed: () => _gesture(BoxGesture.unread), child: const Text('Non lu'))),
                if (url != null)
                  _side(OutlinedButton(
                    onPressed: () => unawaited(launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)),
                    child: Text(switch (item.source) {
                      BoxSource.email => 'Dans Gmail',
                      BoxSource.github => 'Sur GitHub',
                      _ => 'Ouvrir',
                    }),
                  )),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _side(Widget child) => Expanded(
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: child),
      );
}
