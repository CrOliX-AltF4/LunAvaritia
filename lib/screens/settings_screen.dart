import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../models/assistant_identity.dart';
import '../services/app_version.dart';
import '../services/backend_client.dart';
import '../services/pairing.dart';
import '../widgets/shell_widgets.dart';
import '../services/update_checker.dart';
import '../services/update_launcher.dart';

/// Asks a server who answers — the connection test. Injectable so a widget test needs no network.
typedef IdentityProbe = Future<AssistantIdentity> Function(ApiConfig config);

Future<AssistantIdentity> _probeServer(ApiConfig config) => buildBackendClient(config).getIdentity();

Future<UpdateStatus> _checkForUpdate() => UpdateChecker().check();

/// LunAcedia first — it is the product (ADR-008). Wiring to a hub is an advanced, optional setting
/// (ADR-020 D2, live check C20): no mode switch, and no assistant name written in the app.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.probe = _probeServer,
    this.checkUpdate = _checkForUpdate,
    this.pair = pairDevice,
  });

  final IdentityProbe probe;

  /// Pairs this phone with a server (ADR-020 M3) — injectable for widget tests.
  final PairDevice pair;

  /// Asks GitHub for a newer signed release (ADR-020 M1) — injectable for widget tests.
  final Future<UpdateStatus> Function() checkUpdate;

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

  /// Result of the last "Tester la connexion" — null until the first test.
  String? _testResult;
  bool _testOk = false;

  bool _checkingUpdate = false;
  UpdateStatus? _update;

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

  Future<void> _checkUpdate() async {
    setState(() => _checkingUpdate = true);
    final status = await widget.checkUpdate();
    if (!mounted) return;
    setState(() {
      _update = status;
      _checkingUpdate = false;
    });
  }

  Widget _updateSection() {
    final update = _update;
    if (update is UpdateAvailable) {
      return FilledButton.icon(
        onPressed: () => openUpdateDownload(context, update.update),
        icon: const Icon(Icons.download_outlined),
        label: Text('Télécharger la version ${update.update.version}'),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _checkingUpdate ? null : _checkUpdate,
          icon: _checkingUpdate
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.system_update_outlined),
          label: const Text('Rechercher une mise à jour'),
        ),
        if (update != null) ...[
          const SizedBox(height: 8),
          Text(switch (update) {
            UpToDate() => "L'application est à jour.",
            UpdateUnknown(:final reason) => 'Impossible de vérifier : $reason.',
            UpdateAvailable() => '',
          }),
        ],
      ],
    );
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

  InputDecoration _field(String label, IconData icon, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      );

  TextEditingController _urlOf(PairingTarget t) => t == PairingTarget.lunacedia ? _acediaUrlCtrl : _hubUrlCtrl;
  TextEditingController _tokenOf(PairingTarget t) => t == PairingTarget.lunacedia ? _acediaTokenCtrl : _hubTokenCtrl;

  /// Where this phone stands with a server, and the way to pair it (ADR-020 M3). No secret is ever typed here.
  Widget _pairingRow(PairingTarget target) {
    final colors = Theme.of(context).colorScheme;
    final state = pairingStateOf(_tokenOf(target).text);
    final (icon, label, color) = switch (state) {
      PairingState.paired => (Icons.verified_user_outlined, 'Cet appareil est appairé.', colors.primary),
      PairingState.legacySecret => (
          Icons.warning_amber_outlined,
          'Ancien secret enregistré sur le téléphone — appairez cet appareil pour le remplacer.',
          colors.error,
        ),
      PairingState.none => (Icons.link_off, "Cet appareil n'est pas appairé.", colors.onSurfaceVariant),
    };
    return Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: TextStyle(color: color))),
        TextButton(
          onPressed: () => _openPairDialog(target),
          child: Text(state == PairingState.paired ? 'Ré-appairer' : 'Appairer'),
        ),
      ],
    );
  }

  Future<void> _openPairDialog(PairingTarget target) async {
    final url = _urlOf(target).text.trim();
    final messenger = ScaffoldMessenger.of(context);
    if (url.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text("Renseignez d'abord l'adresse.")));
      return;
    }
    final token = await showDialog<String>(
      context: context,
      builder: (_) => _PairDialog(target: target, url: url, pair: widget.pair),
    );
    if (token == null || !mounted) return;
    // The device token replaces whatever was stored — an old master secret included (ADR-020 M3).
    setState(() => _tokenOf(target).text = token);
    await ApiConfig.save(
      acediaUrl:   _acediaUrlCtrl.text,
      acediaToken: _acediaTokenCtrl.text,
      hubUrl:      _hubUrlCtrl.text,
      hubToken:    _hubTokenCtrl.text,
    );
    messenger.showSnackBar(const SnackBar(content: Text("Appareil appairé — redémarrez l'app")));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final small  = Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.onSurfaceVariant);

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        backgroundColor: colors.surface,
        leading: const MenuButton(),
        titleSpacing: 0,
        title: Text('Réglages', style: Theme.of(context).textTheme.titleLarge),
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
          const SizedBox(height: 8),
          _pairingRow(PairingTarget.lunacedia),
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
                const SizedBox(height: 8),
                _pairingRow(PairingTarget.hub),
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
          const SizedBox(height: 8),
          _updateSection(),
        ],
      ),
    );
  }
}

/// Asks the one-time code (shown in LunAcedia's dashboard or the hub's panel) and a name for this phone.
class _PairDialog extends StatefulWidget {
  const _PairDialog({required this.target, required this.url, required this.pair});
  final PairingTarget target;
  final String url;
  final PairDevice pair;

  @override
  State<_PairDialog> createState() => _PairDialogState();
}

class _PairDialogState extends State<_PairDialog> {
  final _code = TextEditingController();
  final _name = TextEditingController(text: 'Mon téléphone');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final token = await widget.pair(
        target: widget.target,
        url: widget.url,
        code: _code.text.trim(),
        name: _name.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(token);
    } catch (e) {
      if (mounted) setState(() => _error = pairingErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final where = widget.target == PairingTarget.lunacedia
        ? 'le tableau de bord de LunAcedia (Appareils)'
        : 'le panel (Pilotage › Accès)';
    return AlertDialog(
      title: const Text('Appairer cet appareil'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text("Demandez un code dans $where, puis saisissez-le ici. Il ne sert qu'une fois et expire au bout de 10 minutes."),
          const SizedBox(height: 12),
          TextField(
            controller: _code,
            decoration: const InputDecoration(labelText: 'Code'),
            textCapitalization: TextCapitalization.characters,
          ),
          const SizedBox(height: 8),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nom de cet appareil')),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(), child: const Text('Annuler')),
        FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? '…' : 'Appairer')),
      ],
    );
  }
}
