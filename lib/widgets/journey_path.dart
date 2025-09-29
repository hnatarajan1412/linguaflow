import 'package:flutter/material.dart';
import 'package:linguaflow/models/section.dart';
import 'package:linguaflow/models/unit.dart';
import 'package:linguaflow/models/level.dart';
import 'package:linguaflow/services/firebase_service.dart';
import 'package:linguaflow/services/user_progress_service.dart';
import 'package:linguaflow/widgets/level_progress_ring.dart';
import 'package:linguaflow/screens/lesson_runner_screen.dart';

class JourneyPath extends StatelessWidget {
  final UserProgressService progressService = UserProgressService();
  final List<Section> sections;
  final Map<String, List<Unit>> sectionUnits;
  final Map<String, List<Level>> unitLevels;
  final FirebaseService firebaseService;

  JourneyPath({
    super.key,
    required this.sections,
    required this.sectionUnits,
    required this.unitLevels,
    required this.firebaseService,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            for (int sectionIndex = 0; sectionIndex < sections.length; sectionIndex++)
              _buildSectionJourney(context, sections[sectionIndex], sectionIndex),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionJourney(BuildContext context, Section section, int sectionIndex) {
    final units = sectionUnits[section.id] ?? [];
    
    return Column(
      children: [
        for (int unitIndex = 0; unitIndex < units.length; unitIndex++)
          _buildUnitJourney(context, section, units[unitIndex], sectionIndex + 1, unitIndex + 1),
      ],
    );
  }

  Widget _buildUnitJourney(BuildContext context, Section section, Unit unit, int sectionNumber, int unitNumber) {
    final levels = unitLevels[unit.id] ?? [];
    
    return Column(
      children: [
        // Unit Header Card
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 32.0),
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF58CC02), Color(0xFF7ED321)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SECTION $sectionNumber, UNIT $unitNumber',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      unit.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8.0),
                ),
                child: const Icon(
                  Icons.menu,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
        ),
        
        // Levels Path
        _buildLevelsPath(context, levels),
        
        const SizedBox(height: 48.0),
      ],
    );
  }

  Widget _buildLevelsPath(BuildContext context, List<Level> levels) {
    return Column(
      children: [
        for (int i = 0; i < levels.length; i++)
          _buildLevelNode(context, levels[i], i),
      ],
    );
  }

  Widget _buildLevelNode(BuildContext context, Level level, int levelIndex) {
    // For now, make first level active/unlocked and rest locked
    final bool isUnlocked = levelIndex == 0;
    final bool isActive = levelIndex == 0;
    
    return Column(
      children: [
        if (levelIndex > 0) _buildPathLine(),
        
        SizedBox(
          width: 88,
          height: 88,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Segmented ring showing lessons progress
              FutureBuilder<int>(
                future: firebaseService.getLessonsCountForLevel(level.id),
                builder: (context, lessonCountSnap) {
                  final totalLessons = lessonCountSnap.data ?? 0;
                  if (totalLessons <= 0) return const SizedBox.shrink();
                  return FutureBuilder<int>(
                    future: progressService.getCompletedLessonsCount(level.id),
                    builder: (context, completedSnap) {
                      final completed = completedSnap.data ?? 0;
                      return LevelProgressRing(
                        totalSegments: totalLessons,
                        completedSegments: completed,
                        outerRadius: 44,
                      );
                    },
                  );
                },
              ),
              
              // Level node button
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isUnlocked 
                      ? const LinearGradient(
                          colors: [Color(0xFF58CC02), Color(0xFF7ED321)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isUnlocked ? null : const Color(0xFF4B5768),
                  border: Border.all(
                    color: isActive ? const Color(0xFF58CC02) : const Color(0xFF4B5768),
                    width: 4.0,
                  ),
                  boxShadow: isUnlocked
                      ? [
                          BoxShadow(
                            color: const Color(0xFF58CC02).withValues(alpha: 0.3),
                            blurRadius: 12.0,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(40.0),
                    onTap: isUnlocked ? () => _onLevelTap(context, level) : null,
                    child: Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.star,
                            color: isUnlocked ? Colors.white : const Color(0xFF6B7280),
                            size: 32,
                          ),
                          if (isActive && levelIndex == 0)
                            Positioned(
                              bottom: -40,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4B5768),
                                  borderRadius: BorderRadius.circular(12.0),
                                ),
                                child: const Text(
                                  'START',
                                  style: TextStyle(
                                    color: Color(0xFF58CC02),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Add decorative elements
        if (levelIndex == 2) _buildDecorationCastle(),
        if (levelIndex == 3) _buildDecorationOwl(),
        if (levelIndex == 4) _buildDecorationHeadphones(),
        if (levelIndex == 5) _buildDecorationTrophy(),
        
        const SizedBox(height: 24.0),
      ],
    );
  }

  Widget _buildPathLine() {
    return Container(
      width: 4,
      height: 40,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF58CC02).withValues(alpha: 0.3),
            const Color(0xFF4B5768),
          ],
        ),
      ),
    );
  }

  Widget _buildDecorationCastle() {
    return Padding(
      padding: const EdgeInsets.only(left: 100.0, top: 20.0),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: const Color(0xFF4B5768),
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: const Icon(
          Icons.castle,
          color: Color(0xFF6B7280),
          size: 30,
        ),
      ),
    );
  }

  Widget _buildDecorationOwl() {
    return Padding(
      padding: const EdgeInsets.only(right: 80.0, top: 20.0),
      child: Container(
        width: 80,
        height: 80,
        decoration: const BoxDecoration(
          color: Color(0xFF4B5768),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.science,
          color: Color(0xFF6B7280),
          size: 35,
        ),
      ),
    );
  }

  Widget _buildDecorationHeadphones() {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0),
      child: Container(
        width: 60,
        height: 60,
        decoration: const BoxDecoration(
          color: Color(0xFF4B5768),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.headphones,
          color: Color(0xFF6B7280),
          size: 30,
        ),
      ),
    );
  }

  Widget _buildDecorationTrophy() {
    return Padding(
      padding: const EdgeInsets.only(left: 100.0, top: 20.0),
      child: Container(
        width: 60,
        height: 60,
        decoration: const BoxDecoration(
          color: Color(0xFF4B5768),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.emoji_events,
          color: Color(0xFF6B7280),
          size: 30,
        ),
      ),
    );
  }

  void _onLevelTap(BuildContext context, Level level) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LessonRunnerScreen(level: level, firebaseService: firebaseService),
      ),
    );
  }
}