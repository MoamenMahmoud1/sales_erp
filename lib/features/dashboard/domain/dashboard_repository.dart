import '../domain/dashboard_snapshot.dart';

abstract interface class DashboardRepository {
  Future<DashboardSnapshot> loadSnapshot();
}
