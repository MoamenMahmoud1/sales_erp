import '../../domain/entities/car_totals.dart';
import '../../domain/entities/car_trip_summary_view.dart';
import '../../domain/repositories/car_report_repository.dart';
import '../../domain/repositories/car_trip_repository.dart';

class CarDashboardData {
  final CarTotals totals;
  final List<CarTripSummaryView> recentTrips;

  const CarDashboardData({
    required this.totals,
    required this.recentTrips,
  });
}

class LoadCarDashboard {
  final CarReportRepository reportRepository;
  final CarTripRepository tripRepository;

  const LoadCarDashboard({
    required this.reportRepository,
    required this.tripRepository,
  });

  Future<CarDashboardData> call() async {
    final results = await Future.wait([
      reportRepository.getTotals(),
      tripRepository.getTripSummaries(),
    ]);
    final totals = results[0] as CarTotals;
    final trips = results[1] as List<CarTripSummaryView>;
    return CarDashboardData(
      totals: totals,
      recentTrips: trips.take(6).toList(growable: false),
    );
  }
}
