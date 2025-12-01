/// Model representing a User
class User {
  final int id;
  final String email;
  final String? role;
  final bool isActive;
  final String? userName;
  final String? phoneNumber;
  final String? country;
  final DateTime? dateCreated;
  final String? avatarUrl;

  User({
    required this.id,
    required this.email,
    this.role,
    required this.isActive,
    this.userName,
    this.phoneNumber,
    this.country,
    this.dateCreated,
    this.avatarUrl,
  });

  /// Creates a User instance from JSON
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as int,
      email: json['email'] as String? ?? json['userName'] as String? ?? '',
      role: json['role'] as String?,
      isActive: json['isActive'] as bool? ?? json['lockoutEnabled'] == false,
      userName: json['userName'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      country: json['country'] as String?,
      dateCreated: json['dateCreated'] != null 
          ? DateTime.parse(json['dateCreated'] as String)
          : null,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  /// Converts User instance to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'role': role,
      'isActive': isActive,
      'userName': userName,
      'phoneNumber': phoneNumber,
      'country': country,
      'dateCreated': dateCreated?.toIso8601String(),
      'avatarUrl': avatarUrl,
    };
  }

  /// Gets the status string
  String get status => isActive ? 'Active' : 'Disabled';
  
  /// Gets display name (username or email prefix)
  String get displayName => userName ?? email.split('@').first;
}

