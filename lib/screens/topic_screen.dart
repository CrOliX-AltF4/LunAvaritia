import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../models/topic.dart';
import '../providers/shell_controller.dart';
import '../providers/topic_controller.dart';
import '../providers/topics_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/shell_widgets.dart';

/// The topic in progress (DA1 « Sujet en cours »): the answers with what they cite and what they wait on.
class TopicScreen extends StatefulWidget {
  const TopicScreen({super.key});

  @override
  State<TopicScreen> createState() => _TopicScreenState();
}

class _TopicScreenState extends State<TopicScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    final controller = context.read<TopicController>();
    if (controller.messages.isEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => controller.load());
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final controller = context.read<TopicController>();
    final topics = context.read<TopicsProvider>();
    final text = _input.text;
    if (text.trim().isEmpty) return;
    _input.clear();
    final topic = await controller.send(text);
    if (topic != null) topics.touched(topic);
    if (controller.unsent != null && _input.text.isEmpty) _input.text = controller.unsent!;
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<TopicController>();
    final topic = controller.topic ?? context.watch<TopicsProvider>().byId(controller.topicId);

    return Scaffold(
      appBar: AppBar(
        leading: const MenuButton(),
        titleSpacing: 0,
        title: Text(topic?.title ?? '…', maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (topic != null)
            IconButton(
              tooltip: 'Actions du sujet',
              icon: const Icon(Icons.more_vert),
              onPressed: () => showTopicActions(context, topic),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _body(controller)),
          if (controller.error != null && controller.messages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
              child: Row(
                children: [
                  Expanded(child: Text(controller.error!, style: da(size: 13))),
                  TextButton(onPressed: controller.clearError, child: const Text('OK')),
                ],
              ),
            ),
          Composer(controller: _input, onSend: _send, sending: controller.sending, hint: 'Répondre…'),
        ],
      ),
    );
  }

  Widget _body(TopicController controller) {
    if (controller.loading && controller.messages.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (controller.error != null && controller.messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(controller.error!, style: da(), textAlign: TextAlign.center),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: controller.load, child: const Text('Réessayer')),
            ],
          ),
        ),
      );
    }
    final reversed = controller.messages.reversed.toList();
    return ListView.builder(
      controller: _scroll,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
      itemCount: reversed.length + (controller.hasMore ? 1 : 0) + (controller.sending ? 1 : 0),
      itemBuilder: (context, i) {
        if (controller.sending) {
          if (i == 0) return const ThinkingRow();
          i -= 1;
        }
        if (i == reversed.length) {
          return Center(
            child: TextButton(
              onPressed: controller.loadingOlder ? null : controller.loadOlder,
              child: Text(controller.loadingOlder ? '…' : 'Messages précédents'),
            ),
          );
        }
        final message = reversed[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 18),
          child: message.role == TopicRole.user ? UserBubble(text: message.text) : _Answer(message: message),
        );
      },
    );
  }
}

class _Answer extends StatelessWidget {
  const _Answer({required this.message});

  final TopicMessage message;

  @override
  Widget build(BuildContext context) {
    final agent = message.agent;
    final notes = <String>[
      if (agent?.status == 'limit_reached') 'Arrêté avant la fin (limite de temps ou d’étapes).',
      if (agent?.status == 'unavailable') 'Agent coupé : réponse sans outils.',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SelectableText(message.text, style: da(height: 1.55)),
        for (final item in agent?.items ?? const <CitedItem>[]) ...[
          const SizedBox(height: 12),
          CitedItemTile(item: item),
        ],
        for (final action in agent?.actions ?? const <AgentAction>[]) ...[
          const SizedBox(height: 12),
          ActionCard(message: message, action: action),
        ],
        if (message.external || notes.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 14,
            runSpacing: 4,
            children: [
              if (message.external)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.warning_amber_outlined, size: 14, color: Palette.lune),
                    const SizedBox(width: 6),
                    Text("contient du texte d'un tiers", style: da(size: 12, color: Palette.lune)),
                  ],
                ),
              for (final n in notes) Text(n, style: da(size: 12, color: Palette.lune)),
            ],
          ),
        ],
      ],
    );
  }
}

const _sourceIcons = {
  'email': Icons.mail_outline,
  'calendar': Icons.event_outlined,
  'tasks': Icons.check_box_outlined,
  'github': Icons.code,
  'rss': Icons.rss_feed,
  'ha': Icons.home_outlined,
};

/// An element of the box the answer cites — touch to read it, or to open a topic about it.
class CitedItemTile extends StatelessWidget {
  const CitedItemTile({super.key, required this.item});

