import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Primary action button with consistent height and press feedback.
class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expanded;
  final ButtonVariant variant;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expanded = true,
    this.variant = ButtonVariant.primary,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final content = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: variant == ButtonVariant.primary
                  ? colors.onPrimary
                  : colors.primary,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20),
                const SizedBox(width: 8),
              ],
              Text(label,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  )),
            ],
          );

    final button = switch (variant) {
      ButtonVariant.primary => FilledButton(
          onPressed: loading ? null : onPressed,
          child: content,
        ),
      ButtonVariant.secondary => OutlinedButton(
          onPressed: loading ? null : onPressed,
          child: content,
        ),
      ButtonVariant.ghost => TextButton(
          onPressed: loading ? null : onPressed,
          child: content,
        ),
      ButtonVariant.danger => FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: colors.error,
            foregroundColor: colors.onError,
          ),
          onPressed: loading ? null : onPressed,
          child: content,
        ),
    };

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

enum ButtonVariant { primary, secondary, ghost, danger }