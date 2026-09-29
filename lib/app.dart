import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/api_config.dart';
import 'providers/alert_provider.dart';
import 'providers/chat_provider.dart';
import 'screens/main_shell.dart';
import 'services/backend_client.dart';

class LunAvaritiaApp extends StatelessWidget {
  const LunAvaritiaApp({super.key, required this.config});

  final ApiConfig config;

  @override
  Widget build(BuildContext context) {
    final client = buildBackendClient(config);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatProvider(client)),
        ChangeNotifierProvider(create: (_) => AlertProvider(client)),
      ],
      child: MaterialApp(
        title: "Lun'Avaritia",
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        home: MainShell(),
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    const seed = Color(0xFF7C5CBF); // Natsume purple
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorSchemeSeed: seed,
    );
  }
}
