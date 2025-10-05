import 'package:flutter/material.dart';
import 'package:linguaflow/models/section.dart';
import 'package:linguaflow/models/unit.dart';
import 'package:linguaflow/models/level.dart';
import 'package:linguaflow/services/firebase_service.dart';
import 'package:linguaflow/widgets/journey_path.dart';
import 'package:linguaflow/scripts/firestore_seeder.dart';
import 'package:linguaflow/widgets/status_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  List<Section> _sections = [];
  Map<String, List<Unit>> _sectionUnits = {};
  Map<String, List<Level>> _unitLevels = {};
  bool _isLoading = true;
  String? _error;
  bool _isSeeding = false;

  @override
  void initState() {
    super.initState();
    _loadJourneyData();
  }

  Future<void> _loadJourneyData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final journeyData = await _firebaseService.getJourneyData();
      if (!mounted) return;
      setState(() {
        _sections = journeyData['sections'];
        _sectionUnits = journeyData['sectionUnits'];
        _unitLevels = journeyData['unitLevels'];
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to load journey data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _seedData() async {
    if (_isSeeding) return;
    setState(() {
      _isSeeding = true;
    });
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seeding Firestore data...')),
      );
      await FirestoreSeeder.runForTestUser(reset: true); // minimal deterministic seed for TESTUSER1
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seeding complete. Reloading journey...')),
      );
      await _loadJourneyData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Seeding failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSeeding = false;
        });
      }
    }
  }

  Widget _seedFab() {
    return FloatingActionButton.extended(
      heroTag: 'seed_fab',
      onPressed: _isSeeding ? null : _seedData,
      icon: _isSeeding
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.auto_fix_high),
      label: Text(_isSeeding ? 'Seeding…' : 'Seed Data'),
      backgroundColor: _isSeeding ? Colors.grey : Colors.blue,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('LinguaFlow'),
          actions: [Padding(padding: const EdgeInsets.only(right: 12), child: StatusBar())],
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading your journey...'),
            ],
          ),
        ),
        floatingActionButton: _seedFab(),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('LinguaFlow'),
          actions: [Padding(padding: const EdgeInsets.only(right: 12), child: StatusBar())],
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadJourneyData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        floatingActionButton: _seedFab(),
      );
    }

    if (_sections.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('LinguaFlow'),
          actions: [Padding(padding: const EdgeInsets.only(right: 12), child: StatusBar())],
        ),
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.school_outlined,
                size: 64,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(height: 16),
              Text(
                'No journey data available',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Add sections, units, and levels in Firebase to see your learning journey.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                children: [
                  ElevatedButton(
                    onPressed: _loadJourneyData,
                    child: const Text('Refresh'),
                  ),
                ],
              ),
            ],
          ),
        ),
        floatingActionButton: _seedFab(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('LinguaFlow'),
        actions: [Padding(padding: const EdgeInsets.only(right: 12), child: StatusBar())],
      ),
      backgroundColor: const Color(0xFF293647),
      body: SafeArea(
        child: JourneyPath(
          sections: _sections,
          sectionUnits: _sectionUnits,
          unitLevels: _unitLevels,
          firebaseService: _firebaseService,
        ),
      ),
      floatingActionButton: _seedFab(),
    );
  }
}
