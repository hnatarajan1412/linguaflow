class Level {
  final String id;
  final String unitId;
  final String title;
  final int orderIndex;
  final Map<String, dynamic>? unlockCriteria;
  final DateTime createdAt;

  Level({
    required this.id,
    required this.unitId,
    required this.title,
    required this.orderIndex,
    this.unlockCriteria,
    required this.createdAt,
  });

  factory Level.fromFirestore(Map<String, dynamic> doc, String id) {
    return Level(
      id: id,
      unitId: doc['unit_id'] ?? '',
      title: doc['title'] ?? '',
      orderIndex: doc['order_index'] ?? 0,
      unlockCriteria: (doc['unlock_criteria'] as Map<String, dynamic>?),
      createdAt: doc['created_at']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'unit_id': unitId,
      'title': title,
      'order_index': orderIndex,
      'unlock_criteria': unlockCriteria,
      'created_at': createdAt,
    };
  }
}