import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:linguaflow/services/quests_service.dart';
import 'package:linguaflow/services/user_progress_service.dart';
import 'package:linguaflow/widgets/status_bar.dart';

class QuestsScreen extends StatefulWidget {
  const QuestsScreen({super.key});

  @override
  State<QuestsScreen> createState() => _QuestsScreenState();
}

class _QuestsScreenState extends State<QuestsScreen> {
  final QuestsService _quests = QuestsService();
  final UserProgressService _progress = UserProgressService();
  bool _initDone = false;
  String? _msg;

  @override
  void initState() {
    super.initState();
    _ensure();
  }

  Future<void> _ensure() async {
    try {
      await _quests.ensureDailyQuests();
    } catch (_) {}
    if (mounted) setState(() => _initDone = true);
  }

  Future<void> _onClaim(String questId) async {
    setState(() => _msg = null);
    final xp = await _quests.completeQuest(questId);
    if (xp > 0) {
      await _progress.addXp(xp);
      if (mounted) setState(() => _msg = '+$xp XP claimed');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Quests'),
        actions: [Padding(padding: const EdgeInsets.only(right: 12), child: StatusBar())],
      ),
      body: !_initDone
          ? const Center(child: CircularProgressIndicator())
          : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _quests.todayQuestsStream(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_msg != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(_msg!, style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
                      ),
                    for (final d in docs) _questTile(context, d.id, d.data()),
                    if (docs.isEmpty) const Text('No quests for today.'),
                  ],
                );
              },
            ),
    );
  }

  Widget _questTile(BuildContext context, String id, Map<String, dynamic> data) {
    final title = (data['title'] ?? '') as String;
    final subtitle = (data['subtitle'] ?? '') as String;
    final xp = (data['xp'] ?? 0) as int;
    final completed = (data['completed'] ?? false) as bool;

    return Card(
      child: ListTile(
        leading: Icon(
          completed ? Icons.check_circle : Icons.flag,
          color: completed ? Colors.green : Colors.orange,
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: completed
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check, color: Colors.green, size: 18),
                    const SizedBox(width: 6),
                    Text('Done (+$xp XP)'),
                  ],
                ),
              )
            : ElevatedButton.icon(
                onPressed: () => _onClaim(id),
                icon: const Icon(Icons.star, color: Colors.white),
                label: Text('+$xp XP'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              ),
      ),
    );
  }
}
