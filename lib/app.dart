import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/api_config.dart';
import 'providers/alert_provider.dart';
import 'providers/identity_provider.dart';
import 'providers/shell_controller.dart';
import 'providers/topics_provider.dart';
import 'screens/main_shell.dart';
import 'services/backend_client.dart';
import 'services/pairing.dart';
import 'theme/app_theme.dart';

class LunAvaritiaApp extends StatelessWidget {
  const LunAvaritiaApp({super.key, required this.config});

  final ApiConfig config;

  @override
  Widget build(BuildContext context) {
    final client = buildBackendClient(config);

    return MultiProvider(
      providers: [
        Provider<BackendClient>.value(value: client),
        ChangeNotifierProvider(create: (_) => ShellController()),
        ChangeNotifierProvider(create: (_) => IdentityProvider(client)),
        ChangeNotifierProvider(create: (_) => TopicsProvider(client)),
        ChangeNotifierProvider(create: (_) => AlertProvider(client)),
      ],
      child: MaterialApp(
        title: "Lun'Avaritia",
        debugShowCheckedModeBanner: false,
        // The DA's ink theme (ADR-020 D5, DA2) — the same dark ground as the site and the panel.
        theme: buildAppTheme(),
        // ADR-020 M3: a phone that is not paired (or still holds an old shared secret) says so everywhere.
        home: MainShell(
          wired: config.wired,
          pairingNeeded: config.baseUrl.isNotEmpty && pairingStateOf(config.token) != PairingState.paired,
        ),
      ),
    );
  }
}
