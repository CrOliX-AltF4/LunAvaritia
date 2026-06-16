import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../providers/chat_provider.dart';
import '../providers/alert_provider.dart';
import '../services/api_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _urlCtrl   = TextEditingController();
  final _tokenCtrl = TextEditingController();
  bool _saving     = false;
  bool _obscure    = true;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final cfg = await ApiConfig.load();
    _urlCtrl.text   = cfg.baseUrl;
    _tokenCtrl.text = cfg.token;
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final url   = _urlCtrl.text.trim();
    final token = _tokenCtrl.text.trim();
    if (url.isEmpty) return;

    setState(() => _saving = true);
    await ApiConfig.save(baseUrl: url, token: token);

    // Reload providers with new config
    if (mounted) {
      final cfg     = await ApiConfig.load();
      final api     = ApiService(cfg);
      context.read<ChatProvider>(); // no direct rebind — full restart required
      context.read<AlertProvider>();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paramètres sauvegardés — redémarrez l\'app')),
      );
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: const Text('Paramètres', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Serveur ─────────────────────────────────────────────────────────
          Text('Serveur Natsume', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _urlCtrl,
            decoration: const InputDecoration(
              labelText: 'URL de base',
              hintText: 'http://192.168.1.x:3333',
              prefixIcon: Icon(Icons.link),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tokenCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Token (ADMIN_SECRET)',
              prefixIcon: const Icon(Icons.key_outlined),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined),
            label: const Text('Sauvegarder'),
          ),
          const SizedBox(height: 32),
          // ── Info ─────────────────────────────────────────────────────────────
          const Divider(),
          const SizedBox(height: 8),
          Text('À propos', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text("Lun'Avaritia"),
            subtitle: const Text('v1.0.0 — companion mobile Natsume'),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
