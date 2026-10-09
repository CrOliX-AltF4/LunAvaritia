import 'http_transport.dart';

/// A write waiting for Master on LunAcedia — durable, with its own deadline.
class PendingWrite {
  PendingWrite({
    required this.id,
    required this.summary,
    required this.connector,
    required this.createdAt,
    this.expiresAt,
    this.untrusted = false,
    this.byAgent = false,
  });

  final String id;

  /// What it would do, in LunAcedia's own words (« Répondre à un mail — Noté. »).
  final String summary;
  final String connector;
  final DateTime createdAt;
  final DateTime? expiresAt;

  /// A third party's text (a mail, an issue) was read before it was proposed.
  final bool untrusted;
  final bool byAgent;

  factory PendingWrite.fromJson(Map<String, dynamic> json) {
    final action = json['action'] is Map<String, dynamic> ? json['action'] as Map<String, dynamic> : const {};
    DateTime? when(Object? ms) => ms is int ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
    return PendingWrite(
      id: json['id'] as String? ?? '',
      summary: json['summary'] as String? ?? (action['kind'] as String? ?? ''),
      connector: json['connector'] as String? ?? '',
      createdAt: when(json['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      expiresAt: when(json['expiresAt']),
      untrusted: json['untrusted'] == true,
      byAgent: json['origin'] == 'agent',
    );
  }
}

/// Something the hub's memory would keep — a fact, or an opinion — waiting for Master (write gate, D9).
class MemoryProposal {
  MemoryProposal({
    required this.id,
    required this.text,
    required this.editableText,
    required this.origin,
    required this.ts,
    this.conflictText,
    this.duplicateText,
  });

  final String id;

  /// As shown: the fact, or « subject — position ».
  final String text;

  /// What « Modifier » rewords: the fact's text, or the opinion's position.
  final String editableText;
  final String origin;
  final DateTime ts;

  /// It contradicts this published fact: the question is « which one is right? ».
  final String? conflictText;

  /// It nearly repeats this published fact: the question is « the same thing? ».
  final String? duplicateText;

  factory MemoryProposal.fromJson(Map<String, dynamic> json) {
    final payload = json['payload'] is Map<String, dynamic> ? json['payload'] as Map<String, dynamic> : const {};
    final opinion = payload['kind'] == 'upsert_opinion';
    final editable = (opinion ? payload['position'] : payload['text']) as String? ?? '';
    return MemoryProposal(
      id: json['id'] as String? ?? '',
      text: opinion ? '${payload['subject'] ?? ''} — $editable' : editable,
      editableText: editable,
      origin: json['origin'] as String? ?? '',
      ts: DateTime.fromMillisecondsSinceEpoch(json['ts'] as int? ?? 0),
      conflictText: json['conflictText'] as String?,
      duplicateText: json['duplicateText'] as String?,
    );
  }
}

/// What the hub's memory wrote without asking — what Master said about himself — shown so it can be taken back.
class UnaskedFact {
  UnaskedFact({required this.speakerId, required this.id, required this.text, required this.at, this.source});

  final String speakerId;
  final String id;
  final String text;
  final DateTime at;

  /// What Master had said, as it was captured.
  final String? source;

  factory UnaskedFact.fromJson(Map<String, dynamic> json) => UnaskedFact(
        speakerId: json['speakerId'] as String? ?? '',
        id: json['id'] as String? ?? '',
        text: json['text'] as String? ?? '',
        at: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int? ?? 0),
        source: json['source'] as String?,
      );
}

/// « À valider »: LunAcedia's pending writes in both modes — on LunAcedia directly, or relayed by
/// the hub — and, wired only, the hub's memory proposals (standalone has no long memory, D8).
class ValidationApi {
  ValidationApi(this._http,
      {required this.actionsPath, required this.pendingPath, this.proposalsPath, this.unaskedPath});

  ValidationApi.lunacedia(HttpTransport http)
      : this(http, actionsPath: '/api/actions', pendingPath: '/api/actions/pending');

  ValidationApi.hub(HttpTransport http)
      : this(
          http,
          actionsPath: '/api/mobile/actions',
          pendingPath: '/api/mobile/actions/pending',
          proposalsPath: '/api/mobile/proposals',
          unaskedPath: '/api/mobile/unasked',
        );

  final HttpTransport _http;
  final String actionsPath;
  final String pendingPath;
  final String? proposalsPath;
  final String? unaskedPath;

  bool get hasMemory => proposalsPath != null;

  /// Oldest first: the longest-waiting decision on top.
  Future<List<PendingWrite>> actions() async {
    final data = await _http.get(pendingPath);
    // LunAcedia answers a bare list; the hub wraps it ({ actions }).
    final list = data is List ? data : (asObject(data)['actions'] as List<dynamic>? ?? const []);
    return [
      for (final w in list)
        if (w is Map<String, dynamic>) PendingWrite.fromJson(w),
    ]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  /// Throws a [BackendError] saying why when the source or the tier refused.
  Future<void> decide(String id, {required bool confirm}) async {
    await _http.post('$actionsPath/${Uri.encodeComponent(id)}/${confirm ? 'confirm' : 'cancel'}');
  }

  /// Oldest first. Empty standalone.
  Future<List<MemoryProposal>> proposals() async {
    final path = proposalsPath;
    if (path == null) return const [];
    final list = asObject(await _http.get(path))['proposals'] as List<dynamic>? ?? const [];
    return [
      for (final p in list)
        if (p is Map<String, dynamic>) MemoryProposal.fromJson(p),
    ]..sort((a, b) => a.ts.compareTo(b.ts));
  }

  /// Kept — in Master's own words when [text] is given (« Modifier »).
  Future<void> approve(String id, {String? text}) async {
    final body = text != null && text.trim().isNotEmpty ? {'text': text} : null;
    await _http.post('$proposalsPath/${Uri.encodeComponent(id)}/approve', body: body);
  }

  Future<void> reject(String id) async {
    await _http.post('$proposalsPath/${Uri.encodeComponent(id)}/reject');
  }

  /// Newest first. Empty standalone (no long memory).
  Future<List<UnaskedFact>> unasked() async {
    final path = unaskedPath;
    if (path == null) return const [];
    final list = asObject(await _http.get(path))['facts'] as List<dynamic>? ?? const [];
    return [
      for (final f in list)
        if (f is Map<String, dynamic>) UnaskedFact.fromJson(f),
    ];
  }

  /// « Annuler »: the fact leaves the memory and is never written again unasked.
  Future<void> undo(UnaskedFact f) async {
    await _http.post('$unaskedPath/${Uri.encodeComponent(f.speakerId)}/${Uri.encodeComponent(f.id)}/undo');
  }
}
