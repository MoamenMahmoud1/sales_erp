import '../../app/config/data_mode.dart';
import '../../features/approvals/data/dio_approval_repository.dart';
import '../../features/approvals/domain/repositories/approval_repository.dart';
import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/domain/repositories/authentication_repository.dart';
import '../../features/customers/data/local_customer_repository.dart';
import '../../features/customers/domain/customer_repository.dart';
import '../../features/dashboard/data/local_dashboard_repository.dart';
import '../../features/dashboard/domain/dashboard_repository.dart';
import '../../features/notifications/data/dio_notification_repository.dart';
import '../../features/notifications/domain/repositories/notification_repository.dart';
import '../../features/products/data/local_product_repository.dart';
import '../../features/products/domain/product_repository.dart';
import '../../features/representative/data/dio_representative_sale_repository.dart';
import '../../features/representative/data/dio_representative_vehicle_repository.dart';
import '../../features/representative/domain/repositories/representative_sale_repository.dart';
import '../../features/representative/domain/repositories/representative_vehicle_repository.dart';
import '../network/api_client.dart';

class AppServices {
  AppServices._();

  static final AppServices instance = AppServices._();

  final DataModeController dataMode = DataModeController();

  final CustomerRepository customerRepository = LocalCustomerRepository();
  final ProductRepository productRepository = LocalProductRepository();
  final DashboardRepository dashboardRepository = LocalDashboardRepository();

  late final ApiClient apiClient;
  late final AuthenticationRepository authRepository;
  late final RepresentativeVehicleRepository representativeVehicleRepository;
  late final RepresentativeSaleRepository representativeSaleRepository;
  late final NotificationRepository notificationRepository;
  late final ApprovalRepository approvalRepository;

  bool _ready = false;

  bool get isReady => _ready;

  Future<void> init() async {
    if (_ready) return;

    await dataMode.load();
    apiClient = await ApiClient.create();
    authRepository = AuthRepository(apiClient);
    representativeVehicleRepository = DioRepresentativeVehicleRepository(apiClient);
    representativeSaleRepository = DioRepresentativeSaleRepository(apiClient);
    notificationRepository = DioNotificationRepository(apiClient);
    approvalRepository = DioApprovalRepository(apiClient);
    _ready = true;
  }

  bool get offlineAllowed => dataMode.offlineAllowed;
  DataMode get mode => dataMode.mode;
}
