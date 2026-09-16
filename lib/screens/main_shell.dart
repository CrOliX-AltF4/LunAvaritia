import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/alert_provider.dart';
import '../services/deep_link_router.dart';
import '../services/digest_gate.dart';
import 'chat_screen.dart';
import 'alert_feed_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    this.digestGate = const DigestGate(),
    DeepLinkRouter? deepLinkRouter,
  }) : deepLinkRouter = deepLinkRouter ?? DeepLinkRouter.instance;

  /// Overridable for tests — a shorter minGap lets a widget test trigger the auto-digest
  /// without waiting on real time or faking SharedPreferences' stored timestamp by hand.
  final DigestGate digestGate;

  /// Overridable for tests — DeepLinkRouter.instance is a process-wide singleton that
  /// would otherwise leak pending state between widget tests.
  final DeepLinkRouter deepLinkRouter;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _index = 0;

  static const _screens = [
    ChatScreen(),
    AlertFeedScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Cold start counts as "waking" the app too, not just a foreground resume.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowDigest());
    widget.deepLinkRouter.addListener(_onDeepLinkRequested);
    // A tap that launched the app cold (getInitialMessage) can fire before this widget
    // even exists — check for an already-pending request instead of only reacting to
    // the listener notification going forward.
    WidgetsBinding.instance.addPostFrameCallback((_) => _onDeepLinkRequested());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.deepLinkRouter.removeListener(_onDeepLinkRequested);
    super.dispose();
  }

  void _onDeepLinkRequested() {
    final tab = widget.deepLinkRouter.pending;
    if (tab == null) return;
    widget.deepLinkRouter.consume();
    setState(() => _index = tab.index);
    if (tab == AppTab.alerts) {
      // The tapped notification is presumably the freshest thing there is — IndexedStack
      // keeps AlertFeedScreen alive since first build, so its own initState-triggered
      // load already ran once and won't naturally pick this up on its own.
      context.read<AlertProvider>().refresh();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _maybeShowDigest();
  }

  Future<void> _maybeShowDigest() async {
    if (!await widget.digestGate.shouldShow()) return;
    if (!mounted) return;
    try {
      final digest = await context.read<AlertProvider>().fetchDigest();
      // Mark shown on any successful fetch, even an empty digest — otherwise "nothing
      // happened" would retry on every resume until the gap naturally elapses on its own.
      await widget.digestGate.markShown();
      if (!mounted || digest.trim().isEmpty) return;
      // Not awaited — see the identical note in AlertFeedScreen._showDigest(); nothing here
      // depends on knowing when the sheet is dismissed.
      unawaited(showDigestSheet(context, digest));
    } catch (_) {
      // Silent — an auto-trigger shouldn't nag on a transient/offline failure, and not
      // calling markShown() here means the next resume retries rather than giving up for
      // the rest of the gap window. The manual digest button already surfaces real errors.
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = context.select<AlertProvider, int>((p) => p.unreadCount);

    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
            icon:         Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble),
            label:        'Chat',
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications),
            ),
            label: 'Alertes',
          ),
          const NavigationDestination(
            icon:         Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label:        'Paramètres',
          ),
        ],
      ),
    );
  }
}
