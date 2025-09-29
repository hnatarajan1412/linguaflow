import 'package:flutter/material.dart';
import 'package:linguaflow/models/level.dart';
import 'package:linguaflow/models/lesson.dart';
import 'package:linguaflow/models/challenge.dart';
import 'package:linguaflow/services/firebase_service.dart';
import 'package:linguaflow/services/user_progress_service.dart';
import 'package:linguaflow/widgets/challenge_player.dart';
import 'package:linguaflow/widgets/status_bar.dart';

class LessonRunnerScreen extends StatefulWidget {
  final Level level;
  final FirebaseService firebaseService;

  const LessonRunnerScreen({super.key, required this.level, required this.firebaseService});

  @override
  State<LessonRunnerScreen> createState() => _LessonRunnerScreenState();
}

class _LessonRunnerScreenState extends State<LessonRunnerScreen> {
  final UserProgressService _progress = UserProgressService();
  final ChallengePlayerController _playerController = ChallengePlayerController();

  List<Lesson> _lessons = [];
  int _currentLessonIndex = 0;
  List<Challenge> _challenges = [];
  int _currentExerciseIndex = 0;
  bool _loading = true;
  String? _error;

  // Feedback state for bottom actions
  bool _inFeedback = false; // true after pressing Check
  bool _wasCorrect = false; // result of last check

  @override
  void initState() {
    super.initState();
    _loadLevelFlow();
  }

  Future<void> _loadLevelFlow() async {
    setState(() { _loading = true; _error = null; _inFeedback = false; _wasCorrect = false; });
    try {
      final lessons = await widget.firebaseService.getLessonsForLevel(widget.level.id);
      final completedLessons = await _progress.getCompletedLessonsCount(widget.level.id);
      final lessonIndex = (completedLessons < lessons.length) ? completedLessons : 0;
      final currentLesson = lessons.isNotEmpty ? lessons[lessonIndex] : null;

      List<Challenge> challenges = [];
      int exerciseIndex = 0;
      if (currentLesson != null) {
        challenges = await widget.firebaseService.getChallengesForLesson(currentLesson.id);
        final completedExercises = await _progress.getCompletedExercisesCount(currentLesson.id);
        exerciseIndex = (completedExercises < challenges.length) ? completedExercises : 0;
      }

      setState(() {
        _lessons = lessons;
        _currentLessonIndex = lessonIndex;
        _challenges = challenges;
        _currentExerciseIndex = exerciseIndex;
        _loading = false;
        _inFeedback = false;
        _wasCorrect = false;
      });
    } catch (e) {
      setState(() { _error = 'Failed to load level: $e'; _loading = false; });
    }
  }

  Future<void> _completeCurrentExercise({required bool awardXp}) async {
    if (_challenges.isEmpty) return;

    final currentLesson = _lessons[_currentLessonIndex];
    final nextExercise = _currentExerciseIndex + 1;

    if (nextExercise < _challenges.length) {
      // advance within lesson
      await _progress.setCompletedExercisesCount(currentLesson.id, nextExercise);
      if (awardXp) {
        await _progress.addXp(5);
      }
      setState(() {
        _currentExerciseIndex = nextExercise;
        _inFeedback = false;
        _wasCorrect = false;
      });
      // ensure the next challenge starts clean
      _playerController.reset();
    } else {
      // complete lesson and go to next lesson
      await _progress.resetExercisesForLesson(currentLesson.id);
      await _progress.incrementCompletedLessons(widget.level.id);
      if (awardXp) {
        await _progress.addXp(15);
      }

      final nextLesson = _currentLessonIndex + 1;
      if (nextLesson < _lessons.length) {
        final lesson = _lessons[nextLesson];
        final challenges = await widget.firebaseService.getChallengesForLesson(lesson.id);
        await _progress.setCompletedExercisesCount(lesson.id, 0);
        setState(() {
          _currentLessonIndex = nextLesson;
          _challenges = challenges;
          _currentExerciseIndex = 0;
          _inFeedback = false;
          _wasCorrect = false;
        });
        _playerController.reset();
      } else {
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('Level complete!'),
            content: const Text('You completed all lessons in this level.'),
            actions: [
              TextButton(
                onPressed: () { Navigator.pop(context); Navigator.pop(context); },
                child: const Text('Back'),
              )
            ],
          ),
        );
      }
    }
  }

  Future<void> _handleOutOfHearts() async {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('You’re out of hearts'),
        content: const Text('Buy a refill in the shop to keep earning XP, or keep practicing without XP.'),
        actions: [
          TextButton(
            onPressed: () { Navigator.of(ctx).pop(); },
            child: const Text('Practice only'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop(); // back to journey
            },
            child: const Text('Go to Shop'),
          ),
        ],
      ),
    );
  }

  void _onCheckPressed() async {
    final ok = _playerController.checkAnswer();
    setState(() {
      _inFeedback = true;
      _wasCorrect = ok;
    });
    if (!ok) {
      await _progress.loseHeart();
      final hearts = await _progress.getHearts();
      if (hearts <= 0) {
        await _handleOutOfHearts();
      }
    }
  }

  void _onTryAgainPressed() {
    // Reset the current challenge state and return to answering mode
    _playerController.reset();
    setState(() {
      _inFeedback = false;
      _wasCorrect = false;
    });
  }

  void _onContinuePressed() {
    // Advance. Award XP only if the last check was correct
    _completeCurrentExercise(awardXp: _wasCorrect);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.level.title),
        actions: [Padding(padding: const EdgeInsets.only(right: 12), child: StatusBar())],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!))
              : _lessons.isEmpty
                  ? const Center(child: Text('No lessons yet.'))
                  : Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Lesson ${_currentLessonIndex + 1} of ${_lessons.length}',
                              style: Theme.of(context).textTheme.headlineSmall),
                          const SizedBox(height: 8),
                          Text('Exercise ${_currentExerciseIndex + 1} of ${_challenges.length}',
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 24),
                          Expanded(
                            child: _challenges.isEmpty
                                ? const Center(child: Text('No exercises in this lesson.'))
                                : _buildExerciseCard(context),
                          ),
                          const SizedBox(height: 12),
                          _buildBottomActions(),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildBottomActions() {
    if (!_inFeedback) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _onCheckPressed,
          child: const Text('Check'),
        ),
      );
    }

    if (_wasCorrect) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _onContinuePressed,
          child: const Text('Continue'),
        ),
      );
    }

    // Incorrect: show Try again + Continue
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _onTryAgainPressed,
            child: const Text('Try again'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: _onContinuePressed,
            child: const Text('Continue'),
          ),
        ),
      ],
    );
  }

  Widget _buildExerciseCard(BuildContext context) {
    final ch = _challenges[_currentExerciseIndex];
    return Card(
      color: Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ChallengePlayer(
          challenge: ch,
          firebaseService: widget.firebaseService,
          controller: _playerController,
          onAnswered: (correct) {
            // Keep ChallengePlayer free to show its own inline feedback text; we manage actions here.
          },
        ),
      ),
    );
  }
}
