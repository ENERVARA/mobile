/// Authenticated user (from `GET /auth/me`). Ported from `src/types/user.ts`.
class User {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String? phone;
  final String? secondaryPhone;
  final String? dateOfBirth;
  final String? sex; // male | female | intersex | prefer_not_to_say
  final String? state;
  final String? city;
  final String? avatar;
  final String? bloodGroup;
  final bool isVerified;
  final String? provider; // email | google
  final bool onboardingCompleted;
  final String? createdAt;
  // Basics captured on the post-signup onboarding modal — used for the SOAP
  // note's patient-demographics card (age/BMI), same source as `/auth/me`.
  final double? heightCm;
  final double? weightKg;

  const User({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.secondaryPhone,
    this.dateOfBirth,
    this.sex,
    this.state,
    this.city,
    this.avatar,
    this.bloodGroup,
    this.isVerified = false,
    this.provider,
    this.onboardingCompleted = false,
    this.createdAt,
    this.heightCm,
    this.weightKg,
  });

  String get fullName => '$firstName $lastName'.trim();

  String get initial {
    final f = firstName.trim();
    if (f.isNotEmpty) return f[0].toUpperCase();
    final e = email.trim();
    return e.isNotEmpty ? e[0].toUpperCase() : '?';
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      email: (json['email'] ?? '') as String,
      firstName: (json['firstName'] ?? '') as String,
      lastName: (json['lastName'] ?? '') as String,
      phone: json['phone'] as String?,
      secondaryPhone: json['secondaryPhone'] as String?,
      dateOfBirth: json['dateOfBirth'] as String?,
      sex: json['sex'] as String?,
      state: json['state'] as String?,
      city: json['city'] as String?,
      avatar: json['avatar'] as String?,
      bloodGroup: json['bloodGroup'] as String?,
      isVerified: json['isVerified'] == true,
      provider: json['provider'] as String?,
      onboardingCompleted: json['onboardingCompleted'] == true,
      createdAt: json['createdAt'] as String?,
      heightCm: (json['heightCm'] as num?)?.toDouble(),
      weightKg: (json['weightKg'] as num?)?.toDouble(),
    );
  }

  User copyWith({
    String? firstName,
    String? lastName,
    String? phone,
    String? secondaryPhone,
    String? dateOfBirth,
    String? sex,
    bool? onboardingCompleted,
  }) {
    return User(
      id: id,
      email: email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      secondaryPhone: secondaryPhone ?? this.secondaryPhone,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      sex: sex ?? this.sex,
      state: state,
      city: city,
      avatar: avatar,
      bloodGroup: bloodGroup,
      isVerified: isVerified,
      provider: provider,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      createdAt: createdAt,
      heightCm: heightCm,
      weightKg: weightKg,
    );
  }
}
