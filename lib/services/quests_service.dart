import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class QuestsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('No authenticated user');
    return uid;
  }

  String get _todayKey {
    final now = DateTime.now().toUtc();
    // yyyy-MM-dd format to bucket quests per UTC day
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    return '${now.year}-$mm-$dd';
  }

  Future<void> ensureDailyQuests() async {
    final uid = _uid;
    final dateKey = _todayKey;
    final root = _db.collection('users').doc(uid).collection('quests').doc('daily').collection(dateKey);
    final existing = await root.limit(1).get();
    if (existing.docs.isNotEmpty) return;

    // Seed three default quests for the day
    final batch = _db.batch();
    final q1 = root.doc('streak');
    batch.set(q1, {
      'title': 'Maintain your streak',
      'subtitle': 'Complete any lesson today',
      'xp': 20,
      'completed': false,
      'order': 1,
      'created_at': FieldValue.serverTimestamp(),
    });
    final q2 = root.doc('xp30');
    batch.set(q2, {
      'title': 'Get XP',
      'subtitle': 'Earn 30 XP today',
      'xp': 30,
      'completed': false,
      'order': 2,
      'created_at': FieldValue.serverTimestamp(),
    });
    final q3 = root.doc('listening');
    batch.set(q3, {
      'title': 'Practice listening',
      'subtitle': 'Finish a listening exercise',
      'xp': 15,
      'completed': false,
      'order': 3,
      'created_at': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> todayQuestsStream() {
    final uid = _uid;
    final dateKey = _todayKey;
    final root = _db.collection('users').doc(uid).collection('quests').doc('daily').collection(dateKey);
    return root.orderBy('order').snapshots();
  }

  Future<int> completeQuest(String questId) async {
    final uid = _uid;
    final dateKey = _todayKey;
    final itemRef = _db.collection('users').doc(uid).collection('quests').doc('daily').collection(dateKey).doc(questId);
    int xpToAward = 0;
    await _db.runTransaction((txn) async {
      final snap = await txn.get(itemRef);
      final data = snap.data();
      if (data == null) return; // nothing to do
      final completed = (data['completed'] ?? false) as bool;
      if (!completed) {
        xpToAward = (data['xp'] ?? 0) as int;
        txn.set(itemRef, {'completed': true, 'completed_at': FieldValue.serverTimestamp()}, SetOptions(merge: true));
      }
    });
    return xpToAward;
  }
}
