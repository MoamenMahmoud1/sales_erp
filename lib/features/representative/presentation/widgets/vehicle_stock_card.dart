import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/ui/app_card.dart';
import '../../domain/entities/vehicle_stock_item.dart';

class VehicleStockCard extends StatelessWidget {
  final List<VehicleStockItem> items;
  final String title;
  final String emptyMessage;

  const VehicleStockCard({
    super.key,
    required this.items,
    this.title = 'Vehicle stock',
    this.emptyMessage = 'No goods are currently loaded in this vehicle.',
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: AppSpacing.md),
          if (items.isEmpty)
            Text(emptyMessage, style: TextStyle(color: colors.textSecondary, fontSize: 13))
          else
            for (var index = 0; index < items.length; index++) ...[
              _VehicleStockRow(item: items[index]),
              if (index != items.length - 1) const Divider(height: 20),
            ],
        ],
      ),
    );
  }
}

class _VehicleStockRow extends StatelessWidget {
  final VehicleStockItem item;

  const _VehicleStockRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
              const SizedBox(height: 2),
              Text('${item.sellingPrice} EGP', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
            ],
          ),
        ),
        Text(
          '${item.quantity}',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        const SizedBox(width: AppSpacing.xs),
        Text('pcs', style: TextStyle(color: colors.textMuted, fontSize: 12)),
      ],
    );
  }
}
