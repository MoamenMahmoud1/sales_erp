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

  if (!context.mounted) return null;
  if (specify != true) return DateTime.now().toUtc();

  return pickPaymentDateTime(context, initial: DateTime.now());
}

/// Opens date and time pickers using [initial] as the starting value.
Future<DateTime?> pickPaymentDateTime(
  BuildContext context, {
  DateTime? initial,
}) async {
  if (!context.mounted) return null;

  final seed = initial?.toLocal() ?? DateTime.now();
  final pickedDate = await showDatePicker(
    context: context,
    initialDate: seed,
    firstDate: DateTime(2000),
    lastDate: DateTime(DateTime.now().year + 5, 12, 31),
    helpText: 'Select payment date',
  );
  if (pickedDate == null || !context.mounted) return null;

  final pickedTime = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(seed),
    helpText: 'Select payment time',
  );
  if (pickedTime == null || !context.mounted) return null;

  return DateTime(
    pickedDate.year,
    pickedDate.month,
    pickedDate.day,
    pickedTime.hour,
    pickedTime.minute,
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
