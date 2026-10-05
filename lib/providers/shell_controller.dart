import 'package:flutter/material.dart';

/// Where the app stands (DA1 « sujet + tiroir »): one screen at a time, the drawer for everything else. No tabs.
sealed class Destination {
  const Destination();
}

/// A new topic — optionally about a box item (a notification's or the box's "Traiter").
class HomeDestination extends Destination {
  const HomeDestination({this.aboutKey, this.aboutTitle});
  final String? aboutKey;
  final String? aboutTitle;
}

class TopicDestination extends Destination {
  const TopicDestination(this.id);
  final String id;
}

class BoxDestination extends Destination {
  const BoxDestination();
}

/// One item of the box, read in full (DA-M4) — from the box or from a tapped notification.
class BoxItemDestination extends Destination {
  const BoxItemDestination(this.key);
  final String key;
}

/// Gmail's trash, from the box.
class TrashDestination extends Destination {
  const TrashDestination();
}

/// « À valider »: memory proposals and pending writes.
class ValidateDestination extends Destination {
  const ValidateDestination();
}

class ArchivedDestination extends Destination {
  const ArchivedDestination();
}

class SettingsDestination extends Destination {
  const SettingsDestination();
}

class ShellController extends ChangeNotifier {
  ShellController({Destination initial = const HomeDestination()}) : _current = initial;

  /// The shell's scaffold — the one holding the drawer, which every screen's menu button opens.
  final scaffoldKey = GlobalKey<ScaffoldState>();

  Destination _current;
  Destination get current => _current;

  void go(Destination destination) {
    _current = destination;
    scaffoldKey.currentState?.closeDrawer();
    notifyListeners();
  }

  void openDrawer() => scaffoldKey.currentState?.openDrawer();
}
