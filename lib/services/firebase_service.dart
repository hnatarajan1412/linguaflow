import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:linguaflow/models/section.dart';
import 'package:linguaflow/models/unit.dart';
import 'package:linguaflow/models/level.dart';
import 'package:linguaflow/models/lesson.dart';
import 'package:linguaflow/models/challenge.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;



  // Get all sections
  Future<List<Section>> getSections() async {
    try {
      final snapshot = await _db.collection('sections').orderBy('order_index').get();
      return snapshot.docs.map((doc) {
        final data = doc.data();
        final orderRaw = data['order_index'];
        final orderIndex = orderRaw is num ? orderRaw.toInt() : 0;
        final created = data['created_at'];
        return Section(
          id: doc.id,
          courseId: data['course_id'] ?? '',
          title: data['title'] ?? '',
          description: data['description'] ?? '',
          orderIndex: orderIndex,
          unlockCriteria: data['unlock_criteria'],
          colorTheme: data['color_theme'] ?? 'blue',
          createdAt: created is Timestamp ? created.toDate() : DateTime.now(),
        );
      }).toList();
    } catch (e) {
      print('Error getting sections: $e');
      rethrow;
    }
  }

  // Get units for a section (sort locally to avoid composite index requirement)
  Future<List<Unit>> getUnitsForSection(String sectionId) async {
    try {
      QuerySnapshot snapshot = await _db
          .collection('units')
          .where('section_id', isEqualTo: sectionId)
          .get();

      final units = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return Unit(
          id: doc.id,
          sectionId: data['section_id'] ?? '',
          title: data['title'] ?? '',
          description: data['description'] ?? '',
          orderIndex: (data['order_index'] ?? 0) as int,
          createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();

      units.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      return units;
    } catch (e) {
      print('Error getting units for section: $e');
      rethrow; // surface error to caller so UI can show message
    }
  }

  // Get levels for a unit (sort locally to avoid composite index requirement)
  Future<List<Level>> getLevelsForUnit(String unitId) async {
    try {
      QuerySnapshot snapshot = await _db
          .collection('levels')
          .where('unit_id', isEqualTo: unitId)
          .get();

      final levels = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        return Level(
          id: doc.id,
          unitId: data['unit_id'] ?? '',
          title: data['title'] ?? '',
          orderIndex: (data['order_index'] ?? 0) as int,
          unlockCriteria: data['unlock_criteria'],
          createdAt: (data['created_at'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();

      levels.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
      return levels;
    } catch (e) {
      print('Error getting levels for unit: $e');
      rethrow; // surface error to caller so UI can show message
    }
  }

  // Lessons for a level
  Future<List<Lesson>> getLessonsForLevel(String levelId) async {
    final snap = await _db
        .collection('lessons')
        .where('level_id', isEqualTo: levelId)
        .get();
    final lessons = snap.docs.map((doc) {
      final data = doc.data();
      return Lesson.fromFirestore(data, doc.id);
    }).toList();
    lessons.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    return lessons;
  }

  Future<int> getLessonsCountForLevel(String levelId) async {
    final lessons = await getLessonsForLevel(levelId);
    return lessons.length;
  }

  // Challenges for a lesson (with options)
  Future<List<Challenge>> getChallengesForLesson(String lessonId) async {
    final snap = await _db
        .collection('challenges')
        .where('lesson_id', isEqualTo: lessonId)
        .get();

    final challenges = <Challenge>[];
    for (final doc in snap.docs) {
      final data = doc.data();
      var ch = Challenge.fromFirestore(data, doc.id);
      final options = await getOptionsForChallenge(ch.id);
      options.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
      ch = ch.copyWith(options: options);
      challenges.add(ch);
    }
    return challenges;
  }

  Future<List<ChallengeOption>> getOptionsForChallenge(String challengeId) async {
    final snap = await _db
        .collection('challenge_options')
        .where('challenge_id', isEqualTo: challengeId)
        .get();
    return snap.docs.map((doc) {
      final data = doc.data();
      return ChallengeOption.fromFirestore(data, doc.id);
    }).toList();
  }

  // Get the journey data (sections with units and levels)
  Future<Map<String, dynamic>> getJourneyData() async {
    List<Section> sections = await getSections();
    Map<String, List<Unit>> sectionUnits = {};
    Map<String, List<Level>> unitLevels = {};

    for (Section section in sections) {
      List<Unit> units = await getUnitsForSection(section.id);
      sectionUnits[section.id] = units;
      
      for (Unit unit in units) {
        List<Level> levels = await getLevelsForUnit(unit.id);
        unitLevels[unit.id] = levels;
      }
    }

    return {
      'sections': sections,
      'sectionUnits': sectionUnits,
      'unitLevels': unitLevels,
    };
  }
}