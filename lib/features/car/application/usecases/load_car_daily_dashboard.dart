import '../../domain/entities/car_totals.dart';
import '../../domain/entities/car_trip_filter.dart';
import '../../domain/entities/car_trip_summary_view.dart';
import '../../domain/repositories/car_report_repository.dart';
import '../../domain/repositories/car_trip_repository.dart';

class CarDailyDashboardData {
  final DateTime day;
  final CarTotals totals;
  final List<CarTripSummaryView> trips;

  const CarDailyDashboardData({
    required this.day,
    required this.totals,
    required this.trips,
  });
}

/// Loads only the local calendar day requested by the UI.
class LoadCarDailyDashboard {
  final CarReportRepository reportRepository;
  final CarTripRepository tripRepository;

  const LoadCarDailyDashboard({
    required this.reportRepository,
    required this.tripRepository,
  });

  Future<CarDailyDashboardData> call(DateTime day) async {
    final localDay = DateTime(day.year, day.month, day.day);
    final results = await Future.wait<dynamic>([
      reportRepository.getTotals(from: localDay, to: localDay),
      tripRepository.getTripSummaries(
        filter: CarTripFilter(from: localDay, to: localDay),
      ),
    ]);

    return CarDailyDashboardData(
      day: localDay,
      totals: results[0] as CarTotals,
      trips: (results[1] as List<CarTripSummaryView>),
    );
  }
}
