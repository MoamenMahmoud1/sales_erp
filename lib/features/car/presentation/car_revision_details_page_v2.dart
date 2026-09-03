import 'package:flutter/material.dart';

import '../../../core/ui/app_card.dart';
import '../domain/entities/car_revision.dart';
import '../domain/entities/car_trip.dart';
import '../domain/entities/money.dart';
import '../domain/services/car_calculator.dart';

class CarRevisionDetailsPage extends StatelessWidget {
  final CarRevision revision;
  final _calculator = const CarCalculator();

  const CarRevisionDetailsPage({super.key, required this.revision});

  CarTrip _tripSnapshot() => CarTrip(
        id: revision.tripId,
        displayNumber: revision.displayNumber,
        salesCarId: revision.salesCarId,
        salesCarName: revision.salesCarName,
        warehouseId: revision.warehouseId,
        warehouseName: revision.warehouseName,
        openedAt: revision.openedAt,
        closedAt: revision.closedAt,
        dueDate: revision.dueDate,
        status: revision.status,
        items: revision.items,
        globalDiscountPercent: revision.globalDiscountPercent,
        globalDiscountEgp: revision.globalDiscountEgp,
        payment: revision.payment,
      );

  String _money(CarMoney value) => 'EGP ${value.units.toStringAsFixed(2)}';

  String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final summary = _calculator.summary(_tripSnapshot());

    return Scaffold(
      appBar: AppBar(title: Text('${revision.displayNumber} · Revision ${revision.revisionNumber}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Historical snapshot', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text('${revision.salesCarName} · ${revision.warehouseName}'),
                const SizedBox(height: 3),
                Text(_date(revision.createdAt), style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Products', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                const SizedBox(height: 7),
                for (final line in summary.items) ...[
                  Row(
                    children: [
                      Expanded(child: Text(line.item.productName, style: const TextStyle(fontWeight: FontWeight.w800))),
                      Text('${line.soldCartons} sold', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Sell ${_money(line.item.sellingPrice)} · Buy ${_money(line.item.purchasePrice)} · Discount ${_money(line.discountAmount)} · Cost ${_money(line.purchaseCost)} · Profit ${_money(line.profitBeforeGlobalDiscount)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(
              children: [
                _amount('Selling total', summary.finalTotalSoldValue),
                _amount('Buying cost', summary.totalPurchaseCost),
                _amount('Product discount', summary.productDiscountTotal),
                _amount('Global % discount', summary.globalDiscountPercentAmount),
                _amount('Global EGP discount', summary.globalDiscountFixedAmount),
                const Divider(height: 18),
                _amount('Profit', summary.profit, strong: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _amount(String label, CarMoney amount, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(label, softWrap: true)),
            const SizedBox(width: 12),
            Text(_money(amount), style: TextStyle(fontWeight: strong ? FontWeight.w900 : FontWeight.w700)),
          ],
        ),
      );
}
