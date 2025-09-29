class Challenge {
  final String id;
  final String lessonId;
  final String type; // e.g., 'select-translation', 'match-pairs', etc.
  final String interactionPattern; // canonical pattern key to drive UI behavior
  final String hint;
  final String? promptText;
  final String? promptAudio;
  final String? promptImage;
  final String? feedbackCorrect;
  final String? feedbackIncorrect;
  final String? explanation;
  final List<ChallengeOption> options;

  Challenge({
    required this.id,
    required this.lessonId,
    required this.type,
    required this.interactionPattern,
    required this.hint,
    this.promptText,
    this.promptAudio,
    this.promptImage,
    this.feedbackCorrect,
    this.feedbackIncorrect,
    this.explanation,
    this.options = const [],
  });

  Challenge copyWith({
    List<ChallengeOption>? options,
    String? hint,
  }) {
    return Challenge(
      id: id,
      lessonId: lessonId,
      type: type,
      interactionPattern: interactionPattern,
      hint: hint ?? this.hint,
      promptText: promptText,
      promptAudio: promptAudio,
      promptImage: promptImage,
      feedbackCorrect: feedbackCorrect,
      feedbackIncorrect: feedbackIncorrect,
      explanation: explanation,
      options: options ?? this.options,
    );
  }

  factory Challenge.fromFirestore(Map<String, dynamic> doc, String id) {
    return Challenge(
      id: id,
      lessonId: doc['lesson_id'] ?? '',
      type: doc['type'] ?? '',
      interactionPattern: doc['interaction_pattern'] ?? '',
      hint: doc['hint'] ?? '',
      promptText: doc['prompt_text'],
      promptAudio: doc['prompt_audio'],
      promptImage: doc['prompt_image'],
      feedbackCorrect: doc['feedback_correct'],
      feedbackIncorrect: doc['feedback_incorrect'],
      explanation: doc['explanation'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'lesson_id': lessonId,
      'type': type,
      'interaction_pattern': interactionPattern,
      'hint': hint,
      'prompt_text': promptText,
      'prompt_audio': promptAudio,
      'prompt_image': promptImage,
      'feedback_correct': feedbackCorrect,
      'feedback_incorrect': feedbackIncorrect,
      'explanation': explanation,
    };
  }
}

class ChallengeOption {
  final String id;
  final String challengeId;
  final String? itemType; // e.g., 'pair_left', 'pair_right' for matching
  final String? contentText;
  final String? contentAudio;
  final String? contentImage;
  final int displayOrder; // also used as pair key for matching
  final bool isCorrect;

  ChallengeOption({
    required this.id,
    required this.challengeId,
    this.itemType,
    this.contentText,
    this.contentAudio,
    this.contentImage,
    required this.displayOrder,
    required this.isCorrect,
  });

  factory ChallengeOption.fromFirestore(Map<String, dynamic> doc, String id) {
    final orderRaw = doc['display_order'];
    return ChallengeOption(
      id: id,
      challengeId: doc['challenge_id'] ?? '',
      itemType: doc['item_type'],
      contentText: doc['content_text'],
      contentAudio: doc['content_audio'],
      contentImage: doc['content_image'],
      displayOrder: orderRaw is num ? orderRaw.toInt() : 0,
      isCorrect: (doc['is_correct'] ?? false) as bool,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'challenge_id': challengeId,
      'item_type': itemType,
      'content_text': contentText,
      'content_audio': contentAudio,
      'content_image': contentImage,
      'display_order': displayOrder,
      'is_correct': isCorrect,
    };
  }
}