import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/validation_controller.dart';
import '../services/validation_api.dart';
import '../theme/app_theme.dart';
import '../widgets/shell_widgets.dart';
import 'topic_screen.dart' show expiresIn;

/// « À valider » (maquette DA1): the hub's memory questions (wired) — Retenir, Modifier, Écarter, or the answer to a
/// contradiction or a near repeat — what it wrote without asking, with Annuler, and LunAcedia's pending writes —
/// Confirmer, Annuler — each with what it would do and when it expires.
class ValidateScreen extends StatefulWidget {
  const ValidateScreen({super.key});

  @override
  State<ValidateScreen> createState() => _ValidateScreenState();
}

class _ValidateScreenState extends State<ValidateScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(context.read<ValidationController>().load());
    });
  }

  void _say(String? error, String what) {
    if (error == null || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$what : $error')));
  }

  @override
  Widget build(BuildContext context) {
    final v = context.watch<ValidationController>();
    return Scaffold(
      appBar: AppBar(leading: const MenuButton(), titleSpacing: 0, title: const Text('À valider')),
      body: RefreshIndicator(
        onRefresh: v.load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
          children: [
            if (!v.loaded) const Center(child: CircularProgressIndicator()),
            if (v.error != null) Text(v.error!, style: da(color: Palette.lune)),
            if (v.proposals.isNotEmpty) ...[
              const _Title('Pour la mémoire'),
              for (final p in v.proposals)
                _ProposalCard(key: ValueKey('proposal-${p.id}'), proposal: p, onError: (e) => _say(e, 'Mémoire')),
              const SizedBox(height: 20),
            ],
            if (v.unasked.isNotEmpty) ...[
              const _Title('Écrits sans demander'),
              for (final f in v.unasked)
                _UnaskedCard(key: ValueKey('unasked-${f.id}'), fact: f, onError: (e) => _say(e, 'Mémoire')),
              const SizedBox(height: 20),
            ],
            if (v.writes.isNotEmpty) ...[
              const _Title('Actions'),
              for (final w in v.writes)
                _WriteCard(key: ValueKey('write-${w.id}'), write: w, onError: (e) => _say(e, 'Rien n’a été fait')),
            ],
            if (v.loaded && v.count == 0)
              Text(
                'Rien en attente. Les actions se confirment aussi dans leur sujet ou depuis leur notification.',
                style: da(size: 13, color: Palette.lune, height: 1.5),
              ),
          ],
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(text, style: da(size: 12, color: Palette.lune, letterSpacing: 0.7)),
      );
}

BoxDecoration get _card => BoxDecoration(
      border: Border.all(color: Palette.filetFort),
      borderRadius: BorderRadius.circular(10),
    );

class _ProposalCard extends StatefulWidget {
  // Keyed by the proposal: a card being reworded must not hand its draft to the next one when it leaves.
  const _ProposalCard({super.key, required this.proposal, required this.onError});
  final MemoryProposal proposal;
  final ValueChanged<String?> onError;

  @override
  State<_ProposalCard> createState() => _ProposalCardState();
}

class _ProposalCardState extends State<_ProposalCard> {
  TextEditingController? _edit;
  bool _busy = false;

  @override
  void dispose() {
    _edit?.dispose();
    super.dispose();
  }

  Future<void> _act(Future<String?> Function(ValidationController v) step) async {
    setState(() => _busy = true);
    final error = await step(context.read<ValidationController>());
    if (mounted) setState(() => _busy = false);
    widget.onError(error);
  }

  /// A question's two answers — each says what it does (the hub does the gesture: replace, or leave as it was).
  List<Widget> _answers(MemoryProposal p, {required String keep, required String drop}) => [
        Expanded(
          child: OutlinedButton(onPressed: _busy ? null : () => _act((v) => v.approve(p)), child: Text(keep)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextButton(onPressed: _busy ? null : () => _act((v) => v.reject(p)), child: Text(drop)),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final p = widget.proposal;
    final edit = _edit;
    // A question (contradiction, near repeat) has its own two answers; nothing to reword there.
    final answers = edit != null
        ? null
        : p.conflictText != null
            ? _answers(p, keep: 'Le nouveau est juste', drop: 'L’ancien est juste')
            : p.duplicateText != null
                ? _answers(p, keep: 'Différent, retenir', drop: 'Même chose')
                : null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (edit == null)
            Text('« ${p.text} »', style: da(family: serif, size: 18, style: FontStyle.italic, height: 1.4))
          else
            TextField(
                controller: edit, maxLines: null, decoration: const InputDecoration(labelText: 'Texte à retenir')),
          if (edit == null && (p.conflictText ?? p.duplicateText) != null) ...[
            const SizedBox(height: 6),
            Text(
              p.conflictText != null
                  ? 'Contredit : « ${p.conflictText} » — le retenir remplace l’ancien.'
                  : 'Ressemble à : « ${p.duplicateText} » — est-ce la même chose ?',
              style: da(size: 12.5, color: Palette.lune, height: 1.4),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: answers ?? (edit == null
                ? [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => _act((v) => v.approve(p)),
                        child: const Text('Retenir'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _busy ? null : () => setState(() => _edit = TextEditingController(text: p.editableText)),
                        child: const Text('Modifier'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextButton(
                        onPressed: _busy ? null : () => _act((v) => v.reject(p)),
                        child: const Text('Écarter'),
                      ),
                    ),
                  ]
                : [
                    Expanded(
                      child: FilledButton(
                        onPressed:
                            _busy || edit.text.trim().isEmpty ? null : () => _act((v) => v.approve(p, text: edit.text)),
                        child: const Text('Retenir ce texte'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(onPressed: () => setState(() => _edit = null), child: const Text('Annuler')),
                  ]),
          ),
        ],
      ),
    );
  }
}

class _UnaskedCard extends StatefulWidget {
  const _UnaskedCard({super.key, required this.fact, required this.onError});
  final UnaskedFact fact;
  final ValueChanged<String?> onError;

  @override
  State<_UnaskedCard> createState() => _UnaskedCardState();
}

class _UnaskedCardState extends State<_UnaskedCard> {
  bool _busy = false;

  Future<void> _undo() async {
    setState(() => _busy = true);
    final error = await context.read<ValidationController>().undo(widget.fact);
    if (mounted) setState(() => _busy = false);
    widget.onError(error);
  }

  @override
  Widget build(BuildContext context) {
    final f = widget.fact;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(f.text, style: da(size: 15)),
          if (f.source != null) ...[
            const SizedBox(height: 6),
            Text('Tu avais dit : « ${f.source} »', style: da(size: 12, color: Palette.lune, style: FontStyle.italic)),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: _busy ? null : _undo, child: const Text('Annuler')),
          ),
        ],
      ),
    );
  }
}

class _WriteCard extends StatefulWidget {
  const _WriteCard({super.key, required this.write, required this.onError});
  final PendingWrite write;
  final ValueChanged<String?> onError;

  @override
  State<_WriteCard> createState() => _WriteCardState();
}

class _WriteCardState extends State<_WriteCard> {
  bool _busy = false;

  Future<void> _decide(bool confirm) async {
    setState(() => _busy = true);
    final error = await context.read<ValidationController>().decide(widget.write, confirm: confirm);
    if (mounted) setState(() => _busy = false);
    widget.onError(error);
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.write;
    final left = w.expiresAt?.difference(DateTime.now());
    final meta = [
      w.byAgent ? 'proposé par l’agent' : w.connector,
      if (left != null) 'expire dans ${expiresIn(left)}',
      if (w.untrusted) 'après un texte d’un tiers',
    ].join(' · ');
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(w.summary, style: da(size: 15)),
          const SizedBox(height: 6),
          Text(meta, style: da(size: 12, color: Palette.lune)),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: FilledButton(onPressed: _busy ? null : () => _decide(true), child: const Text('Confirmer')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(onPressed: _busy ? null : () => _decide(false), child: const Text('Annuler')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
