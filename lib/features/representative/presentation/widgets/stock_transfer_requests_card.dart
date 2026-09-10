import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/ui/app_card.dart';
import '../../../../core/ui/status_badge.dart';
import '../../domain/entities/stock_transfer_request.dart';

class StockTransferRequestsCard extends StatelessWidget {
  final List<StockTransferRequest> requests;

  const StockTransferRequestsCard({
    super.key,
    required this.requests,
  });

  StatusType _statusType(StockTransferRequestStatus status) {
    switch (status) {
      case StockTransferRequestStatus.approved:
        return StatusType.success;
      case StockTransferRequestStatus.rejected:
        return StatusType.error;
      case StockTransferRequestStatus.cancelled:
        return StatusType.neutral;
      case StockTransferRequestStatus.pending:
        return StatusType.warning;
    }
  }

  String _statusLabel(StockTransferRequestStatus status) {
    switch (status) {
      case StockTransferRequestStatus.approved:
        return 'Approved';
      case StockTransferRequestStatus.rejected:
        return 'Rejected';
      case StockTransferRequestStatus.cancelled:
        return 'Cancelled';
      case StockTransferRequestStatus.pending:
        return 'Pending approval';
    }
  }

  String _requestTitle(StockTransferRequest request) {
    return request.isInboundRequest ? 'Loading request' : 'Return request';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Stock requests', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: AppSpacing.md),
          if (requests.isEmpty)
            Text('No stock requests yet.', style: TextStyle(color: colors.textSecondary, fontSize: 13))
          else
            for (var index = 0; index < requests.length; index++) ...[
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  '#${requests[index].id} · ${_requestTitle(requests[index])}',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                subtitle: Text(
                  '${requests[index].warehouseName} · ${requests[index].warehouseManagerName}\n${requests[index].items.length} item(s)',
                  style: const TextStyle(fontSize: 12),
                ),
                isThreeLine: true,
                trailing: StatusBadge(
                  type: _statusType(requests[index].status),
                  label: _statusLabel(requests[index].status),
                  icon: requests[index].status == StockTransferRequestStatus.pending
                      ? Icons.hourglass_top_rounded
                      : null,
                ),
              ),
              if (requests[index].rejectionReason.isNotEmpty) ...[
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    'Reason: ${requests[index].rejectionReason}',
                    style: TextStyle(color: colors.error, fontSize: 12),
                  ),
                ),
              ],
              if (index != requests.length - 1) const Divider(height: 20),
            ],
        ],
      ),
    );
  }
}
