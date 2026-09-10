import '../entities/stock_transfer_request.dart';
import '../entities/vehicle_stock_item.dart';
import '../entities/warehouse_manager.dart';

class RepresentativeVehicle {
  final int shiftId;
  final int vehicleId;
  final String vehicleName;
  final String businessDate;

  const RepresentativeVehicle({
    required this.shiftId,
    required this.vehicleId,
    required this.vehicleName,
    required this.businessDate,
  });
}

abstract interface class RepresentativeVehicleRepository {
  Future<RepresentativeVehicle?> fetchCurrentVehicle();

  Future<List<VehicleStockItem>> fetchVehicleStock({required int vehicleId});

  Future<List<WarehouseOption>> fetchWarehouses();

  Future<List<WarehouseManager>> fetchWarehouseManagers({required int warehouseId});

  Future<List<StockTransferRequest>> fetchStockTransferRequests();

  Future<StockTransferRequest> createLoadingRequest({
    required int warehouseId,
    required int warehouseManagerId,
    required List<StockTransferRequestItem> items,
    String reference = '',
  });

  Future<StockTransferRequest> createReturnRequest({
    required int warehouseId,
    required int warehouseManagerId,
    required int invoiceId,
    required List<StockTransferRequestItem> items,
    String reference = '',
  });
}

class WarehouseOption {
  final int id;
  final String name;

  const WarehouseOption({
    required this.id,
    required this.name,
  });
}
