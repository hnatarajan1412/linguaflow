import 'package:flutter/material.dart';
import 'package:linguaflow/services/user_progress_service.dart';
import 'package:linguaflow/widgets/status_bar.dart';

class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  final UserProgressService _progress = UserProgressService();
  bool _loading = false;
  String? _msg;

  Future<void> _buyHearts() async {
    setState(() { _loading = true; _msg = null; });
    try {
      final ok = await _progress.spendGems(50);
      if (ok) {
        await _progress.addHearts(5);
        setState(() { _msg = 'Purchased 5 hearts for 50 gems'; });
      } else {
        setState(() { _msg = 'Not enough gems'; });
      }
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Future<void> _buyStreakFreeze() async {
    setState(() { _loading = true; _msg = null; });
    try {
      final ok = await _progress.spendGems(100);
      setState(() { _msg = ok ? 'Streak Freeze activated' : 'Not enough gems'; });
    } finally {
      if (mounted) setState(() { _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop'),
        actions: [Padding(padding: const EdgeInsets.only(right: 12), child: StatusBar())],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_msg != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(_msg!, style: TextStyle(color: Theme.of(context).colorScheme.secondary)),
            ),
          _item(
            context,
            icon: Icons.favorite,
            color: Colors.red,
            title: 'Refill Hearts',
            subtitle: 'Buy 5 hearts to keep learning',
            price: 50,
            onTap: _loading ? null : _buyHearts,
          ),
          _item(
            context,
            icon: Icons.ac_unit,
            color: Colors.blue,
            title: 'Streak Freeze',
            subtitle: "Protect today's streak if you miss a day",
            price: 100,
            onTap: _loading ? null : _buyStreakFreeze,
          ),
        ],
      ),
    );
  }

  Widget _item(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required int price,
    VoidCallback? onTap,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(backgroundColor: color.withValues(alpha: 0.15), child: Icon(icon, color: color)),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: ElevatedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.diamond, color: Colors.white),
          label: Text(price.toString()),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
        ),
      ),
    );
  }
}
