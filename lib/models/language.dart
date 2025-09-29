class Language {
  final String id;
  final String code;
  final String name;
  final String nativeName;
  final String flagIconUrl;
  final bool rtl;
  final DateTime createdAt;

  Language({
    required this.id,
    required this.code,
    required this.name,
    required this.nativeName,
    required this.flagIconUrl,
    required this.rtl,
    required this.createdAt,
  });

  factory Language.fromFirestore(Map<String, dynamic> doc, String id) {
    return Language(
      id: id,
      code: doc['code'] ?? '',
      name: doc['name'] ?? '',
      nativeName: doc['native_name'] ?? '',
      flagIconUrl: doc['flag_icon_url'] ?? '',
      rtl: doc['rtl'] ?? false,
      createdAt: doc['created_at']?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'code': code,
      'name': name,
      'native_name': nativeName,
      'flag_icon_url': flagIconUrl,
      'rtl': rtl,
      'created_at': createdAt,
    };
  }
}