import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/box_controller.dart';
import '../providers/identity_provider.dart';
import '../providers/shell_controller.dart';
import '../providers/topic_controller.dart';
import '../providers/topics_provider.dart';
import '../providers/validation_controller.dart';
import '../services/backend_client.dart';
import '../services/change_stream.dart';
import '../services/deep_link_router.dart';
import '../services/digest_gate.dart';
import '../services/update_checker.dart';
import '../services/update_launcher.dart';
import '../widgets/app_drawer.dart';
import 'archived_screen.dart';
import 'box_reader_screen.dart';
import 'box_screen.dart';
import 'digest_sheet.dart';
import 'home_screen.dart';
import 'settings_screen.dart';
import 'topic_screen.dart';
import 'trash_screen.dart';
import 'validate_screen.dart';

/// One screen at a time and a drawer for the rest (DA1 « sujet + tiroir ») — no tabs.
class MainShell extends StatefulWidget {
  // Not const — deepLinkRouter's default falls back to DeepLinkRouter.instance, a runtime
  // singleton, which can't appear in a const constructor's initializer list.
  MainShell({
    super.key,
    this.digestGate = const DigestGate(),
    this.pairingNeeded = false,
    this.wired = false,
    DeepLinkRouter? deepLinkRouter,
    UpdateChecker? updateChecker,
    this.settings,
    this.changeStream,
  })  : deepLinkRouter = deepLinkRouter ?? DeepLinkRouter.instance,
        updateChecker = updateChecker ?? UpdateChecker();

  /// Overridable for tests — a shorter minGap lets a widget test trigger the auto-digest
  /// without waiting on real time or faking SharedPreferences' stored timestamp by hand.
  final DigestGate digestGate;

  /// Overridable for tests — DeepLinkRouter.instance is a process-wide singleton that
  /// would otherwise leak pending state between widget tests.
  final DeepLinkRouter deepLinkRouter;

  /// Overridable for tests — the real one asks GitHub.
  final UpdateChecker updateChecker;

  /// This phone is not paired with the server it talks to, or still holds an old shared secret.
  final bool pairingNeeded;

  /// Wired to the hub — said in the drawer.
  final bool wired;

  /// Overridable for tests — the real settings screen probes the server.
  final Widget? settings;

