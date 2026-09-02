import 'package:flutter/material.dart';

class CarMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? accent;

  const CarMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tone = accent ?? colors.primary;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .55)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: tone.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: tone, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12)),
                const SizedBox(height: 3),
                Text(value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
