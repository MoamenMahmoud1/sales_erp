import 'package:flutter/material.dart';

/// Prompts the user to either use the current time or specify the payment
/// date and time manually.
Future<DateTime?> resolvePaymentTime(BuildContext context) async {
  final specify = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Specify payment time?'),
      content: const Text(
        'Would you like to specify the payment date and time, or continue with the current time?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Continue'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Specify details'),
        ),
      ],
    ),
  );

  if (specify != true) return DateTime.now().toUtc();

  final now = DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: now,
    firstDate: DateTime(2000),
    lastDate: DateTime(now.year + 5, now.month, now.day),
    helpText: 'Select payment date',
  );
  if (date == null || !context.mounted) return null;

  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(now),
    helpText: 'Select payment time',
  );
  if (time == null || !context.mounted) return null;

  return DateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  ).toUtc();
}

String formatPaymentDateTime(DateTime value) {
  final local = value.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month/${local.year} $hour:$minute';
}
