import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/api_config.dart';
import 'providers/box_controller.dart';
import 'providers/identity_provider.dart';
import 'providers/shell_controller.dart';
import 'providers/topics_provider.dart';
import 'providers/validation_controller.dart';
import 'screens/main_shell.dart';
import 'services/backend_client.dart';
import 'services/change_stream.dart';
import 'services/connection_controller.dart';
import 'services/pairing.dart';
import 'theme/app_theme.dart';

class LunAvaritiaApp extends StatefulWidget {
  const LunAvaritiaApp({super.key, required this.connection});

  /// Which server the app talks to — a change rebuilds the clients and the views, no restart.
  final ConnectionController connection;

  @override
  State<LunAvaritiaApp> createState() => _LunAvaritiaAppState();
}

class _LunAvaritiaAppState extends State<LunAvaritiaApp> {
  late ApiConfig _config = widget.connection.config;

  // One stream of what changed per connection — the shell opens it in front and closes it behind.
  late ChangeStream _changeStream = ChangeStream(_config);

  // Which page is open survives a change of server: the settings stay on screen after « Enregistrer ».
  final _shell = ShellController();

  @override
  void initState() {
    super.initState();
    widget.connection.addListener(_onConnection);
  }

  /// Another server: a new stream of changes, new clients — the views reload from it.
  void _onConnection() {
    final next = widget.connection.config;
    if (identical(next, _config)) return;
    final old = _changeStream;
    setState(() {
      _config = next;
      _changeStream = ChangeStream(next);
    });
    unawaited(old.dispose());
  }

  @override
  void dispose() {
    widget.connection.removeListener(_onConnection);
    unawaited(_changeStream.dispose());
    _shell.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = _config;
    final client = buildBackendClient(config);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ConnectionController>.value(value: widget.connection),
        ChangeNotifierProvider<ShellController>.value(value: _shell),
      ],
      // Keyed by the connection: every provider below is created again for the new server.
      child: MultiProvider(
        key: ObjectKey(config),
        providers: [
          Provider<BackendClient>.value(value: client),
          ChangeNotifierProvider(create: (_) => IdentityProvider(client)),
          ChangeNotifierProvider(create: (_) => TopicsProvider(client)),
          ChangeNotifierProvider(create: (_) => BoxController(client)),
          ChangeNotifierProvider(create: (_) => ValidationController(client)),
        ],
        child: MaterialApp(
          title: "Lun'Avaritia",
          debugShowCheckedModeBanner: false,
          // The DA's ink theme — the same dark ground as the site and the panel.
          theme: buildAppTheme(),
          // A phone that is not paired (or still holds an old shared secret) says so everywhere.
          home: MainShell(
            changeStream: _changeStream,
            wired: config.wired,
            pairingNeeded: config.baseUrl.isNotEmpty && pairingStateOf(config.token) != PairingState.paired,
          ),
        ),
      ),
    );
  }
}
