class NatsumeStatus {
  NatsumeStatus({
    required this.mood,
    required this.energy,
    required this.affinityTier,
    required this.pendingAlerts,
  });

  final String mood;
  final double energy;
  // Natsume's /api/mobile/status has always sent this as a number (1-5, see
  // admin_router.ts's affinityTier() helper) — this was previously typed and cast
  // as a String, which threw on every single call (Dart's `as String?` throws a
  // TypeError on a non-null, non-String value; it does not return null).
  final int affinityTier;
  final int pendingAlerts;

  factory NatsumeStatus.fromJson(Map<String, dynamic> json) {
    return NatsumeStatus(
      mood:          json['mood'] as String? ?? 'neutral',
      energy:        (json['energy'] as num?)?.toDouble() ?? 0.5,
      affinityTier:  (json['affinityTier'] as num?)?.toInt() ?? 0,
      pendingAlerts: json['pendingAlerts'] as int? ?? 0,
    );
  }

  static NatsumeStatus get empty =>
      NatsumeStatus(mood: 'neutral', energy: 0.5, affinityTier: 0, pendingAlerts: 0);
}
