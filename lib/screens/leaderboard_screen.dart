import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:linguaflow/widgets/status_bar.dart';

class LeaderboardScreen extends StatelessWidget {
  const LeaderboardScreen({super.key});

  Stream<List<_Entry>> _entries() async* {
    // Try Firestore leaderboard; if missing, fall back to a static mock
    final col = FirebaseFirestore.instance.collection('leaderboards').doc('global').collection('weekly');
    yield* col.orderBy('xp', descending: true).snapshots().map((s) {
      if (s.docs.isEmpty) {
        return [
          _Entry('You', 1, 120),
          _Entry('Alex', 2, 95),
          _Entry('Sam', 3, 80),
          _Entry('Mia', 4, 70),
          _Entry('Kai', 5, 60),
        ];
      }
      int pos = 1;
      return s.docs.map((d) => _Entry(d['name'] ?? 'User', pos++, (d['xp'] ?? 0) as int)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Leagues'),
        actions: [Padding(padding: const EdgeInsets.only(right: 12), child: StatusBar())],
      ),
      body: StreamBuilder<List<_Entry>>(
        stream: _entries(),
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <_Entry>[];
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (_, i) {
              final e = items[i];
              return ListTile(
                leading: CircleAvatar(child: Text(e.position.toString())),
                title: Text(e.name),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: Colors.orange, size: 18),
                    const SizedBox(width: 6),
                    Text('${e.xp} XP'),
                  ],
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemCount: items.length,
          );
        },
      ),
    );
  }
}

class _Entry {
  final String name;
  final int position;
  final int xp;
  _Entry(this.name, this.position, this.xp);
}
