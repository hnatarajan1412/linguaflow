class UserProgress {
  final String? currentCourseId;
  final int totalXp;
  final int streakCount;
  final DateTime? lastActivityDate;
  final String fromLanguageId;
  final String toLanguageId;

  UserProgress({
    this.currentCourseId,
    this.totalXp = 0,
    this.streakCount = 0,
    this.lastActivityDate,
    this.fromLanguageId = '',
    this.toLanguageId = '',
  });

  factory UserProgress.fromJson(Map<String, dynamic> json) {
    return UserProgress(
      currentCourseId: json['current_course_id'],
      totalXp: json['total_xp'] ?? 0,
      streakCount: json['streak_count'] ?? 0,
      lastActivityDate: json['last_activity_date'] != null 
          ? DateTime.parse(json['last_activity_date']) 
          : null,
      fromLanguageId: json['from_language_id'] ?? '',
      toLanguageId: json['to_language_id'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current_course_id': currentCourseId,
      'total_xp': totalXp,
      'streak_count': streakCount,
      'last_activity_date': lastActivityDate?.toIso8601String(),
      'from_language_id': fromLanguageId,
      'to_language_id': toLanguageId,
    };
  }

  UserProgress copyWith({
    String? currentCourseId,
    int? totalXp,
    int? streakCount,
    DateTime? lastActivityDate,
    String? fromLanguageId,
    String? toLanguageId,
  }) {
    return UserProgress(
      currentCourseId: currentCourseId ?? this.currentCourseId,
      totalXp: totalXp ?? this.totalXp,
      streakCount: streakCount ?? this.streakCount,
      lastActivityDate: lastActivityDate ?? this.lastActivityDate,
      fromLanguageId: fromLanguageId ?? this.fromLanguageId,
      toLanguageId: toLanguageId ?? this.toLanguageId,
    );
  }
}

class LessonProgress {
  final String lessonId;
  final DateTime completedAt;
  final int xpEarned;
  final int attemptsCount;

  LessonProgress({
    required this.lessonId,
    required this.completedAt,
    required this.xpEarned,
    required this.attemptsCount,
  });

  factory LessonProgress.fromJson(Map<String, dynamic> json) {
    return LessonProgress(
      lessonId: json['lesson_id'],
      completedAt: DateTime.parse(json['completed_at']),
      xpEarned: json['xp_earned'],
      attemptsCount: json['attempts_count'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lesson_id': lessonId,
      'completed_at': completedAt.toIso8601String(),
      'xp_earned': xpEarned,
      'attempts_count': attemptsCount,
    };
  }
}