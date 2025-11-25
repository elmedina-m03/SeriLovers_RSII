/// Model representing a Challenge
class Challenge {
  final int id;
  final String name;
  final String? description;
  final String difficulty; // Easy, Medium, Hard, Expert
  final int targetCount;
  final int participantsCount;
  final DateTime? createdAt;

  Challenge({
    required this.id,
    required this.name,
    this.description,
    required this.difficulty,
    required this.targetCount,
    required this.participantsCount,
    this.createdAt,
  });

  /// Creates a Challenge instance from JSON
  factory Challenge.fromJson(Map<String, dynamic> json) {
    return Challenge(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      difficulty: json['difficulty'] is String 
          ? json['difficulty'] as String
          : _difficultyToString(json['difficulty'] as int? ?? 1),
      targetCount: json['targetCount'] as int,
      participantsCount: json['participantsCount'] as int? ?? 0,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt'] as String)
          : null,
    );
  }

  /// Converts difficulty enum value to string
  static String _difficultyToString(int value) {
    switch (value) {
      case 1:
        return 'Easy';
      case 2:
        return 'Medium';
      case 3:
        return 'Hard';
      case 4:
        return 'Expert';
      default:
        return 'Easy';
    }
  }

  /// Converts Challenge instance to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'difficulty': difficulty,
      'targetCount': targetCount,
      'participantsCount': participantsCount,
      'createdAt': createdAt?.toIso8601String(),
    };
  }

  /// Legacy getter for backward compatibility
  int get participants => participantsCount;
}

