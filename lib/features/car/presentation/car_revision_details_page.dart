import 'package:flutter/material.dart';

import '../../../core/ui/app_card.dart';
import '../domain/entities/car_revision.dart';
import '../domain/entities/car_trip.dart';
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
        payment: revision.payment,
      );

  String _money(int minor) => 'EGP ${(minor / 100).toStringAsFixed(2)}';

  String _date(DateTime value) {
    final local = value.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final trip = _tripSnapshot();
    final summary = _calculator.summary(trip);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: Text('${revision.displayNumber} · Revision ${revision.revisionNumber}')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
        children: [
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Historical snapshot', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text('${revision.salesCarName} · ${revision.warehouseName}', style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text(_date(revision.createdAt), style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
              if (revision.triggeredBy != null) ...[
                const SizedBox(height: 5),
                Text('Source: ${revision.triggeredBy}', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
              ],
            ]),
          ),
          const SizedBox(height: 12),
          _flowCard(summary, scheme),
          const SizedBox(height: 12),
          AppCard(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Frozen product snapshot', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 10),
              for (final line in summary.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(line.item.productName, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text('${line.item.loadedCartons} loaded · ${line.item.returnedCartons} returned · ${line.soldCartons} sold', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 3),
                    Text('${_money(line.item.unitPrice.minorUnits)} / carton · ${line.item.discountPercent.toStringAsFixed(2)}% discount', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 3),
                    Text('Gross ${_money(line.grossValue.minorUnits)} · Discount ${_money(line.discountAmount.minorUnits)} · Net ${_money(line.netValue.minorUnits)}', style: TextStyle(fontSize: 12, color: scheme.primary, fontWeight: FontWeight.w700)),
                  ]),
                ),
            ]),
          ),
          const SizedBox(height: 12),
          AppCard(
            child: Column(children: [
              _amount('Gross', summary.grossSubtotal),
              _amount('Product discounts', summary.productDiscountTotal),
              _amount('After product discounts', summary.subtotalAfterProducts),
              _amount('Global discount', summary.globalDiscountAmount),
              const Divider(height: 22),
              _amount('Actual sold value', summary.finalTotalSoldValue, strong: true),
              _amount('Paid', revision.payment.totalPaid),
              _amount('Remaining', _calculator.remaining(trip, summary), strong: true),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _flowCard(dynamic summary, ColorScheme scheme) => AppCard(
        child: Row(children: [
          _flow('Loaded', summary.totalLoadedCartons, Icons.outbox_rounded, scheme.primary),
          const Icon(Icons.arrow_forward_rounded, size: 18),
          _flow('Returned', summary.totalReturnedCartons, Icons.assignment_return_rounded, scheme.error),
          const Icon(Icons.arrow_forward_rounded, size: 18),
          _flow('Sold', summary.totalSoldCartons, Icons.point_of_sale_rounded, scheme.primary),
        ]),
      );

  Widget _flow(String label, int value, IconData icon, Color color) => Expanded(child: Column(children: [
        Icon(icon, color: color),
        const SizedBox(height: 4),
        Text('$value', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)),
        Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ]));

  Widget _amount(String label, dynamic amount, {bool strong = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(fontWeight: strong ? FontWeight.w800 : FontWeight.w500)),
          Text(_money(amount.minorUnits), style: TextStyle(fontWeight: strong ? FontWeight.w900 : FontWeight.w700, fontSize: strong ? 17 : 13)),
        ]),
      );
}