  /// What changed on the server, followed while the app is in front (lot S). Null: nothing followed (tests).
  final ChangeStream? changeStream;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  late final ChangeBursts _bursts = ChangeBursts(_onChanged);
  StreamSubscription<Change>? _changes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _changes = widget.changeStream?.changes.listen(_bursts.add);
    widget.changeStream?.start();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // What the drawer and the home screen show: who answers, the topics, the box's counts.
      unawaited(context.read<IdentityProvider>().refresh());
      unawaited(context.read<TopicsProvider>().refresh());
      unawaited(context.read<BoxController>().load());
      unawaited(context.read<ValidationController>().load());
    });
    // Cold start counts as "waking" the app too, not just a foreground resume.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowDigest());
    widget.deepLinkRouter.addListener(_onDeepLinkRequested);
    widget.deepLinkRouter.boxNudges.addListener(_onBoxNudged);
    // A tap that launched the app cold (getInitialMessage) can fire before this widget
    // even exists — check for an already-pending request instead of only reacting to
    // the listener notification going forward.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onDeepLinkRequested());
    // Cold start only, never blocking: a new signed release is offered once per version.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeOfferUpdate());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.deepLinkRouter.removeListener(_onDeepLinkRequested);
    widget.deepLinkRouter.boxNudges.removeListener(_onBoxNudged);
    unawaited(_changes?.cancel());
    _bursts.cancel();
    widget.changeStream?.stop();
    super.dispose();
  }

  void _onDeepLinkRequested() {
    final target = widget.deepLinkRouter.pending;
    if (target == null || !mounted) return;
    widget.deepLinkRouter.consume();
    if (target.validate) {
      context.read<ShellController>().go(const ValidateDestination());
      unawaited(context.read<ValidationController>().load());
      return;
    }
    final key = target.boxKey;
    // The tapped notification is presumably the freshest thing there is: the box is read again either way.
    final box = context.read<BoxController>();
    if (key == null) {
      context.read<ShellController>().go(const BoxDestination());
      unawaited(box.load());
      return;
    }
    // The reader looks the item up once the box is read; it says so if the item left the box since.
    unawaited(box.load().then((_) {
      if (mounted) context.read<ShellController>().go(BoxItemDestination(key));
    }));
  }

  void _onBoxNudged() {
    if (!mounted) return;
    unawaited(context.read<BoxController>().load());
    unawaited(context.read<ValidationController>().load());
  }

  /// A burst of changes in one scope: what shows it is read again — the open topic follows on its own.
  void _onChanged(String scope, List<Change> changes) {
    if (!mounted) return;
    switch (scope) {
      case 'box' || 'alerts':
        unawaited(context.read<BoxController>().load());
      case 'actions' || 'memory':
        unawaited(context.read<ValidationController>().load());
      case 'topics':
        unawaited(context.read<TopicsProvider>().refresh());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final stream = widget.changeStream;
    switch (state) {
      case AppLifecycleState.resumed:
        // Back in front: what changed meanwhile is read once, then followed again.
        if (stream != null && !stream.running) {
          stream.start();
          _onBoxNudged();
        }
        _maybeShowDigest();
      case AppLifecycleState.paused || AppLifecycleState.hidden || AppLifecycleState.detached:
        // Out of sight: no connection kept (battery) — the silent pushes take notifications down meanwhile.
        stream?.stop();
        _bursts.cancel();
      case AppLifecycleState.inactive:
        break;
    }
  }

  Future<void> _maybeOfferUpdate() async {
    final status = await widget.updateChecker.check();
    if (status is! UpdateAvailable) return;
    final update = status.update;
    if (!await UpdateChecker.shouldNotify(update.version)) return;
    if (!mounted) return;
    await UpdateChecker.markNotified(update.version);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Version ${update.version} disponible'),
        duration: const Duration(seconds: 10),
        action: SnackBarAction(label: 'Télécharger', onPressed: () => openUpdateDownload(context, update)),
      ),
    );
  }

  Future<void> _maybeShowDigest() async {
    if (!await widget.digestGate.shouldShow()) return;
    if (!mounted) return;
    try {
      final digest = await context.read<BoxController>().fetchDigest();
      // Mark shown on any successful fetch, even an empty digest — otherwise "nothing
      // happened" would retry on every resume until the gap naturally elapses on its own.
      await widget.digestGate.markShown();
      if (!mounted || digest.isEmpty) return;
      // Not awaited — showModalBottomSheet()'s future resolves when the sheet is dismissed;
      // nothing here depends on knowing that.
      unawaited(showDigestSheet(context, digest,
          onOpen: (key) => context.read<ShellController>().go(BoxItemDestination(key))));
    } catch (_) {
      // Silent — an auto-trigger shouldn't nag on a transient/offline failure, and not
      // calling markShown() here means the next resume retries rather than giving up for
      // the rest of the gap window. The manual digest button already surfaces real errors.
    }
  }

  Widget _screenFor(Destination destination) => switch (destination) {
        HomeDestination(:final aboutKey, :final aboutTitle) =>
          HomeScreen(key: ValueKey('home-$aboutKey'), aboutKey: aboutKey, aboutTitle: aboutTitle),
        TopicDestination(:final id) => ChangeNotifierProvider(
            key: ValueKey('topic-$id'),
            create: (context) {
              final topics = context.read<TopicsProvider>();
              final opened = topics.lastOpened?.topic.id == id ? topics.lastOpened : null;
              // The first answer is shown as it came — not asked for again.
              if (opened != null) topics.lastOpened = null;
              return TopicController(context.read<BackendClient>(), id,
                  opened: opened, changes: widget.changeStream?.changes);
            },
            child: const TopicScreen(),
          ),
        BoxDestination() => const BoxScreen(),
        BoxItemDestination(:final key) => BoxReaderScreen(key: ValueKey('box-item-$key'), itemKey: key),
        TrashDestination() => const TrashScreen(),
        ValidateDestination() => const ValidateScreen(),
        ArchivedDestination() => const ArchivedScreen(),
        SettingsDestination() => widget.settings ?? const SettingsScreen(),
      };

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<ShellController>();
    final destination = shell.current;
    final showPairingBanner = widget.pairingNeeded && destination is! SettingsDestination;

    return PopScope(
      // Back leads home first — from an item or the trash, to the box; from home, it leaves the app.
      canPop: destination is HomeDestination,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        shell.go(destination is BoxItemDestination || destination is TrashDestination
            ? const BoxDestination()
            : const HomeDestination());
      },
      child: Scaffold(
        key: shell.scaffoldKey,
        drawer: AppDrawer(wired: widget.wired, paired: !widget.pairingNeeded),
        body: Column(
          children: [
            // The banner takes the status bar's place; the screen below then must not leave room for it again.
            if (showPairingBanner)
              SafeArea(
                bottom: false,
                child: MaterialBanner(
                  leading: const Icon(Icons.link_off),
                  content: const Text(
                    "Cet appareil n'est pas appairé avec son serveur, ou garde un ancien secret. Appairez-le dans les réglages.",
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => shell.go(const SettingsDestination()),
                      child: const Text('Réglages'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: showPairingBanner,
                child: _screenFor(destination),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
