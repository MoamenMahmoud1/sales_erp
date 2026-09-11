import '../../../core/sync/sync_outbox.dart';
import '../entities/returnable_invoice.dart';
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

class VehicleMutationSubmission {
  final bool queued;
  final String operationKey;
  final Map<String, dynamic>? response;

  const VehicleMutationSubmission({
    required this.queued,
    required this.operationKey,
    required this.response,
  });
}

abstract interface class RepresentativeVehicleRepository {
  Future<RepresentativeVehicle?> fetchCurrentVehicle();

  Future<List<VehicleStockItem>> fetchVehicleStock({required int vehicleId});

  Future<List<WarehouseOption>> fetchWarehouses();

  Future<List<WarehouseManager>> fetchWarehouseManagers({required int warehouseId});

  Future<List<StockTransferRequest>> fetchStockTransferRequests();

  Future<ReturnableInvoice?> fetchReturnableInvoice({required int invoiceId});

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

  Future<VehicleMutationSubmission> requestVehicleUpdate({
    required int vehicleId,
    required String name,
    String reason = '',
  });

  Future<VehicleMutationSubmission> requestVehicleDelete({
    required int vehicleId,
    String reason = '',
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
