import '../../app/config/data_mode.dart';
import '../../features/car/data/local_car_catalog_repository.dart';
import '../../features/car/data/local_car_payment_repository.dart';
import '../../features/car/data/local_car_report_repository.dart';
import '../../features/car/data/local_car_trip_repository.dart';
import '../../features/car/domain/repositories/car_catalog_repository.dart';
import '../../features/car/domain/repositories/car_payment_repository.dart';
import '../../features/car/domain/repositories/car_report_repository.dart';
import '../../features/car/domain/repositories/car_trip_repository.dart';
import '../../features/customers/data/local_customer_repository.dart';
import '../../features/customers/domain/customer_repository.dart';
import '../../features/products/data/local_product_repository.dart';
import '../../features/products/domain/product_repository.dart';

/// Central composition root for application services and repositories.
///
/// Runtime is currently offline-first. Repository interfaces are deliberately
/// stable so remote data sources can be introduced later without changing UI
/// or domain code.
class AppServices {
  AppServices._();

  static final AppServices instance = AppServices._();

  final DataModeController dataMode = DataModeController();

  final CustomerRepository customerRepository = LocalCustomerRepository();
  final ProductRepository productRepository = LocalProductRepository();

  final CarCatalogRepository carCatalogRepository =
      LocalCarCatalogRepository();
  final CarTripRepository carTripRepository = LocalCarTripRepository();
  final CarPaymentRepository carPaymentRepository =
      LocalCarPaymentRepository();
  final CarReportRepository carReportRepository = LocalCarReportRepository();

  bool _ready = false;

  bool get isReady => _ready;

  Future<void> init() async {
    if (_ready) return;
    await dataMode.load();
    _ready = true;
  }

  bool get offlineAllowed => dataMode.offlineAllowed;

  DataMode get mode => dataMode.mode;
}
