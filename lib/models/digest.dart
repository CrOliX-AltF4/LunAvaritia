/// One urgent item the digest lists — chosen by LunAcedia's rules, never by the model.
class DigestUrgent {
  const DigestUrgent({required this.key, required this.title, this.priorityReason});

  /// The box item's key: a tap opens it in the reader.
  final String key;
  final String title;

  /// Why it is urgent, in LunAcedia's words (« VIP », « CI rouge sur main »).
  final String? priorityReason;

  factory DigestUrgent.fromJson(Map<String, dynamic> json) => DigestUrgent(
        key: json['key'] as String? ?? '',
        title: json['title'] as String? ?? '',
        priorityReason: json['priorityReason'] as String?,
      );
}

/// What came in and is still unread: the urgent items listed by LunAcedia, then the model's summary of the rest.
class Digest {
  const Digest({this.summary = '', this.urgent = const [], this.count = 0});

  final String summary;
  final List<DigestUrgent> urgent;

  /// Unread items in all.
  final int count;

  /// Nothing to say: no sheet.
  bool get isEmpty => summary.trim().isEmpty && urgent.isEmpty;

  factory Digest.fromJson(Map<String, dynamic> json) => Digest(
        summary: json['response'] as String? ?? '',
        urgent: [
          for (final u in (json['urgent'] as List<dynamic>? ?? const []))
            if (u is Map<String, dynamic>) DigestUrgent.fromJson(u),
        ],
        count: json['count'] as int? ?? 0,
      );
}
