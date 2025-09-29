import 'package:cloud_firestore/cloud_firestore.dart';

/// A single, consolidated Firestore seeding script.
///
/// Invoke FirestoreSeeder.run() from a one-off place in your app (e.g.,
/// a temporary call in main) when you need to populate development data.
/// No UI hooks, no auto-run.
class FirestoreSeeder {
  FirestoreSeeder._();

  /// Seeds Sections → Units → Levels → Lessons → Challenges in Firestore.
  ///
  /// If reset is true, it will delete existing docs in the target collections
  /// before writing fresh sample data.
  static Future<void> run({
    bool reset = false,
    String courseId = 'spanish_es',
    String sectionTitle = 'Basics 1',
    String sectionDescription = 'Start with greetings and simple phrases',
    int unitsPerSection = 2,
    int levelsPerUnit = 6,
    int lessonsPerLevel = 5,
    int challengesPerLesson = 4,
  }) async {
    final db = FirebaseFirestore.instance;

    print('FirestoreSeeder: starting run(reset: $reset, courseId: $courseId, unitsPerSection: $unitsPerSection, levelsPerUnit: $levelsPerUnit, lessonsPerLevel: $lessonsPerLevel, challengesPerLesson: $challengesPerLesson)');

    if (reset) {
      await _resetCollections(db);
    }

    // If there is already at least one section, skip seeding.
    final existing = await db.collection('sections').limit(1).get();
    if (existing.docs.isNotEmpty) {
      print('FirestoreSeeder: skipping seeding because sections already exist (>=1). Use reset:true to force reseed.');
      return;
    }

    // 1) Section
    final sectionRef = await db.collection('sections').add({
      'course_id': courseId,
      'title': sectionTitle,
      'description': sectionDescription,
      'order_index': 0,
      'unlock_criteria': null,
      'color_theme': 'green',
      'created_at': FieldValue.serverTimestamp(),
    });
    print('FirestoreSeeder: created section ' + sectionRef.id);

    // 2) Units
    final unitRefs = <DocumentReference>[];
    for (int u = 0; u < unitsPerSection; u++) {
      final unitRef = await db.collection('units').add({
        'section_id': sectionRef.id,
        'title': u == 0 ? 'Greetings' : 'Essentials ${u + 1}',
        'description': u == 0 ? 'Hola, Adiós, Gracias' : 'Sí, No, Por favor',
        'order_index': u,
        'created_at': FieldValue.serverTimestamp(),
      });
      unitRefs.add(unitRef);
    }

    print('FirestoreSeeder: created ' + unitRefs.length.toString() + ' units.');

    // 3) Levels (batch)
    final levelsBatch = db.batch();
    final levelRefs = <DocumentReference>[];
    for (final unitRef in unitRefs) {
      for (int i = 0; i < levelsPerUnit; i++) {
        final docRef = db.collection('levels').doc();
        levelsBatch.set(docRef, {
          'unit_id': unitRef.id,
          'title': 'Level ${i + 1}',
          'order_index': i,
          'unlock_criteria': i == 0 ? null : {'requires_level': i},
          'created_at': FieldValue.serverTimestamp(),
        });
        levelRefs.add(docRef);
      }
    }
    await levelsBatch.commit();
    print('FirestoreSeeder: created ' + levelRefs.length.toString() + ' levels.');

    // 4) Lessons and 5) Challenges (chunked batches for safety)
    // Each level gets [lessonsPerLevel] lessons; each lesson gets [challengesPerLesson] challenges.
    final challengeTypes = [
      {'type': 'select-translation', 'pattern': 'multiple_choice'},
      {'type': 'listen-tap', 'pattern': 'audio_tokens'},
      {'type': 'type-what-you-hear', 'pattern': 'audio_free_text'},
      {'type': 'match-pairs', 'pattern': 'pair_matching'},
    ];

    // Prepare chunked writes (Firestore batch limit ~500)
    WriteBatch? currentLessonsBatch;
    int currentLessonsCount = 0;

    WriteBatch? currentChallengesBatch;
    int currentChallengesCount = 0;

    Future<void> commitLessonsBatch() async {
      if (currentLessonsBatch != null && currentLessonsCount > 0) {
        await currentLessonsBatch!.commit();
      }
      currentLessonsBatch = null;
      currentLessonsCount = 0;
    }

    Future<void> commitChallengesBatch() async {
      if (currentChallengesBatch != null && currentChallengesCount > 0) {
        await currentChallengesBatch!.commit();
      }
      currentChallengesBatch = null;
      currentChallengesCount = 0;
    }

    currentLessonsBatch = db.batch();
    currentChallengesBatch = db.batch();

    for (final levelRef in levelRefs) {
      for (int l = 0; l < lessonsPerLevel; l++) {
        if (currentLessonsCount >= 450) {
          await commitLessonsBatch();
          currentLessonsBatch = db.batch();
        }
        final lessonRef = db.collection('lessons').doc();
        currentLessonsBatch!.set(lessonRef, {
          'level_id': levelRef.id,
          'title': 'Lesson ${l + 1}',
          'description': 'Practice core phrases',
          'order_index': l,
          'estimated_time_minutes': 5,
          'xp_reward': 10,
          'created_at': FieldValue.serverTimestamp(),
        });
        currentLessonsCount++;

        // Challenges
        final typesToUse = challengesPerLesson <= challengeTypes.length
            ? challengeTypes.take(challengesPerLesson).toList()
            : challengeTypes;
        for (int c = 0; c < typesToUse.length; c++) {
          if (currentChallengesCount >= 450) {
            await commitChallengesBatch();
            currentChallengesBatch = db.batch();
          }
          final cfg = typesToUse[c];
          final chRef = db.collection('challenges').doc();
          currentChallengesBatch!.set(chRef, {
            'lesson_id': lessonRef.id,
            'type': cfg['type'],
            'interaction_pattern': cfg['pattern'],
            'hint': 'Tap the correct answer',
            'prompt_text': 'Hola = Hello',
          });
          currentChallengesCount++;
        }
      }
    }

    await commitLessonsBatch();
    await commitChallengesBatch();

    print('FirestoreSeeder: seeding complete. Levels: ' + levelRefs.length.toString() +
        ', lessons per level: ' + lessonsPerLevel.toString() +
        ', challenges per lesson: ' + challengesPerLesson.toString());
  }

