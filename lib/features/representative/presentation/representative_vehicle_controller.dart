import 'package:flutter/foundation.dart';

import '../../../core/sync/sync_outbox.dart';
import '../../../core/sync/sync_outbox_events.dart';
import '../domain/entities/returnable_invoice.dart';
import '../domain/entities/stock_transfer_request.dart';
import '../domain/entities/vehicle_stock_item.dart';
import '../domain/entities/warehouse_manager.dart';
import '../domain/repositories/representative_vehicle_repository.dart';

class RepresentativeVehicleController extends ChangeNotifier {
  final RepresentativeVehicleRepository repository;

  RepresentativeVehicleController({required this.repository}) {
    _lastHandledSyncKey = SyncOutboxEventBus.instance.lastSuccess?.operationKey;
    SyncOutboxEventBus.instance.addListener(_onSyncCompleted);
  }

  RepresentativeVehicle? _vehicle;
  List<VehicleStockItem> _vehicleStock = const [];
  List<StockTransferRequest> _transferRequests = const [];
  List<WarehouseOption> _warehouses = const [];
  List<WarehouseManager> _warehouseManagers = const [];
  List<VehicleStockItem> _selectedWarehouseStock = const [];

  bool _isLoading = false;
  bool _isSubmittingRequest = false;
  bool _isSubmittingVehicleMutation = false;
  bool _lastRequestQueued = false;
  bool _lastVehicleMutationQueued = false;
  String? _errorMessage;
  int? _selectedWarehouseId;
  String? _lastHandledSyncKey;
  bool _disposed = false;

  RepresentativeVehicle? get vehicle => _vehicle;
  List<VehicleStockItem> get vehicleStock => _vehicleStock;
  List<StockTransferRequest> get transferRequests => _transferRequests;
  List<WarehouseOption> get warehouses => _warehouses;
  List<WarehouseManager> get warehouseManagers => _warehouseManagers;
  List<VehicleStockItem> get selectedWarehouseStock => _selectedWarehouseStock;
  bool get isLoading => _isLoading;
  bool get isSubmittingRequest => _isSubmittingRequest;
  bool get isSubmittingVehicleMutation => _isSubmittingVehicleMutation;
  bool get lastRequestQueued => _lastRequestQueued;
  bool get lastVehicleMutationQueued => _lastVehicleMutationQueued;
  String? get errorMessage => _errorMessage;
  int? get selectedWarehouseId => _selectedWarehouseId;

  void _onSyncCompleted() {
    if (_disposed) return;
    final event = SyncOutboxEventBus.instance.lastSuccess;
    if (event == null || event.operationKey == _lastHandledSyncKey) return;

    _lastHandledSyncKey = event.operationKey;
    if (_isVehicleRelevantPath(event.path)) {
      load();
    }
  }

  bool _isVehicleRelevantPath(String path) {
    return path.startsWith('/invoices/representative-sale/') ||
        path.startsWith('/inventory/transfer-requests/') ||
        path.startsWith('/approvals/');
  }

  Future<void> load() async {
    if (_disposed) return;
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _vehicle = await repository.fetchCurrentVehicle();
      _vehicleStock = _vehicle == null
          ? const []
          : await repository.fetchVehicleStock(vehicleId: _vehicle!.vehicleId);
      _transferRequests = await repository.fetchStockTransferRequests();
      _warehouses = await repository.fetchWarehouses();
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      if (!_disposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> selectWarehouse(int warehouseId) async {
    _selectedWarehouseId = warehouseId;
    _warehouseManagers = const [];
    _selectedWarehouseStock = const [];
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        repository.fetchWarehouseManagers(warehouseId: warehouseId),
        repository.fetchVehicleStock(vehicleId: warehouseId),
      ]);
      _warehouseManagers = results[0] as List<WarehouseManager>;
      _selectedWarehouseStock = results[1] as List<VehicleStockItem>;
    } catch (error) {
      _errorMessage = error.toString();
      notifyListeners();
    }
  }

  Future<ReturnableInvoice?> fetchReturnableInvoice({required int invoiceId}) {
    return repository.fetchReturnableInvoice(invoiceId: invoiceId);
  }

  Future<bool> createLoadingRequest({
    required int warehouseId,
    required int warehouseManagerId,
    required List<StockTransferRequestItem> items,
    String reference = '',
  }) async {
    _isSubmittingRequest = true;
    _lastRequestQueued = false;
    _errorMessage = null;
    notifyListeners();

    try {
      final request = await repository.createLoadingRequest(
        warehouseId: warehouseId,
        warehouseManagerId: warehouseManagerId,
        items: items,
        reference: reference,
      );
      _transferRequests = [request, ..._transferRequests];
      return true;
    } on QueuedOperationException {
      _lastRequestQueued = true;
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _isSubmittingRequest = false;
      notifyListeners();
    }
  }

  Future<bool> createReturnRequest({
    required int warehouseId,
    required int warehouseManagerId,
    required int invoiceId,
    required List<StockTransferRequestItem> items,
    String reference = '',
  }) async {
    _isSubmittingRequest = true;
    _lastRequestQueued = false;
    _errorMessage = null;
    notifyListeners();

    try {
      final request = await repository.createReturnRequest(
        warehouseId: warehouseId,
        warehouseManagerId: warehouseManagerId,
        invoiceId: invoiceId,
        items: items,
        reference: reference,
      );
      _transferRequests = [request, ..._transferRequests];
      return true;
    } on QueuedOperationException {
      _lastRequestQueued = true;
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _isSubmittingRequest = false;
      notifyListeners();
    }
  }

  Future<bool> requestVehicleUpdate({required String name, String reason = ''}) async {
    final vehicle = _vehicle;
    if (vehicle == null) return false;

    _isSubmittingVehicleMutation = true;
    _lastVehicleMutationQueued = false;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await repository.requestVehicleUpdate(
        vehicleId: vehicle.vehicleId,
        name: name,
        reason: reason,
      );
      _lastVehicleMutationQueued = result.queued;
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _isSubmittingVehicleMutation = false;
      notifyListeners();
    }
  }

  Future<bool> requestVehicleDelete({String reason = ''}) async {
    final vehicle = _vehicle;
    if (vehicle == null) return false;

    _isSubmittingVehicleMutation = true;
    _lastVehicleMutationQueued = false;
    _errorMessage = null;
    notifyListeners();
    try {
      final result = await repository.requestVehicleDelete(
        vehicleId: vehicle.vehicleId,
        reason: reason,
      );
      _lastVehicleMutationQueued = result.queued;
      return true;
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _isSubmittingVehicleMutation = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    SyncOutboxEventBus.instance.removeListener(_onSyncCompleted);
    super.dispose();
  }
}
