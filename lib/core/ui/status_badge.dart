import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// Semantic status types that map to consistent colors + icons. Status is
/// always communicated beyond color via the label and optional icon.
enum StatusType {
  success,
  info,
  warning,
  error,
  neutral,
}

/// Chip-like status badge used for payment/invoice/stock states.
class StatusBadge extends StatelessWidget {
  final StatusType type;
  final String label;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.type,
    required this.label,
    this.icon,
  });

  Color _foreground(AppColors c) => switch (type) {
        StatusType.success => c.success,
        StatusType.info => c.info,
        StatusType.warning => c.warning,
        StatusType.error => c.error,
        StatusType.neutral => c.textSecondary,
      };

  Color _background(AppColors c) => switch (type) {
        StatusType.success => c.successContainer,
        StatusType.info => c.infoContainer,
        StatusType.warning => c.warningContainer,
        StatusType.error => c.errorContainer,
        StatusType.neutral => c.surfaceMuted,
      };

  Color _onBackground(AppColors c) => switch (type) {
        StatusType.success => c.onSuccessContainer,
        StatusType.info => c.onInfoContainer,
        StatusType.warning => c.onWarningContainer,
        StatusType.error => c.onErrorContainer,
        StatusType.neutral => c.textSecondary,
      };

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: _background(colors),
        borderRadius: AppRadius.xlAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: _foreground(colors)),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: _onBackground(colors),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}