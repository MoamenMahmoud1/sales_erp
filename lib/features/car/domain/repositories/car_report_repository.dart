import '../entities/car_totals.dart';

abstract interface class CarReportRepository {
  Future<CarTotals> getTotals({DateTime? from, DateTime? to});
}
