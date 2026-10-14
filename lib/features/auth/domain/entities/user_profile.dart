class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    this.name,
    this.avatarUrl,
    this.currency = 'USD',
    this.onboardingDone = false,
  });

  final String id;
  final String email;
  final String? name;
  final String? avatarUrl;
  final String currency;
  final bool onboardingDone;

  /// The name to show to the user, or null when none is set. A stored name
  /// that is really an email address (it contains '@') counts as not set.
  String? get displayName {
    final trimmed = name?.trim();
    if (trimmed == null || trimmed.isEmpty || trimmed.contains('@')) return null;
    return trimmed;
  }

  UserProfile copyWith({
    String? name,
    String? avatarUrl,
    String? currency,
    bool? onboardingDone,
  }) {
    return UserProfile(
      id: id,
      email: email,
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      currency: currency ?? this.currency,
      onboardingDone: onboardingDone ?? this.onboardingDone,
    );
  }
}
