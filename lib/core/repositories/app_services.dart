import '../../app/config/data_mode.dart';
import '../../features/customers/data/local_customer_repository.dart';
import '../../features/customers/domain/customer_repository.dart';
import '../../features/products/data/local_product_repository.dart';
import '../../features/products/domain/product_repository.dart';

/// Central entry point for core services and repositories.
///
/// The current runtime is **100% local**: startup initializes only the local
/// data mode and database and never touches any network/client code. A future
/// API phase can be introduced behind the same repository interfaces.
class AppServices {
  AppServices._();

  static final AppServices instance = AppServices._();

  final DataModeController dataMode = DataModeController();

  bool _ready = false;

  bool get isReady => _ready;

  /// Initializes purely local services. Never touches the network layer, so
  /// the app boots without a backend, internet, or API credentials.
  Future<void> init() async {
    if (_ready) return;
    await dataMode.load();
    _ready = true;
  }

  /// Whether the current operational mode permits offline access without a
  /// server (true for `local` & `hybrid`, false only for `api`).
  bool get offlineAllowed => dataMode.offlineAllowed;

  DataMode get mode => dataMode.mode;

  /// In this local-only phase every mode resolves to the local SQLite-backed
  /// repository. The [DataMode.api] / [DataMode.hybrid] branches will be
  /// introduced in a future integration phase via the same interfaces.
  CustomerRepository get customerRepository => LocalCustomerRepository();

  ProductRepository get productRepository => LocalProductRepository();
}