  /// Minimal seeding for testing UI and progress with a fixed user TESTUSER1.
  /// Creates:
  /// - 1 Section (Basics 1) → 1 Unit → 1 Level → Lesson 1 with 10+ challenges (one per type family)
  /// - users/TESTUSER1 with a progress/summary doc
  static Future<void> runForTestUser({bool reset = true}) async {
    final db = FirebaseFirestore.instance;
    print('FirestoreSeeder: runForTestUser(reset: $reset)');

    if (reset) {
      await _resetCollections(db);
      // Also clear TESTUSER1 progress
      final userDoc = db.collection('users').doc('TESTUSER1');
      final userSnap = await userDoc.get();
      if (userSnap.exists) {
        final sub = await userDoc.collection('progress').get();
        for (final d in sub.docs) {
          await d.reference.delete();
        }
        await userDoc.delete();
      }
      // wipe challenge_options as well
      final optsSnap = await db.collection('challenge_options').get();
      for (final d in optsSnap.docs) {
        await d.reference.delete();
      }
    }

    // Create a minimal journey
    final sectionRef = await db.collection('sections').add({
      'course_id': 'spanish_es',
      'title': 'Basics 1',
      'description': 'Start with greetings and simple phrases',
      'order_index': 0,
      'unlock_criteria': null,
      'color_theme': 'green',
      'created_at': FieldValue.serverTimestamp(),
    });

    final unitRef = await db.collection('units').add({
      'section_id': sectionRef.id,
      'title': 'Greetings',
      'description': 'Hola, Adiós, Gracias',
      'order_index': 0,
      'created_at': FieldValue.serverTimestamp(),
    });

    final levelRef = await db.collection('levels').add({
      'unit_id': unitRef.id,
      'title': 'Level 1',
      'order_index': 0,
      'unlock_criteria': null,
      'created_at': FieldValue.serverTimestamp(),
    });

    final lessonRef = await db.collection('lessons').add({
      'level_id': levelRef.id,
      'title': 'Lesson 1',
      'description': 'Practice core phrases',
      'order_index': 0,
      'estimated_time_minutes': 5,
      'xp_reward': 10,
      'created_at': FieldValue.serverTimestamp(),
    });

    // Add one challenge for each type family with real options
    // Add prompt_image and prompt_audio (TTS) where appropriate so media shows in UI
    final imgGreeting = 'https://pixabay.com/get/g7ac021aa7ddd7dfca225e06a930af9d934c259f627525271612cf16cc049e333b1e48412d4f39be185213133c208cbbaff22df014bc6b63f93c85f79f6cbef9d_1280.jpg';
    final imgGoodbye = 'https://pixabay.com/get/gd7671007b702b2fbcb2979d5ffdd34d91f955457e4ec920acc1d4c7c3c6a5fc5d07c008897c3b23ed89455e7d47d73efed2de477f7782891a2456a70dfaa857b_1280.jpg';
    final imgThanks = 'https://pixabay.com/get/g0fdb8f1ad25c7c5b135eae781fb1ef02ccde143165d08aab2d567086fb5814c328e01eb65ce21d4f640a2f93a4c5f043e8cd1089d621152931fb64f90def51f3_1280.jpg';
    final imgStudent = 'https://pixabay.com/get/ge54e2987b172d89f537f4977917c24ff95889cdf4053e231bddca2488f955da49ffa4df29559495180bde44c0aa9cec8b34d13015a27783374fccda77f51ad40_1280.jpg';
    final imgMorning = 'https://pixabay.com/get/g43197b27344277c195cb61a7c045bc2dc07a84b9bb0607a1f5256d8af087de6604f02da7b0b845d2be5247eaae6b3b25f1c4b46039c4f7e3167525b9977eb9f4_1280.jpg';
    
    final List<Map<String, String?>> challengeDefs = [
      {
        'type': 'select-translation',
        'pattern': 'multiple_choice',
        'prompt': 'Hola = ?',
        'prompt_image': imgGreeting,
        'prompt_audio': 'tts: hola',
      },
      {
        'type': 'true-false',
        'pattern': 'multiple_choice',
        'prompt': '"Gracias" means "Thank you."',
        'prompt_image': imgThanks,
        'prompt_audio': 'tts: gracias',
      },
      {
        'type': 'select-multiple',
        'pattern': 'multiple_choice_multi',
        'prompt': 'Select all greetings',
        'prompt_image': imgGreeting,
        'prompt_audio': 'tts: hola buenos días',
      },
      {
        'type': 'choose-correct-picture',
        'pattern': 'multiple_choice',
        'prompt': 'Which is "Adiós"?',
        'prompt_image': imgGoodbye,
        'prompt_audio': 'tts: adiós',
      },
      {
        'type': 'complete-sentence',
        'pattern': 'word_bank_order',
        'prompt': 'Form the sentence: Yo soy estudiante',
        'prompt_image': imgStudent,
        'prompt_audio': 'tts: Yo soy estudiante',
      },
      {
        'type': 'tap-words',
        'pattern': 'word_bank_order',
        'prompt': 'Build: Hasta luego',
        'prompt_image': imgGreeting,
        'prompt_audio': 'tts: Hasta luego',
      },
      {
        'type': 'match-pairs',
        'pattern': 'pair_matching',
        'prompt': 'Match pairs',
        'prompt_image': null,
        'prompt_audio': null,
      },
      {
        'type': 'type-translation',
        'pattern': 'free_text',
        'prompt': 'Translate: Buenos días',
        'prompt_image': imgMorning,
        'prompt_audio': 'tts: Buenos días',
      },
      {
        'type': 'type-what-you-hear',
        'pattern': 'audio_free_text',
        'prompt': 'Type what you hear: hola',
        'prompt_image': null,
        'prompt_audio': 'tts: hola',
      },
      {
        'type': 'listen-choose',
        'pattern': 'multiple_choice',
        'prompt': 'Which word did you hear? "gracias"',
        'prompt_image': null,
        'prompt_audio': 'tts: gracias',
      },
    ];

    final List<DocumentReference> challengeRefs = [];
    for (final def in challengeDefs) {
      final chRef = db.collection('challenges').doc();
      await chRef.set({
        'lesson_id': lessonRef.id,
        'type': def['type'],
        'interaction_pattern': def['pattern'],
        'hint': 'Do your best! You got this.',
        'prompt_text': def['prompt'],
        'prompt_audio': def['prompt_audio'],
        'prompt_image': def['prompt_image'],
      });
      challengeRefs.add(chRef);
    }

    // Create options for each challenge according to its pattern
    Future<void> addOption(DocumentReference chRef, {
      required int order,
      String? itemType,
      String? text,
      String? audio,
      String? image,
      bool correct = false,
    }) async {
      final optRef = db.collection('challenge_options').doc();
      await optRef.set({
        'challenge_id': chRef.id,
        'item_type': itemType,
        'content_text': text,
        'content_audio': audio,
        'content_image': image,
        'display_order': order,
        'is_correct': correct,
      });
    }

    // 1) select-translation: Hola = ? -> Hello (correct)
    {
      final chRef = challengeRefs[0];
      await addOption(chRef, order: 1, text: 'Hello', audio: 'tts: hello', correct: true);
      await addOption(chRef, order: 2, text: 'Goodbye', audio: 'tts: goodbye');
      await addOption(chRef, order: 3, text: 'Please', audio: 'tts: please');
    }

    // 2) true-false: "Gracias" means "Thank you". -> True
    {
      final chRef = challengeRefs[1];
      await addOption(chRef, order: 1, text: 'True', audio: 'tts: true', correct: true);
      await addOption(chRef, order: 2, text: 'False', audio: 'tts: false', correct: false);
    }

    // 3) select-multiple: Select all greetings -> Hola, Buenos días
    {
      final chRef = challengeRefs[2];
      await addOption(chRef, order: 1, text: 'Hola', audio: 'tts: hola', correct: true);
      await addOption(chRef, order: 2, text: 'Buenos días', audio: 'tts: buenos días', correct: true);
      await addOption(chRef, order: 3, text: 'Gracias', audio: 'tts: gracias');
      await addOption(chRef, order: 4, text: 'Adiós', audio: 'tts: adiós');
    }

    // 4) choose-correct-picture -> treat as text MC: Adiós = Goodbye (pick 'Goodbye')
    {
      final chRef = challengeRefs[3];
      await addOption(chRef, order: 1, text: 'Goodbye', image: imgGoodbye, audio: 'tts: goodbye', correct: true);
      await addOption(chRef, order: 2, text: 'Hello', image: imgGreeting, audio: 'tts: hello');
      await addOption(chRef, order: 3, text: 'Thank you', image: imgThanks, audio: 'tts: thank you');
    }

    // 5) complete-sentence (word bank order): Yo soy estudiante
    {
      final chRef = challengeRefs[4];
      await addOption(chRef, order: 1, text: 'Yo', audio: 'tts: Yo', correct: true);
      await addOption(chRef, order: 2, text: 'soy', audio: 'tts: soy', correct: true);
      await addOption(chRef, order: 3, text: 'estudiante', audio: 'tts: estudiante', correct: true);
      await addOption(chRef, order: 4, text: 'ella', audio: 'tts: ella');
      await addOption(chRef, order: 5, text: 'el', audio: 'tts: él');
    }

    // 6) tap-words: Hasta luego
    {
      final chRef = challengeRefs[5];
      await addOption(chRef, order: 1, text: 'Hasta', audio: 'tts: hasta', correct: true);
      await addOption(chRef, order: 2, text: 'luego', audio: 'tts: luego', correct: true);
      await addOption(chRef, order: 3, text: 'manzana', audio: 'tts: manzana');
      await addOption(chRef, order: 4, text: 'por', audio: 'tts: por');
    }

    // 7) match-pairs: Hola=Hello, Gracias=Thank you, Adiós=Goodbye
    {
      final chRef = challengeRefs[6];
      // pair 1
      await addOption(chRef, order: 1, itemType: 'pair_left', text: 'Hola', audio: 'tts: hola', correct: true);
      await addOption(chRef, order: 1, itemType: 'pair_right', text: 'Hello', audio: 'tts: hello', correct: true);
      // pair 2
      await addOption(chRef, order: 2, itemType: 'pair_left', text: 'Gracias', audio: 'tts: gracias', correct: true);
      await addOption(chRef, order: 2, itemType: 'pair_right', text: 'Thank you', audio: 'tts: thank you', correct: true);
      // pair 3
      await addOption(chRef, order: 3, itemType: 'pair_left', text: 'Adiós', audio: 'tts: adiós', correct: true);
      await addOption(chRef, order: 3, itemType: 'pair_right', text: 'Goodbye', audio: 'tts: goodbye', correct: true);
    }

    // 8) type-translation: Buenos días -> good morning
    {
      final chRef = challengeRefs[7];
      await addOption(chRef, order: 1, text: 'good morning', audio: 'tts: good morning', correct: true);
      await addOption(chRef, order: 2, text: 'morning good', audio: 'tts: morning good', correct: true); // accept minor variation
    }

    // 9) type-what-you-hear: hola -> hola
    {
      final chRef = challengeRefs[8];
      await addOption(chRef, order: 1, text: 'hola', audio: 'tts: hola', correct: true);
    }

    // 10) listen-choose: "gracias" -> thank you
    {
      final chRef = challengeRefs[9];
      await addOption(chRef, order: 1, text: 'thank you', audio: 'tts: thank you', correct: true);
      await addOption(chRef, order: 2, text: 'please', audio: 'tts: please');
      await addOption(chRef, order: 3, text: 'goodbye', audio: 'tts: goodbye');
    }

    // Bootstrap TESTUSER1
    final userDoc = db.collection('users').doc('TESTUSER1');
    await userDoc.set({
      'created_at': FieldValue.serverTimestamp(),
      'email': 'testuser1@linguaflow.dev',
      'display_name': 'TEST USER1',
      'photo_url': null,
      'auth_provider': 'dummy',
    }, SetOptions(merge: true));

    await userDoc.collection('progress').doc('summary').set({
      'total_xp': 0,
      'streak_count': 0,
      'last_activity_date': FieldValue.serverTimestamp(),
      'current_course_id': 'spanish_es',
      'from_language_id': 'en',
      'to_language_id': 'es',
    });

    print('FirestoreSeeder: runForTestUser complete — minimal journey + TESTUSER1 created.');
  }

  static Future<void> _resetCollections(FirebaseFirestore db) async {
    final collections = [
      'challenge_options',
      'challenges',
      'lessons',
      'levels',
      'units',
      'sections',
    ];

    for (final name in collections) {
      QuerySnapshot snap = await db.collection(name).get();
      // chunk deletes by 450
      int idx = 0;
      while (idx < snap.docs.length) {
        final batch = db.batch();
        final slice = snap.docs.skip(idx).take(450);
        for (final d in slice) {
          batch.delete(d.reference);
        }
        await batch.commit();
        idx += 450;
      }
    }
  }
}
