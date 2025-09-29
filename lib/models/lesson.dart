class Lesson {
  final String id;
  final String levelId;
  final String title;
  final String description;
  final int orderIndex;
  final int estimatedTimeMinutes;
  final int xpReward;
  final DateTime createdAt;

  Lesson({
    required this.id,
    required this.levelId,
    required this.title,
    required this.description,
    required this.orderIndex,
    required this.estimatedTimeMinutes,
    required this.xpReward,
    required this.createdAt,
  });

  factory Lesson.fromFirestore(Map<String, dynamic> doc, String id) {
    return Lesson(
      id: id,
      levelId: doc['level_id'] ?? '',
      title: doc['title'] ?? '',
      description: doc['description'] ?? '',
      orderIndex: doc['order_index'] ?? 0,
      estimatedTimeMinutes: doc['estimated_time_minutes'] ?? 5,
      xpReward: doc['xp_reward'] ?? 10,
      createdAt: doc['created_at']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'level_id': levelId,
      'title': title,
      'description': description,
      'order_index': orderIndex,
      'estimated_time_minutes': estimatedTimeMinutes,
      'xp_reward': xpReward,
      'created_at': createdAt,
    };
  }
}