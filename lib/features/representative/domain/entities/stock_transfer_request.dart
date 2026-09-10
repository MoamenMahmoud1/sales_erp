enum StockTransferRequestType {
  warehouseToVehicle,
  vehicleToWarehouse,
}

enum StockTransferRequestStatus {
  pending,
  approved,
  rejected,
  cancelled,
}

class StockTransferRequestItem {
  final int productId;
  final String productName;
  final int quantity;
  final int? invoiceItemId;

  const StockTransferRequestItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    this.invoiceItemId,
  });
}

class StockTransferRequest {
  final int id;
  final StockTransferRequestType type;
  final StockTransferRequestStatus status;
  final int warehouseId;
  final String warehouseName;
  final int warehouseManagerId;
  final String warehouseManagerName;
  final List<StockTransferRequestItem> items;
  final String reference;
  final String rejectionReason;
  final DateTime createdAt;
  final DateTime? reviewedAt;

  const StockTransferRequest({
    required this.id,
    required this.type,
    required this.status,
    required this.warehouseId,
    required this.warehouseName,
    required this.warehouseManagerId,
    required this.warehouseManagerName,
    required this.items,
    required this.reference,
    required this.rejectionReason,
    required this.createdAt,
    required this.reviewedAt,
  });

  bool get isInboundRequest => type == StockTransferRequestType.warehouseToVehicle;
}
