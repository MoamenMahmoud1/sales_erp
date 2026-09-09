import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/ui/status_badge.dart';
import '../../domain/dashboard_snapshot.dart';

class RecentSaleTile extends StatelessWidget {
  final DashboardInvoiceSummary invoice;

  const RecentSaleTile({super.key, required this.invoice});

  StatusType _statusType(String? status) => switch (status) {
        'paid' => StatusType.success,
        'pending' => StatusType.warning,
        'overdue' => StatusType.error,
        _ => StatusType.neutral,
      };

  String _statusLabel(String? status) => switch (status) {
        'paid' => 'Paid',
        'pending' => 'Pending',
        'overdue' => 'Overdue',
        _ => 'Unknown',
      };

  String _money(double value) => 'EGP ${value.toStringAsFixed(2)}';

  String _dateLabel(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: AppRadius.smAll,
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: 19,
              color: colors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  invoice.customerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.title(context).copyWith(fontSize: 14),
                ),
                const SizedBox(height: 2),
                Text(
                  '#${invoice.id} · ${_dateLabel(invoice.createdAt)}',
                  style: AppTextStyles.caption(context).copyWith(
                    color: colors.textMuted,
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
                _money(invoice.total),
                style: AppTextStyles.numeric(context, size: 15, weight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              StatusBadge(
                type: _statusType(invoice.paymentStatus),
                label: _statusLabel(invoice.paymentStatus),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
