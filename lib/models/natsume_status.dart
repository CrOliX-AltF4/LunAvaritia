class NatsumeStatus {
  NatsumeStatus({
    required this.mood,
    required this.energy,
    required this.affinityTier,
    required this.pendingAlerts,
  });

  final String mood;
  final double energy;
  final String affinityTier;
  final int pendingAlerts;

  factory NatsumeStatus.fromJson(Map<String, dynamic> json) {
    return NatsumeStatus(
      mood:          json['mood'] as String? ?? 'neutral',
      energy:        (json['energy'] as num?)?.toDouble() ?? 0.5,
      affinityTier:  json['affinityTier'] as String? ?? 'neutral',
      pendingAlerts: json['pendingAlerts'] as int? ?? 0,
    );
  }

  static NatsumeStatus get empty =>
      NatsumeStatus(mood: 'neutral', energy: 0.5, affinityTier: 'neutral', pendingAlerts: 0);
}
