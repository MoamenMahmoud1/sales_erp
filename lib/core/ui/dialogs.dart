import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import 'app_button.dart';

/// Modern confirm dialog using the app's dialog theme.
Future<bool> showConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) {
      final colors = AppColors.of(context);
      return AlertDialog(
        title: Row(
          children: [
            if (destructive)
              Icon(Icons.warning_amber_rounded, color: colors.warning)
            else
              Icon(Icons.help_outline, color: colors.primary),
            const SizedBox(width: AppSpacing.md),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(cancelLabel),
          ),
          AppButton(
            label: confirmLabel,
            onPressed: () => Navigator.of(context).pop(true),
            expanded: false,
            variant: destructive ? ButtonVariant.danger : ButtonVariant.primary,
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// Shows a modal bottom sheet with the app's sheet theme (rounded top, drag handle).
Future<T?> showAppBottomSheet<T>(
  BuildContext context,
  Widget child, {
  bool isScrollControlled = true,
  double? maxHeight,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    useSafeArea: true,
    constraints: BoxConstraints(
      maxHeight: maxHeight ??
          (isScrollControlled
              ? MediaQuery.of(context).size.height * 0.85
              : double.infinity),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom > 0
            ? MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg
            : AppSpacing.lg,
      ),
      child: child,
    ),
  );
}