  final CitedItem item;

  @override
  Widget build(BuildContext context) {
    final meta = [
      if (item.from != null) item.from!,
      if (item.at != null) timeago.format(item.at!, locale: 'fr'),
      if (item.priority == 'urgent') 'urgent',
    ].join(' · ');
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _showItem(context, item),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: Palette.filetFort),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(_sourceIcons[item.source] ?? Icons.inbox_outlined, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title, style: da(size: 14, weight: 400), maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(meta, style: da(size: 13, color: Palette.lune)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text('Ouvrir', style: da(size: 13, color: Palette.lavis)),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showItem(BuildContext context, CitedItem item) {
  final shell = context.read<ShellController>();
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(item.title, style: Theme.of(sheet).textTheme.headlineSmall),
            if (item.from != null) ...[
              const SizedBox(height: 4),
              Text(item.from!, style: da(size: 13, color: Palette.lune)),
            ],
            if (item.snippet != null) ...[
              const SizedBox(height: 14),
              SelectableText(item.snippet!, style: da(height: 1.5)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                Navigator.of(sheet).pop();
                shell.go(HomeDestination(aboutKey: item.key, aboutTitle: item.title));
              },
              child: const Text('Ouvrir un sujet sur cet élément'),
            ),
          ],
        ),
      ),
    ),
  );
}

/// An action the agent did or proposes. One waiting on the user is settled right here.
class ActionCard extends StatelessWidget {
  const ActionCard({super.key, required this.message, required this.action});

  final TopicMessage message;
  final AgentAction action;

  @override
  Widget build(BuildContext context) {
    final preview = action.preview;
    final where = action.connector != null && !action.isMemoryProposal ? ' · ${action.connector}' : '';
    final children = <Widget>[
      Text('${action.label}$where', style: da(size: 13, color: Palette.lune)),
      if (preview != null) ...[
        const SizedBox(height: 8),
        Text('« $preview »', style: da(family: serif, size: 17, style: FontStyle.italic, height: 1.4)),
      ],
      const SizedBox(height: 10),
      _footer(context),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: action.isDecidable ? Palette.encre2 : Colors.transparent,
        border: Border.all(color: Palette.filetFort),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
    );
  }

  Widget _footer(BuildContext context) {
    if (action.isMemoryProposal) {
      return Text(
        switch (action.status) {
          'pending' => 'Proposé pour la mémoire — à retenir dans « À valider ».',
          'executed' => 'Retenu.',
          _ => 'Pas retenu${action.reason != null ? ' : ${action.reason}' : '.'}',
        },
        style: da(size: 13, color: Palette.lune),
      );
    }
    if (!action.isDecidable) {
      return Text(
        switch (action.status) {
          'executed' => 'Fait.',
          'refused' => 'Refusé${action.reason != null ? ' : ${action.reason}' : '.'}',
          _ => 'Pas fait${action.reason != null ? ' : ${action.reason}' : '.'}',
        },
        style: da(size: 13, color: Palette.lune),
      );
    }
    final controller = context.watch<TopicController>();
    final state = controller.decisionOf(message, action);
    final left = controller.remainingFor(message, action);
    return switch (state) {
      DecisionState.waiting || DecisionState.failed || DecisionState.deciding => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state == DecisionState.failed)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(controller.decisionErrorOf(action) ?? 'Échec.', style: da(size: 13)),
              ),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: state == DecisionState.deciding ? null : () => controller.decide(action, confirm: true),
                    child: const Text('Confirmer'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: state == DecisionState.deciding ? null : () => controller.decide(action, confirm: false),
                    child: const Text('Annuler'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'expire dans ${expiresIn(left)}',
              style: da(size: 12, color: Palette.lune),
            ),
          ],
        ),
      DecisionState.confirmed => Text('Confirmé — fait.', style: da(size: 13, color: Palette.lune)),
      DecisionState.cancelled => Text('Annulé — rien n’a été fait.', style: da(size: 13, color: Palette.lune)),
      DecisionState.expired =>
        Text('Expiré — rien n’a été fait. Redemandez dans le sujet.', style: da(size: 13, color: Palette.lune)),
    };
  }
}

/// « moins d'une minute », « 12 min », « 1 h 30 », « 23 h » — a pending write may wait up to a day.
String expiresIn(Duration left) {
  if (left.inMinutes < 1) return "moins d'une minute";
  if (left.inHours < 1) return '${left.inMinutes} min';
  final minutes = left.inMinutes % 60;
  return minutes == 0 ? '${left.inHours} h' : '${left.inHours} h ${minutes.toString().padLeft(2, '0')}';
}
