import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:linguaflow/services/user_progress_service.dart';

class StatusBar extends StatelessWidget {
  StatusBar({super.key});

  final UserProgressService _progress = UserProgressService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _progress.summaryDocStream(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data() ?? const {};
        final int hearts = (data['hearts'] ?? 5) as int;
        final int gems = (data['gems'] ?? 0) as int;
        final int xp = (data['total_xp'] ?? 0) as int;
        final int streak = (data['streak_count'] ?? 0) as int;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _pill(context, Icons.favorite, Colors.red, hearts.toString()),
            const SizedBox(width: 8),
            _pill(context, Icons.star, Colors.orange, xp.toString()),
            const SizedBox(width: 8),
            _pill(context, Icons.local_fire_department, Colors.deepOrange, streak.toString()),
            const SizedBox(width: 8),
            _pill(context, Icons.diamond, Colors.blue, gems.toString()),
          ],
        );
      },
    );
  }

  Widget _pill(BuildContext context, IconData icon, Color color, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(text, style: Theme.of(context).textTheme.labelLarge),
        ],
      ),
    );
  }
}
