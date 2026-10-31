// Ported from ui/screens/AboutScreen.kt
import 'package:flutter/material.dart';

class AboutScreen extends StatelessWidget {
  final VoidCallback onLogout;
  const AboutScreen({super.key, this.onLogout = _noop});

  static void _noop() {}

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('About e-krushi')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(Icons.spa, color: colorScheme.primary, size: 64),
            const SizedBox(height: 16),
            Text('e-krushi', style: textTheme.headlineMedium),
            const SizedBox(height: 4),
            Text(
              'AI-powered plant disease detection for farmers and hobbyist growers.',
              textAlign: TextAlign.center,
              style: textTheme.bodyLarge?.copyWith(color: colorScheme.outline),
            ),
            const SizedBox(height: 32),
            const _InfoRow(label: 'Model', value: 'MobileNetV2 (Transfer Learning)'),
            const _InfoRow(label: 'Backend', value: 'FastAPI (Python)'),
            const _InfoRow(label: 'Coverage', value: '38+ disease classes, 14 crops'),
            const _InfoRow(label: 'Version', value: '1.0.0 — Final Year Project'),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onLogout,
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Logout'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: colorScheme.outline)),
          Text(value, style: textTheme.bodyLarge),
        ],
      ),
    );
  }
}
