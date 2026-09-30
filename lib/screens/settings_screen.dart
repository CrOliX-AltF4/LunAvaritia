import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../models/assistant_identity.dart';
import '../services/app_version.dart';
import '../services/backend_client.dart';

/// Asks a server who answers — the connection test. Injectable so a widget test needs no network.
typedef IdentityProbe = Future<AssistantIdentity> Function(ApiConfig config);

Future<AssistantIdentity> _probeServer(ApiConfig config) => buildBackendClient(config).getIdentity();

/// LunAcedia first — it is the product (ADR-008). Wiring to a hub is an advanced, optional setting
/// (ADR-020 D2, live check C20): no mode switch, and no assistant name written in the app.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, this.probe = _probeServer});

  final IdentityProbe probe;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _acediaUrlCtrl   = TextEditingController();
  final _acediaTokenCtrl = TextEditingController();
  final _hubUrlCtrl      = TextEditingController();
  final _hubTokenCtrl    = TextEditingController();
  bool _loaded   = false;
  bool _saving   = false;
  bool _testing  = false;
  bool _obscure  = true;

  /// Result of the last "Tester la connexion" — null until the first test.
  String? _testResult;
  bool _testOk = false;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final cfg = await ApiConfig.load();
    if (!mounted) return;
    setState(() {
      _acediaUrlCtrl.text   = cfg.acediaUrl;
      _acediaTokenCtrl.text = cfg.acediaToken;
      _hubUrlCtrl.text      = cfg.hubUrl;
      _hubTokenCtrl.text    = cfg.hubToken;
      _loaded               = true;
    });
  }

  @override
  void dispose() {
    _acediaUrlCtrl.dispose();
    _acediaTokenCtrl.dispose();
    _hubUrlCtrl.dispose();
    _hubTokenCtrl.dispose();
    super.dispose();
  }

  ApiConfig get _formConfig => ApiConfig.fromForm(
        acediaUrl:   _acediaUrlCtrl.text,
        acediaToken: _acediaTokenCtrl.text,
        hubUrl:      _hubUrlCtrl.text,
        hubToken:    _hubTokenCtrl.text,
      );

  bool get _hasAddress => _formConfig.baseUrl.isNotEmpty;

  Future<void> _test() async {
    if (!_hasAddress) {
      setState(() {
        _testOk = false;
        _testResult = 'Renseignez une adresse.';
      });
      return;
    }
    final cfg = _formConfig;
    setState(() => _testing = true);
    try {
      final identity = await widget.probe(cfg);
      _testOk = true;
      _testResult = cfg.wired ? 'Hub joignable — ${identity.name} répond.' : 'Connecté — ${identity.name} répond.';
    } on BackendError catch (e) {
      _testOk = false;
      _testResult = e.message;
    } catch (e) {
      _testOk = false;
      _testResult = 'Erreur inattendue : $e';
    }
    if (mounted) setState(() => _testing = false);
  }

  Future<void> _save() async {
    if (!_hasAddress) return;
    setState(() => _saving = true);
    await ApiConfig.save(
      acediaUrl:   _acediaUrlCtrl.text,
      acediaToken: _acediaTokenCtrl.text,
      hubUrl:      _hubUrlCtrl.text,
      hubToken:    _hubTokenCtrl.text,
    );
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paramètres sauvegardés — redémarrez l\'app')),
      );
      setState(() => _saving = false);
    }
  }

  InputDecoration _field(String label, IconData icon, {String? hint, bool secret = false}) => InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
        suffixIcon: secret
            ? IconButton(
                icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _obscure = !_obscure),
              )
            : null,
      );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final small  = Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        title: const Text('Paramètres', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── LunAcedia ────────────────────────────────────────────────────────
          Text('Serveur LunAcedia', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          TextField(
            controller: _acediaUrlCtrl,
            decoration: _field('Adresse', Icons.link, hint: 'http://192.168.1.x:4001'),
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _acediaTokenCtrl,
            obscureText: _obscure,
            decoration: _field('Jeton d\'accès', Icons.key_outlined, secret: true),
          ),
          const SizedBox(height: 16),
          // ── Hub (advanced) ───────────────────────────────────────────────────
          // Built only once the saved values are in, so an already-wired install opens it expanded.
          if (_loaded)
            ExpansionTile(
              initiallyExpanded: _hubUrlCtrl.text.trim().isNotEmpty,
              tilePadding: EdgeInsets.zero,
              childrenPadding: const EdgeInsets.only(bottom: 8),
              title: const Text('Avancé — relier à un hub'),
              subtitle: Text(
                'Laisser vide pour parler à LunAcedia directement. Relié à un hub, l\'app ne passe plus que par lui.',
                style: small,
              ),
              children: [
                TextField(
                  controller: _hubUrlCtrl,
                  decoration: _field('Adresse du hub', Icons.hub_outlined, hint: 'http://192.168.1.x:3333'),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _hubTokenCtrl,
                  obscureText: _obscure,
                  decoration: _field('Jeton du hub', Icons.key_outlined, secret: true),
                ),
              ],
            ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _testing ? null : _test,
                  icon: _testing
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.wifi_tethering),
                  label: const Text('Tester la connexion'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
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
              ),
            ],
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  _testOk ? Icons.check_circle_outline : Icons.error_outline,
                  size: 18,
                  color: _testOk ? colors.primary : colors.error,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(_testResult!)),
              ],
            ),
          ],
          const SizedBox(height: 32),
          // ── Info ─────────────────────────────────────────────────────────────
          const Divider(),
          const SizedBox(height: 8),
          Text('À propos', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 8),
          // Read from the installed package (live check C18: "v1.1.0" was written by hand while 1.3.1 ran).
          FutureBuilder<String>(
            future: installedVersion(),
            builder: (context, snap) => ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text("Lun'Avaritia"),
              subtitle: Text(snap.data ?? '…'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }
}
