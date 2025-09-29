import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserProgressService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw StateError('No authenticated user');
    }
    return uid;
  }

  // Ensure base docs exist and summary fields initialized for the current user
  Future<void> _ensureUserDocs() async {
    final user = _auth.currentUser;
    if (user == null) throw StateError('No authenticated user');
    final userDoc = _db.collection('users').doc(user.uid);
    final snap = await userDoc.get();
    if (!snap.exists) {
      await userDoc.set({
        'created_at': FieldValue.serverTimestamp(),
        'email': user.email,
        'display_name': user.displayName ?? (user.email ?? 'Learner'),
        'photo_url': user.photoURL,
        'auth_provider': user.providerData.isNotEmpty ? user.providerData.first.providerId : 'password',
      }, SetOptions(merge: true));
    } else {
      // keep profile fresh
      await userDoc.set({
        'email': user.email,
        'display_name': user.displayName ?? (user.email ?? 'Learner'),
        'photo_url': user.photoURL,
      }, SetOptions(merge: true));
    }

    final summaryDoc = userDoc.collection('progress').doc('summary');
    final summarySnap = await summaryDoc.get();
    if (!summarySnap.exists) {
      await summaryDoc.set({
        'total_xp': 0,
        'streak_count': 0,
        'last_activity_date': FieldValue.serverTimestamp(),
        'current_course_id': 'spanish_es',
        'from_language_id': 'en',
        'to_language_id': 'es',
        'hearts': 5,
        'max_hearts': 5,
        'gems': 100,
        'daily_goal_xp': 20,
      });
    } else {
      // Ensure missing fields are backfilled
      await summaryDoc.set({
        'hearts': summarySnap.data()?['hearts'] ?? 5,
        'max_hearts': summarySnap.data()?['max_hearts'] ?? 5,
        'gems': summarySnap.data()?['gems'] ?? 0,
        'daily_goal_xp': summarySnap.data()?['daily_goal_xp'] ?? 20,
      }, SetOptions(merge: true));
    }
  }

  // Live summary stream
  Stream<DocumentSnapshot<Map<String, dynamic>>> summaryDocStream() {
    final uid = _uid; // throws if not signed-in, which is fine because UI is gated by auth
    final ref = _db.collection('users').doc(uid).collection('progress').doc('summary');
    return ref.snapshots();
  }

  Future<Map<String, dynamic>> getSummary() async {
    await _ensureUserDocs();
    final ref = _db.collection('users').doc(_uid).collection('progress').doc('summary');
    final snap = await ref.get();
    return snap.data() ?? {};
  }

  // XP update helper (+ streak + weekly leaderboard)
  Future<void> addXp(int amount) async {
    await _ensureUserDocs();
    final uid = _uid;
    final user = _auth.currentUser!;
    final summary = _db.collection('users').doc(uid).collection('progress').doc('summary');

    await _db.runTransaction((txn) async {
      final snap = await txn.get(summary);
      final current = (snap.data()?['total_xp'] ?? 0) as int;
      txn.set(summary, {
        'total_xp': current + amount,
        'last_activity_date': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });

    // Streak: if new day, increment
    await incrementStreakIfNewDay();

    // Weekly leaderboard (simple global bucket): leaderboards/global/weekly/{uid}
    final lbRef = _db.collection('leaderboards').doc('global').collection('weekly').doc(uid);
    await _db.runTransaction((txn) async {
      final snap = await txn.get(lbRef);
      final current = (snap.data()?['xp'] ?? 0) as int;
      txn.set(lbRef, {
        'name': user.displayName ?? (user.email ?? 'Learner'),
        'photo_url': user.photoURL,
        'xp': current + amount,
        'updated_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  // Hearts
  Future<int> getHearts() async {
    await _ensureUserDocs();
    final s = await getSummary();
    return (s['hearts'] ?? 5) as int;
  }

  Future<void> loseHeart({int amount = 1}) async {
    await _ensureUserDocs();
    final summary = _db.collection('users').doc(_uid).collection('progress').doc('summary');
    await _db.runTransaction((txn) async {
      final snap = await txn.get(summary);
      final current = (snap.data()?['hearts'] ?? 5) as int;
      final next = current - amount;
      txn.set(summary, {
        'hearts': next < 0 ? 0 : next,
        'last_activity_date': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> addHearts(int amount) async {
    await _ensureUserDocs();
    final summary = _db.collection('users').doc(_uid).collection('progress').doc('summary');
    await _db.runTransaction((txn) async {
      final snap = await txn.get(summary);
      final current = (snap.data()?['hearts'] ?? 5) as int;
      final max = (snap.data()?['max_hearts'] ?? 5) as int;
      final next = current + amount;
      txn.set(summary, {
        'hearts': next > max ? max : next,
        'last_activity_date': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  // Gems
  Future<int> getGems() async {
    await _ensureUserDocs();
    final s = await getSummary();
    return (s['gems'] ?? 0) as int;
  }

  Future<bool> spendGems(int amount) async {
    await _ensureUserDocs();
    final summary = _db.collection('users').doc(_uid).collection('progress').doc('summary');
    bool ok = false;
    await _db.runTransaction((txn) async {
      final snap = await txn.get(summary);
      final current = (snap.data()?['gems'] ?? 0) as int;
      if (current >= amount) {
        txn.set(summary, {'gems': current - amount}, SetOptions(merge: true));
        ok = true;
      } else {
        ok = false;
      }
    });
    return ok;
  }

  Future<void> addGems(int amount) async {
    await _ensureUserDocs();
    final summary = _db.collection('users').doc(_uid).collection('progress').doc('summary');
    await _db.runTransaction((txn) async {
      final snap = await txn.get(summary);
      final current = (snap.data()?['gems'] ?? 0) as int;
      txn.set(summary, {'gems': current + amount}, SetOptions(merge: true));
    });
  }

  // Streak helpers (simplified)
  Future<void> incrementStreakIfNewDay() async {
    await _ensureUserDocs();
    final summary = _db.collection('users').doc(_uid).collection('progress').doc('summary');
    await _db.runTransaction((txn) async {
      final snap = await txn.get(summary);
      final last = (snap.data()?['last_activity_date'] as Timestamp?)?.toDate();
      final now = DateTime.now();
      bool sameUtcDay = false;
      if (last != null) {
        sameUtcDay = last.toUtc().year == now.toUtc().year && last.toUtc().month == now.toUtc().month && last.toUtc().day == now.toUtc().day;
      }
      if (!sameUtcDay) {
        final streak = (snap.data()?['streak_count'] ?? 0) as int;
        txn.set(summary, {
          'streak_count': streak + 1,
          'last_activity_date': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    });
  }

  // Levels -> completed lessons
  Future<int> getCompletedLessonsCount(String levelId) async {
    await _ensureUserDocs();
    final doc = await _db
        .collection('users')
        .doc(_uid)
        .collection('progress')
        .doc('levels')
        .collection('by_id')
        .doc(levelId)
        .get();
    return (doc.data()?['completed_lessons'] ?? 0) as int;
  }

  Future<void> setCompletedLessonsCount(String levelId, int count) async {
    await _ensureUserDocs();
    final ref = _db
        .collection('users')
        .doc(_uid)
        .collection('progress')
        .doc('levels')
        .collection('by_id')
        .doc(levelId);
    await ref.set({'completed_lessons': count, 'updated_at': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  Future<void> incrementCompletedLessons(String levelId) async {
    await _ensureUserDocs();
    final ref = _db
        .collection('users')
        .doc(_uid)
        .collection('progress')
        .doc('levels')
        .collection('by_id')
        .doc(levelId);
    await _db.runTransaction((txn) async {
      final snap = await txn.get(ref);
      final current = (snap.data()?['completed_lessons'] ?? 0) as int;
      txn.set(ref, {'completed_lessons': current + 1, 'updated_at': FieldValue.serverTimestamp()}, SetOptions(merge: true));
    });
  }

  // Lessons -> completed exercises
  Future<int> getCompletedExercisesCount(String lessonId) async {
    await _ensureUserDocs();
    final ref = _db
        .collection('users')
        .doc(_uid)
        .collection('progress')
        .doc('lessons')
        .collection('by_id')
        .doc(lessonId);
    final snap = await ref.get();
    return (snap.data()?['completed_exercises'] ?? 0) as int;
  }

  Future<void> setCompletedExercisesCount(String lessonId, int count) async {
    await _ensureUserDocs();
    final ref = _db
        .collection('users')
        .doc(_uid)
        .collection('progress')
        .doc('lessons')
        .collection('by_id')
        .doc(lessonId);
    await ref.set({'completed_exercises': count, 'updated_at': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  Future<void> resetExercisesForLesson(String lessonId) async {
    await setCompletedExercisesCount(lessonId, 0);
  }
}
