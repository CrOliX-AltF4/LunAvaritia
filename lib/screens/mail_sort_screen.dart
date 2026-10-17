import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/mail_sort.dart';
import '../providers/box_controller.dart';
import '../providers/shell_controller.dart';
import '../services/backend_client.dart';
import '../theme/app_theme.dart';

/// Sorting mail (maquette du 2026-10-17): each class with its three switches, the personal senders, the rules that
/// classify. Every change is saved at LunAcedia at once; nothing is decided here.
class MailSortScreen extends StatefulWidget {
  const MailSortScreen({super.key});

  @override
  State<MailSortScreen> createState() => _MailSortScreenState();
}

const _switches = [('visible', 'Boîte'), ('ai', "Lu par l'IA"), ('rings', 'Sonne')];

class _MailSortScreenState extends State<MailSortScreen> {
  MailSortConfig? _config;
  List<SortRule> _rules = [];
  int _kept = 0;
  String? _error;
  final _sender = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _sender.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final api = context.read<BackendClient>().mailSort;
    try {
      final config = await api.config();
      final rules = await api.rules();
      final kept = await api.keptOut(rules.names);
      if (!mounted) return;
      setState(() {
        _config = config;
        _rules = rules.rules;
        _kept = kept.total;
        _error = null;
      });
    } on BackendError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  /// A change saved at LunAcedia — the screen shows what it answered; a refusal is said and nothing moves.
  Future<void> _save(Future<void> Function(BackendClient api) change) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await change(context.read<BackendClient>());
      // The class of what the box shows may have changed: the box is read again.
      if (mounted) unawaited(context.read<BoxController>().load());
    } on BackendError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Pas enregistré : ${e.message}')));
    }
    await _load();
  }

  void _addSender() {
    final s = _sender.text.trim();
    if (s.isEmpty || _config == null) return;
    _sender.clear();
    unawaited(_save((api) => api.mailSort.setPersonalSenders([..._config!.personalSenders, s])));
  }

  @override
  Widget build(BuildContext context) {
    final shell = context.read<ShellController>();
    final config = _config;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Retour aux réglages',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => shell.go(const SettingsDestination()),
        ),
        titleSpacing: 0,
        title: const Text('Tri des mails'),
      ),
      body: config == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Text(_error!, textAlign: TextAlign.center, style: da(color: Palette.lune)),
                        const SizedBox(height: 16),
                        OutlinedButton(onPressed: _load, child: const Text('Réessayer')),
                      ]),
                    ),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              children: [
                Text(
                  "Chaque mail est classé à l'arrivée, sans aucune IA : d'après Gmail, tes expéditeurs perso et tes "
                  'règles. Une classe « hors IA » n\'est lue par aucun modèle — ni Natsume, ni l\'assistant.',
                  style: da(size: 13, color: Palette.lune, height: 1.5),
                ),
                const SizedBox(height: 18),
                _classesHeader(),
                for (final c in MailClass.values) _classRow(c, config.classes[c]!),
                const SizedBox(height: 8),
                Text(
                  'Retiré de la boîte = gardé à part, récupérable. « Sonne » s\'ajoute au filtre de priorité ; un VIP '
                  "n'est jamais retiré.",
                  style: da(size: 12, color: Palette.brume),
                ),
                const SizedBox(height: 22),
                Text('Expéditeurs perso', style: da(family: serif, size: 20, weight: 600)),
                const SizedBox(height: 4),
                Text('Un nom, une adresse ou une partie (« @famille.fr »).', style: da(size: 12.5, color: Palette.brume)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final s in config.personalSenders)
                    InputChip(
                      label: Text(s),
                      onDeleted: () => _save((api) =>
                          api.mailSort.setPersonalSenders(config.personalSenders.where((x) => x != s).toList())),
                      deleteButtonTooltipMessage: 'Retirer $s',
                    ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _sender,
                      decoration: const InputDecoration(labelText: 'Nouvel expéditeur perso', hintText: 'Ajouter…'),
                      onSubmitted: (_) => _addSender(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(onPressed: _addSender, child: const Text('Ajouter')),
                ]),
                const SizedBox(height: 22),
                Text('Règles qui classent', style: da(family: serif, size: 20, weight: 600)),
                const SizedBox(height: 4),
                if (_rules.isEmpty)
                  Text('Aucune — un geste « Classer… » sur un mail en crée une.', style: da(size: 13, color: Palette.brume)),
                for (final r in _rules)
                  SwitchListTile(
                    key: ValueKey('sort-rule-${r.id}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text('${r.when} → ${r.mailClass.label}', style: da(size: 14)),
                    value: r.enabled,
                    onChanged: (v) => _save((api) => api.mailSort.setRule(r.id, v)),
                  ),
                Text(
                  'Une règle naît d\'un geste « Classer… » sur un mail. Les modifier en détail : tableau de bord de LunAcedia.',
                  style: da(size: 12, color: Palette.brume),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Gardés hors de la boîte'),
                  trailing: Text('$_kept ›', style: da(size: 14, color: Palette.brume)),
                  onTap: () => shell.go(const KeptOutDestination()),
                ),
                const Divider(height: 1),
              ],
            ),
    );
  }

  Widget _classesHeader() => Container(
        padding: const EdgeInsets.only(bottom: 6),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Palette.filet))),
        child: Row(children: [
          Expanded(child: Text('Classe', style: da(size: 11.5, color: Palette.brume))),
          for (final (_, label) in _switches)
            SizedBox(width: 60, child: Text(label, textAlign: TextAlign.center, style: da(size: 11.5, color: Palette.brume))),
        ]),
      );

  Widget _classRow(MailClass c, ClassSettings s) {
    final count = _config?.counts[c] ?? 0;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: Palette.filet))),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.label, style: da(size: 14.5)),
            Text('${c.how}${s.ai ? '' : ' · hors IA'} · $count en 7 j', style: da(size: 12, color: Palette.brume)),
          ]),
        ),
        for (final (key, label) in _switches)
          SizedBox(
            width: 60,
            child: Checkbox(
              key: ValueKey('class-${c.name}-$key'),
              value: s.of(key),
              semanticLabel: '${c.label} — $label',
              onChanged: (v) => _save((api) => api.mailSort.setClass(c, key, v ?? false)),
            ),
          ),
      ]),
    );
  }
}

