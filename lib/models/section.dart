class Section {
  final String id;
  final String courseId;
  final String title;
  final String description;
  final int orderIndex;
  final Map<String, dynamic>? unlockCriteria;
  final String colorTheme;
  final DateTime createdAt;

  Section({
    required this.id,
    required this.courseId,
    required this.title,
    required this.description,
    required this.orderIndex,
    this.unlockCriteria,
    required this.colorTheme,
    required this.createdAt,
  });

  factory Section.fromFirestore(Map<String, dynamic> doc, String id) {
    return Section(
      id: id,
      courseId: doc['course_id'] ?? '',
      title: doc['title'] ?? '',
      description: doc['description'] ?? '',
      orderIndex: doc['order_index'] ?? 0,
      unlockCriteria: (doc['unlock_criteria'] as Map<String, dynamic>?),
      colorTheme: doc['color_theme'] ?? 'blue',
      createdAt: doc['created_at']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'course_id': courseId,
      'title': title,
      'description': description,
      'order_index': orderIndex,
      'unlock_criteria': unlockCriteria,
      'color_theme': colorTheme,
      'created_at': createdAt,
    };
  }
}