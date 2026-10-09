import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

/// What changed on the server, never the content: the view that cares reads its part again — the server stays the
/// only truth, and a lost message costs nothing the next load does not catch up.
class Change {
  const Change({required this.scope, this.key, this.settled = false});

  /// « box », « actions », « topics », « alerts » or « memory ».
  final String scope;

  /// The one object, when there is one: a box item's key, an action's id, a topic's id, an alert's id.
  final String? key;

  /// The object is settled (read, gone, decided, expired).
  final bool settled;

  static Change? tryParse(String data) {
    try {
      final json = jsonDecode(data);
      if (json is! Map<String, dynamic>) return null;
      final scope = json['scope'];
      if (scope is! String || scope.isEmpty) return null;
      final key = json['key'];
      return Change(scope: scope, key: key is String && key.isNotEmpty ? key : null, settled: json['settled'] == true);
    } on FormatException {
      return null;
    }
  }
}

/// Reads Server-Sent Events a chunk at a time: only `event: change` blocks with their data become changes.
class ChangeEventParser {
  String _buffer = '';
  String? _event;
  final List<String> _data = [];

  List<Change> add(String chunk) {
    _buffer += chunk.replaceAll('\r\n', '\n');
    final out = <Change>[];
    int newline;
    while ((newline = _buffer.indexOf('\n')) >= 0) {
      final line = _buffer.substring(0, newline);
      _buffer = _buffer.substring(newline + 1);
      if (line.isEmpty) {
        if (_event == 'change' && _data.isNotEmpty) {
          final change = Change.tryParse(_data.join('\n'));
          if (change != null) out.add(change);
        }
        _event = null;
        _data.clear();
      } else if (line.startsWith('event:')) {
        _event = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        _data.add(line.substring(5).trimLeft());
      }
      // `:` comments (the heartbeat), `retry:`, `id:` — nothing to do.
    }
    return out;
  }
}

/// The stream of changes from the server the app talks to — the hub's `/api/mobile/changes` when wired, LunAcedia's
/// `/api/changes` otherwise, with the device's token. Open only while the app is in front (battery): the shell starts
/// it when the app comes up and stops it when it leaves. A dropped connection is opened again after a growing wait;
/// a refused token stops it (the pairing banner says why).
class ChangeStream {
  ChangeStream(this._config, {http.Client Function()? client, Duration Function(int attempt)? backoff})
      : _newClient = client ?? http.Client.new,
        _backoff = backoff ?? defaultBackoff;

  final ApiConfig _config;
  final http.Client Function() _newClient;
  final Duration Function(int attempt) _backoff;
  final _changes = StreamController<Change>.broadcast();

  http.Client? _client;
  bool _running = false;
  int _generation = 0;

  /// 1 s, 2 s, 4 s… up to 30 s.
  static Duration defaultBackoff(int attempt) => Duration(seconds: attempt >= 5 ? 30 : 1 << attempt);

  Stream<Change> get changes => _changes.stream;

  bool get running => _running;

  String get _path => _config.wired ? '/api/mobile/changes' : '/api/changes';

  void start() {
    if (_running || _config.baseUrl.isEmpty || _config.token.isEmpty) return;
    _running = true;
    unawaited(_run(++_generation));
  }

  void stop() {
    _running = false;
    _generation++;
    _client?.close();
    _client = null;
  }

  Future<void> dispose() async {
    stop();
    await _changes.close();
  }

  Future<void> _run(int generation) async {
    var attempt = 0;
    while (_running && generation == _generation) {
      final client = _newClient();
      _client = client;
      try {
        final uri = Uri.parse('${_config.baseUrl}$_path');
        final request = http.Request('GET', uri)
          ..headers.addAll({'Accept': 'text/event-stream', 'Authorization': 'Bearer ${_config.token}'});
        final response = await client.send(request);
        if (response.statusCode == 401 || response.statusCode == 403) {
          _running = false;
          return;
        }
        if (response.statusCode == 200) {
          attempt = 0;
          final parser = ChangeEventParser();
          await for (final chunk in response.stream.transform(utf8.decoder)) {
            if (generation != _generation) return;
            for (final change in parser.add(chunk)) {
              if (!_changes.isClosed) _changes.add(change);
            }
          }
        }
      } catch (_) {
        // out of reach, or closed by stop(): the loop decides
      } finally {
        client.close();
      }
      if (!_running || generation != _generation) return;
      await Future<void>.delayed(_backoff(attempt++));
    }
  }
}

/// Gathers a burst of changes: [onScope] is called once per scope, a short while after the burst's first change — a
/// steady flow never holds it back.
class ChangeBursts {
  ChangeBursts(this.onScope, {this.window = const Duration(milliseconds: 300)});

  final void Function(String scope, List<Change> changes) onScope;
  final Duration window;
  final Map<String, Timer> _timers = {};
  final Map<String, List<Change>> _pending = {};

  void add(Change change) {
    (_pending[change.scope] ??= []).add(change);
    if (_timers.containsKey(change.scope)) return;
    _timers[change.scope] = Timer(window, () {
      _timers.remove(change.scope);
      final changes = _pending.remove(change.scope) ?? const [];
      if (changes.isNotEmpty) onScope(change.scope, changes);
    });
  }

  void cancel() {
    for (final t in _timers.values) {
      t.cancel();
    }
    _timers.clear();
    _pending.clear();
  }
}