/// What was kept out of the box — by a rule or by its class — each with why, restorable.
class KeptOutScreen extends StatefulWidget {
  const KeptOutScreen({super.key});

  @override
  State<KeptOutScreen> createState() => _KeptOutScreenState();
}

class _KeptOutScreenState extends State<KeptOutScreen> {
  List<KeptOut>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final api = context.read<BackendClient>().mailSort;
    try {
      final rules = await api.rules();
      final kept = await api.keptOut(rules.names);
      if (mounted) setState(() => _items = kept.items);
    } on BackendError catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _restore(KeptOut k) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<BackendClient>().mailSort.restore(k.key);
      if (mounted) unawaited(context.read<BoxController>().load());
      setState(() => _items = _items?.where((x) => x.key != k.key).toList());
    } on BackendError catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Pas restauré : ${e.message}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Retour au tri',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.read<ShellController>().go(const MailSortDestination()),
        ),
        titleSpacing: 0,
        title: const Text('Gardés hors de la boîte'),
      ),
      body: items == null
          ? Center(
              child: _error == null
                  ? const CircularProgressIndicator()
                  : Text(_error!, style: da(color: Palette.lune)),
            )
          : items.isEmpty
              ? Center(child: Text("Rien n'est gardé hors de la boîte.", style: da(color: Palette.lune)))
              : ListView(children: [
                  for (final k in items)
                    ListTile(
                      title: Text(k.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${k.from} · ${k.why}', style: da(size: 12.5, color: Palette.brume)),
                      trailing: TextButton(onPressed: () => _restore(k), child: const Text('Restaurer')),
                    ),
                ]),
    );
  }
}
