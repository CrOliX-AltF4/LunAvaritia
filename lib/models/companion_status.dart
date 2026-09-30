/// The hub companion's state (mood, energy, affinity) — only meaningful wired to the hub
/// ([AssistantIdentity.isCompanion]); LunAcedia on its own has none.
class CompanionStatus {
  CompanionStatus({
    required this.mood,
    required this.energy,
    required this.affinityTier,
    required this.pendingAlerts,
  });

  final String mood;
  final double energy;
  // The hub's /api/mobile/status has always sent this as a number (1-5, see
  // admin_router.ts's affinityTier() helper) — this was previously typed and cast
  // as a String, which threw on every single call (Dart's `as String?` throws a
  // TypeError on a non-null, non-String value; it does not return null).
  final int affinityTier;
  final int pendingAlerts;

  factory CompanionStatus.fromJson(Map<String, dynamic> json) {
    return CompanionStatus(
      mood:          json['mood'] as String? ?? 'neutral',
      energy:        (json['energy'] as num?)?.toDouble() ?? 0.5,
      affinityTier:  (json['affinityTier'] as num?)?.toInt() ?? 0,
      pendingAlerts: json['pendingAlerts'] as int? ?? 0,
    );
  }

  static CompanionStatus get empty =>
      CompanionStatus(mood: 'neutral', energy: 0.5, affinityTier: 0, pendingAlerts: 0);
}
