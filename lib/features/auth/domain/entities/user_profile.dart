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
