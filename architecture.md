# LinguaFlow - Duolingo Clone Architecture

## Project Overview
LinguaFlow is a language learning mobile app inspired by Duolingo, built with Flutter and Firebase backend.

## Core Features (MVP)
1. **Language Selection** - Choose from/to languages for courses
2. **Course Structure** - Hierarchical learning path: Courses → Sections → Units → Levels → Lessons
3. **Interactive Challenges** - Various challenge types (multiple choice, translation, etc.)
4. **Progress Tracking** - XP system, lesson completion, streak tracking
5. **User Profile** - Statistics, achievements, settings

## Data Models (Based on Firebase Schema)

### Core Entities
- **Language**: code, name, native_name, flag_icon_url, rtl
- **Course**: from_language_id, to_language_id, title, description, difficulty_level
- **Section**: course_id, title, description, order_index, color_theme, unlock_criteria
- **Unit**: section_id, title, description, order_index
- **Level**: unit_id, title, order_index, unlock_criteria
- **Lesson**: level_id, title, description, order_index, estimated_time_minutes, xp_reward
- **Challenge**: lesson_id, type, interaction_pattern, hint, prompt_text, feedback_correct, feedback_incorrect
- **ChallengeOption**: challenge_id, content_text, display_order, is_correct

### User Progress Models (Local Storage)
- **UserProgress**: current_course_id, total_xp, streak_count, last_activity_date
- **LessonProgress**: lesson_id, completed_at, xp_earned, attempts_count
- **UserStats**: lessons_completed, total_time_studied, accuracy_rate

## App Structure

### Screen Hierarchy
1. **Splash/Onboarding** - Language selection, user setup
2. **Home/Dashboard** - Course overview, progress stats, daily goals
3. **Course Map** - Visual learning path with sections/units/levels
4. **Lesson View** - Challenge sequence with progress
5. **Challenge Screen** - Interactive exercise interface
6. **Profile** - Statistics, settings, achievements

### Core Components
- **LanguageSelector** - Flag-based language picker
- **CourseCard** - Course information display
- **ProgressPath** - Visual learning progression
- **ChallengeWidget** - Dynamic challenge renderer
- **XPDisplay** - Experience points and streaks
- **ProgressBar** - Lesson/course completion

## Technical Implementation

### State Management
- Provider pattern for app state
- Local storage for user progress
- Firebase for content data

### Navigation
- Bottom navigation for main sections
- Modal routes for challenges
- Custom transitions for lesson flow

### Data Flow
1. **Startup**: Load languages and user's current course
2. **Course Selection**: Filter courses by language pair
3. **Learning Path**: Build hierarchical structure from Firebase data
4. **Challenge Flow**: Fetch lesson challenges and options
5. **Progress Update**: Save completion status locally

### Firebase Collections Structure
```
languages/
courses/
sections/
units/
levels/
lessons/
challenges/
challengeoptions/
```

## File Structure
```
lib/
├── main.dart
├── theme.dart
├── models/
│   ├── language.dart
│   ├── course.dart
│   ├── lesson.dart
│   ├── challenge.dart
│   └── user_progress.dart
├── services/
│   ├── firebase_service.dart
│   └── local_storage_service.dart
├── screens/
│   ├── onboarding_screen.dart
│   ├── home_screen.dart
│   ├── course_screen.dart
│   ├── lesson_screen.dart
│   └── profile_screen.dart
├── widgets/
│   ├── language_selector.dart
│   ├── course_card.dart
│   ├── progress_path.dart
│   ├── challenge_widget.dart
│   └── xp_display.dart
└── utils/
    └── constants.dart
```

## Implementation Steps
1. Set up Firebase connection via Dreamflow UI
2. Create data models
3. Implement Firebase service layer
4. Build core screens and navigation
5. Implement challenge system
6. Add progress tracking
7. Polish UI and add sample data
8. Testing and compilation

## Sample Data Strategy
- Pre-populate with English ↔ Spanish course
- Include 2-3 sections with multiple lessons
- Various challenge types (translation, multiple choice, audio)
- Realistic XP rewards and time estimates