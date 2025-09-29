class Unit {
  final String id;
  final String sectionId;
  final String title;
  final String description;
  final int orderIndex;
  final DateTime createdAt;

  Unit({
    required this.id,
    required this.sectionId,
    required this.title,
    required this.description,
    required this.orderIndex,
    required this.createdAt,
  });

  factory Unit.fromFirestore(Map<String, dynamic> doc, String id) {
    return Unit(
      id: id,
      sectionId: doc['section_id'] ?? '',
      title: doc['title'] ?? '',
      description: doc['description'] ?? '',
      orderIndex: doc['order_index'] ?? 0,
      createdAt: doc['created_at']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'section_id': sectionId,
      'title': title,
      'description': description,
      'order_index': orderIndex,
      'created_at': createdAt,
    };
  }
}