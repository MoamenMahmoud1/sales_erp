import '../../app/config/data_mode.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/domain/repositories/authentication_repository.dart';
import '../../features/car/data/local_car_catalog_repository.dart';
import '../../features/car/data/local_car_payment_repository.dart';
import '../../features/car/data/local_car_report_repository.dart';
import '../../features/car/data/local_car_trip_command_repository.dart';
import '../../features/car/domain/repositories/car_catalog_repository.dart';
import '../../features/car/domain/repositories/car_payment_repository.dart';
import '../../features/car/domain/repositories/car_report_repository.dart';
import '../../features/car/domain/repositories/car_trip_command_repository.dart';
import '../../features/customers/data/local_customer_repository.dart';
import '../../features/customers/domain/customer_repository.dart';
import '../../features/dashboard/data/local_dashboard_repository.dart';
import '../../features/dashboard/domain/dashboard_repository.dart';
import '../../features/products/data/local_product_repository.dart';
import '../../features/products/domain/product_repository.dart';
import '../network/api_client.dart';
import 'car_trip_event_bus.dart';

class AppServices {
  AppServices._();

  static final AppServices instance = AppServices._();

  final DataModeController dataMode = DataModeController();
  final CarTripEventBus carTripEvents = CarTripEventBus();

  final CustomerRepository customerRepository = LocalCustomerRepository();
  final ProductRepository productRepository = LocalProductRepository();
  final DashboardRepository dashboardRepository = LocalDashboardRepository();

  final CarCatalogRepository carCatalogRepository = LocalCarCatalogRepository();
  final CarTripCommandRepository carTripRepository =
      LocalCarTripCommandRepository();
  final CarPaymentRepository carPaymentRepository = LocalCarPaymentRepository();
  final CarReportRepository carReportRepository = LocalCarReportRepository();

  late final ApiClient apiClient;
  late final AuthenticationRepository authRepository;

  bool _ready = false;

  bool get isReady => _ready;

  Future<void> init() async {
    if (_ready) return;

    await dataMode.load();
    apiClient = await ApiClient.create();
    authRepository = AuthRepository(apiClient);
    _ready = true;
  }

  bool get offlineAllowed => dataMode.offlineAllowed;
  DataMode get mode => dataMode.mode;
}
