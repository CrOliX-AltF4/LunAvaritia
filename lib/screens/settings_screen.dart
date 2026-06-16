import 'package:flutter/material.dart';
import '../config/api_config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _urlCtrl   = TextEditingController();
  final _tokenCtrl = TextEditingController();
  String _mode     = 'natsume';
  bool _saving     = false;
  bool _obscure    = true;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final cfg = await ApiConfig.load();
    setState(() {
      _urlCtrl.text   = cfg.baseUrl;
      _tokenCtrl.text = cfg.token;
      _mode           = cfg.backendMode;
    });
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
    await ApiConfig.save(baseUrl: url, token: token, backendMode: _mode);

    if (mounted) {
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
          // ── Mode serveur ─────────────────────────────────────────────────────
          Text('Mode backend', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'natsume',
                label: Text('Natsume'),
                icon: Icon(Icons.auto_awesome_outlined),
              ),
              ButtonSegment(
                value: 'lunacedia',
                label: Text('LunAcedia'),
                icon: Icon(Icons.inbox_outlined),
              ),
            ],
            selected: {_mode},
            onSelectionChanged: (v) => setState(() => _mode = v.first),
          ),
          const SizedBox(height: 4),
          Text(
            _mode == 'natsume'
                ? 'Natsume Core — chat companion + alertes intégrées'
                : 'LunAcedia — serveur d\'information autonome (events, digest)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          // ── Connexion ────────────────────────────────────────────────────────
          Text('Connexion', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _urlCtrl,
            decoration: InputDecoration(
              labelText: 'URL de base',
              hintText: _mode == 'natsume'
                  ? 'http://192.168.1.x:3333'
                  : 'http://192.168.1.x:4001',
              prefixIcon: const Icon(Icons.link),
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tokenCtrl,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: _mode == 'natsume' ? 'Token (ADMIN_SECRET)' : 'Token (ACEDIA_SECRET)',
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
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
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
            subtitle: const Text('v1.1.0 — companion mobile Natsume / LunAcedia'),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }
}
