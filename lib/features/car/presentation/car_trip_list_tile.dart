import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/status_badge.dart';
import '../domain/entities/car_payment_status.dart';
import '../domain/entities/car_trip.dart';
import '../domain/entities/car_trip_status.dart';
import '../domain/entities/car_trip_summary_view.dart';
import '../domain/services/car_payment_evaluator.dart';

class CarTripListTile extends StatelessWidget {
  final CarTripSummaryView trip;
  final CarPaymentEvaluator paymentEvaluator;
  final bool deleting;
  final bool confirming;
  final VoidCallback? onTap;
  final VoidCallback? onConfirm;
  final VoidCallback? onDelete;

  const CarTripListTile({
    super.key,
    required this.trip,
    required this.paymentEvaluator,
    this.deleting = false,
    this.confirming = false,
    this.onTap,
    this.onConfirm,
    this.onDelete,
  });

  String _money(int minorUnits) =>
      'EGP ${(minorUnits / 100).toStringAsFixed(2)}';

  String _dayLabel(DateTime value) {
    final local = value.toLocal();
    final formatted =
        '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
    return formatted;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDraft = trip.status == CarTripStatus.open;
    final paymentStatus = trip.paymentStatus(paymentEvaluator, DateTime.now());
    final paymentBadge = switch (paymentStatus) {
      CarPaymentStatus.paid => (StatusType.success, 'Paid'),
      CarPaymentStatus.partiallyPaid => (StatusType.warning, 'Partial'),
      CarPaymentStatus.unpaid => (StatusType.neutral, 'Unpaid'),
      CarPaymentStatus.overdue => (StatusType.error, 'Overdue'),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        onTap: deleting || confirming ? null : onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: colors.primaryContainer,
                borderRadius: AppRadius.mdAll,
              ),
              child: Icon(
                Icons.local_shipping_rounded,
                color: colors.primary,
                size: 21,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _dayLabel(trip.openedAt),
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${trip.salesCarName} · ${trip.warehouseName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${trip.totalLoadedCartons} loaded · ${trip.totalReturnedCartons} returned · ${trip.totalSoldCartons} sold',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _money(trip.finalValue.minorUnits),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                StatusBadge(
                  type: isDraft ? StatusType.warning : paymentBadge.$1,
                  label: isDraft ? 'Draft' : paymentBadge.$2,
                ),
                if (isDraft) ...[
                  const SizedBox(height: 2),
                  TextButton.icon(
                    onPressed: confirming || deleting ? null : onConfirm,
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 7),
                    ),
                    icon: confirming
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 17,
                          ),
                    label: Text(confirming ? 'Confirming' : 'Confirm'),
                  ),
                ],
                IconButton(
                  tooltip: 'Delete trip',
                  visualDensity: VisualDensity.compact,
                  onPressed: deleting || confirming ? null : onDelete,
                  icon: deleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
