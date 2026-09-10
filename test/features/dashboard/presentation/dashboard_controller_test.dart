import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sales_erp/features/dashboard/domain/dashboard_repository.dart';
import 'package:sales_erp/features/dashboard/domain/dashboard_snapshot.dart';
import 'package:sales_erp/features/dashboard/presentation/dashboard_controller.dart';

class _DeferredDashboardRepository implements DashboardRepository {
  final List<Completer<DashboardSnapshot>> requests = [];

  @override
  Future<DashboardSnapshot> loadSnapshot() {
    final request = Completer<DashboardSnapshot>();
    requests.add(request);
    return request.future;
  }
}

DashboardSnapshot _snapshot(double todayRevenue) => DashboardSnapshot(
      totalRevenue: todayRevenue,
      todayRevenue: todayRevenue,
      previousWeekRevenue: 0,
      outstandingAmount: 0,
      productCount: 0,
      customerCount: 0,
      invoiceCount: 0,
      overdueInvoiceCount: 0,
      weeklyRevenue: const [],
      recentInvoices: const [],
    );

void main() {
  test('ignores a stale load result when a newer load completes first', () async {
    final repository = _DeferredDashboardRepository();
    final controller = DashboardController(repository: repository);
    addTearDown(controller.dispose);

    final firstLoad = controller.load();
    final secondLoad = controller.load();

    repository.requests[1].complete(_snapshot(200));
    await secondLoad;

    repository.requests[0].complete(_snapshot(100));
    await firstLoad;

    expect(controller.status, DashboardStatus.ready);
    expect(controller.snapshot?.todayRevenue, 200);
  });

  test('ignores an in-flight load after the controller is disposed', () async {
    final repository = _DeferredDashboardRepository();
    final controller = DashboardController(repository: repository);

    final load = controller.load();
    controller.dispose();

    repository.requests.single.complete(_snapshot(100));
    await load;
  });
}
