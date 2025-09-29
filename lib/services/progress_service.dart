import 'package:shared_preferences/shared_preferences.dart';

class ProgressService {
  static const String _levelLessonKeyPrefix = 'level_completed_lessons_';
  static const String _lessonExerciseKeyPrefix = 'lesson_completed_exercises_';

  // LESSONS per LEVEL progress
  static Future<int> getCompletedLessonsCount(String levelId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_levelLessonKeyPrefix$levelId') ?? 0;
  }

  static Future<void> setCompletedLessonsCount(String levelId, int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_levelLessonKeyPrefix$levelId', count);
  }

  static Future<void> incrementCompletedLessons(String levelId) async {
    final current = await getCompletedLessonsCount(levelId);
    await setCompletedLessonsCount(levelId, current + 1);
  }

  // EXERCISES per LESSON progress
  static Future<int> getCompletedExercisesCount(String lessonId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_lessonExerciseKeyPrefix$lessonId') ?? 0;
  }

  static Future<void> setCompletedExercisesCount(String lessonId, int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('$_lessonExerciseKeyPrefix$lessonId', count);
  }

  static Future<void> incrementCompletedExercise(String lessonId) async {
    final current = await getCompletedExercisesCount(lessonId);
    await setCompletedExercisesCount(lessonId, current + 1);
  }

  static Future<void> resetExercisesForLesson(String lessonId) async {
    await setCompletedExercisesCount(lessonId, 0);
  }
}