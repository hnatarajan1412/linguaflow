import 'package:flutter/material.dart';
import 'package:linguaflow/services/auth_service.dart';
import 'package:linguaflow/services/user_progress_service.dart';
import 'package:linguaflow/widgets/status_bar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<Map<String, dynamic>> _summary() async => UserProgressService().getSummary();

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [Padding(padding: const EdgeInsets.only(right: 12), child: StatusBar())],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _summary(),
        builder: (context, snapshot) {
          final s = snapshot.data ?? const {};
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(s['display_name'] ?? 'Learner'),
                subtitle: Text((s['from_language_id'] ?? 'en') + ' → ' + (s['to_language_id'] ?? 'es')),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Daily goal'),
                subtitle: Text('${(s['daily_goal_xp'] ?? 20) as int} XP/day'),
              ),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Sign out'),
                onTap: () async {
                  try { await auth.signOut(); } catch (_) {}
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Signed out')));
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
