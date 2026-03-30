/// The role a user selects during onboarding.
enum UserRole { elder, caregiver }

/// A user profile stored in Firestore at `/users/{uid}`.
class UserProfile {
  const UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.photoUrl,
    this.linkedElderUid,
    this.linkedCaregiverUids = const [],
    this.createdAt,
  });

  final String uid;
  final String name;
  final String? email;
  final String? phone;
  final UserRole role;
  final String? photoUrl;

  /// For caregivers — the UID of the elder they are linked to.
  final String? linkedElderUid;

  /// For elders — the UIDs of caregivers linked to them.
  final List<String> linkedCaregiverUids;

  final DateTime? createdAt;

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role.name,
        'photoUrl': photoUrl,
        'linkedElderUid': linkedElderUid,
        'linkedCaregiverUids': linkedCaregiverUids,
        'createdAt': createdAt?.toIso8601String(),
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        uid: json['uid'] as String,
        name: json['name'] as String? ?? '',
        email: json['email'] as String?,
        phone: json['phone'] as String?,
        role: UserRole.values.firstWhere(
          (r) => r.name == json['role'],
          orElse: () => UserRole.elder,
        ),
        photoUrl: json['photoUrl'] as String?,
        linkedElderUid: json['linkedElderUid'] as String?,
        linkedCaregiverUids:
            List<String>.from(json['linkedCaregiverUids'] as List? ?? []),
        createdAt: json['createdAt'] != null
            ? DateTime.tryParse(json['createdAt'] as String)
            : null,
      );

  UserProfile copyWith({
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    String? photoUrl,
    String? linkedElderUid,
    List<String>? linkedCaregiverUids,
  }) =>
      UserProfile(
        uid: uid,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        role: role ?? this.role,
        photoUrl: photoUrl ?? this.photoUrl,
        linkedElderUid: linkedElderUid ?? this.linkedElderUid,
        linkedCaregiverUids: linkedCaregiverUids ?? this.linkedCaregiverUids,
        createdAt: createdAt,
      );
}
