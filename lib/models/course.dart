class Course {
  final String id;
  final String fromLanguageId;
  final String toLanguageId;
  final String title;
  final String description;
  final int difficultyLevel;
  final bool isActive;
  final DateTime createdAt;

  Course({
    required this.id,
    required this.fromLanguageId,
    required this.toLanguageId,
    required this.title,
    required this.description,
    required this.difficultyLevel,
    required this.isActive,
    required this.createdAt,
  });

  factory Course.fromFirestore(Map<String, dynamic> doc, String id) {
    return Course(
      id: id,
      fromLanguageId: doc['from_language_id'] ?? '',
      toLanguageId: doc['to_language_id'] ?? '',
      title: doc['title'] ?? '',
      description: doc['description'] ?? '',
      difficultyLevel: doc['difficulty_level'] ?? 1,
      isActive: doc['is_active'] ?? true,
      createdAt: doc['created_at']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'from_language_id': fromLanguageId,
      'to_language_id': toLanguageId,
      'title': title,
      'description': description,
      'difficulty_level': difficultyLevel,
      'is_active': isActive,
      'created_at': createdAt,
    };
  }
}