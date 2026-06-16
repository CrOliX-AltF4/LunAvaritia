import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'config/api_config.dart';
import 'providers/alert_provider.dart';
import 'providers/chat_provider.dart';
import 'screens/main_shell.dart';
import 'services/api_service.dart';

class LunAvaritiaApp extends StatelessWidget {
  const LunAvaritiaApp({super.key, required this.config});

  final ApiConfig config;

  @override
  Widget build(BuildContext context) {
    final api = ApiService(config);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ChatProvider(api)),
        ChangeNotifierProvider(create: (_) => AlertProvider(api)),
      ],
      child: MaterialApp(
        title: "Lun'Avaritia",
        debugShowCheckedModeBanner: false,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        home: const MainShell(),
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final seed = const Color(0xFF7C5CBF); // Natsume purple
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorSchemeSeed: seed,
    );
  }
}
