// Ported from ui/screens/HistoryScreen.kt
import 'package:flutter/material.dart';
import '../data/models.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan History')),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: MockRepository.sampleHistory.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          return _HistoryRow(item: MockRepository.sampleHistory[index]);
        },
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final ScanHistoryItem item;
  const _HistoryRow({required this.item});

  Color _severityColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (item.severity.toLowerCase()) {
      case 'high':
        return colorScheme.error;
      case 'moderate':
        return const Color(0xFFF9A825);
      case 'low':
        return const Color(0xFF558B2F);
      default:
        return const Color(0xFF2E7D32);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final severityColor = _severityColor(context);

    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: severityColor.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(Icons.eco, color: severityColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.disease, style: textTheme.titleMedium),
                  Text(item.date,
                      style: textTheme.bodyMedium?.copyWith(color: colorScheme.outline)),
                ],
              ),
            ),
            Text(
              '${item.confidence}%',
              style: textTheme.titleMedium?.copyWith(color: colorScheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
