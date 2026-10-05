/// Who the app is talking to — given by the server, never written in the app
/// (a name written in the app showed in standalone too). Standalone: LunAcedia's assistant
/// (`GET /api/identity`). Wired to the hub: the Core's character (`GET /api/mobile/identity`), a companion with a mood of her own.
class AssistantIdentity {
  const AssistantIdentity({required this.name, required this.isCompanion});

  final String name;

  /// True when the hub's companion answers — the only case where mood/energy/affinity mean anything.
  final bool isCompanion;

  /// Before the server has answered once: a neutral name, no companion.
  static const unknown = AssistantIdentity(name: 'Assistant', isCompanion: false);

  factory AssistantIdentity.fromJson(Map<String, dynamic> json) {
    final raw = json['name'];
    final name = raw is String && raw.trim().isNotEmpty ? raw.trim() : unknown.name;
    return AssistantIdentity(name: name, isCompanion: json['kind'] == 'natsume');
  }

  Map<String, dynamic> toJson() => {'name': name, 'kind': isCompanion ? 'natsume' : 'lunacedia'};
}
