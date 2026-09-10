import 'package:flutter/foundation.dart';

import '../domain/entities/returnable_invoice.dart';
import '../domain/entities/stock_transfer_request.dart';
import '../domain/entities/vehicle_stock_item.dart';
import '../domain/entities/warehouse_manager.dart';
import '../domain/repositories/representative_vehicle_repository.dart';

class RepresentativeVehicleController extends ChangeNotifier {
  final RepresentativeVehicleRepository repository;

  RepresentativeVehicleController({required this.repository});

  RepresentativeVehicle? _vehicle;
  List<VehicleStockItem> _vehicleStock = const [];
  List<StockTransferRequest> _transferRequests = const [];
  List<WarehouseOption> _warehouses = const [];
  List<WarehouseManager> _warehouseManagers = const [];
  List<VehicleStockItem> _selectedWarehouseStock = const [];

  bool _isLoading = false;
  bool _isSubmittingRequest = false;
  String? _errorMessage;
  int? _selectedWarehouseId;

  RepresentativeVehicle? get vehicle => _vehicle;
  List<VehicleStockItem> get vehicleStock => _vehicleStock;
  List<StockTransferRequest> get transferRequests => _transferRequests;
  List<WarehouseOption> get warehouses => _warehouses;
  List<WarehouseManager> get warehouseManagers => _warehouseManagers;
  List<VehicleStockItem> get selectedWarehouseStock => _selectedWarehouseStock;
  bool get isLoading => _isLoading;
  bool get isSubmittingRequest => _isSubmittingRequest;
  String? get errorMessage => _errorMessage;
  int? get selectedWarehouseId => _selectedWarehouseId;

  Future<void> load() async {
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
      _isLoading = false;
      notifyListeners();
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
    } catch (error) {
      _errorMessage = error.toString();
      return false;
    } finally {
      _isSubmittingRequest = false;
      notifyListeners();
    }
  }
}
