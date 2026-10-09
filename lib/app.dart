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
import 'services/pairing.dart';
import 'theme/app_theme.dart';

class LunAvaritiaApp extends StatefulWidget {
  const LunAvaritiaApp({super.key, required this.config});

  final ApiConfig config;

  @override
  State<LunAvaritiaApp> createState() => _LunAvaritiaAppState();
}

class _LunAvaritiaAppState extends State<LunAvaritiaApp> {
  // One stream of what changed for the app's life — the shell opens it in front and closes it behind.
  late final ChangeStream _changeStream = ChangeStream(widget.config);

  ApiConfig get config => widget.config;

  @override
  void dispose() {
    unawaited(_changeStream.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final client = buildBackendClient(config);

    return MultiProvider(
      providers: [
        Provider<BackendClient>.value(value: client),
        ChangeNotifierProvider(create: (_) => ShellController()),
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
    );
  }
}
