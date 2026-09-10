import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/entities/stock_transfer_request.dart';
import '../domain/entities/vehicle_stock_item.dart';
import '../domain/entities/warehouse_manager.dart';
import '../domain/repositories/representative_vehicle_repository.dart';

class DioRepresentativeVehicleRepository implements RepresentativeVehicleRepository {
  final ApiClient client;

  const DioRepresentativeVehicleRepository(this.client);

  @override
  Future<RepresentativeVehicle?> fetchCurrentVehicle() async {
    final response = await client.dio.get('/accounts/shifts/current/');
    if (response.data == null) return null;

    final data = Map<String, dynamic>.from(response.data as Map);
    final vehicleId = _readNullableInt(data['vehicle']);
    if (vehicleId == null) return null;

    return RepresentativeVehicle(
      shiftId: _readInt(data['id']),
      vehicleId: vehicleId,
      vehicleName: _readString(data['vehicle_name']),
      businessDate: _readString(data['business_date']),
    );
  }

  @override
  Future<List<VehicleStockItem>> fetchVehicleStock({required int vehicleId}) async {
    final response = await client.dio.get(
      '/inventory/stock/',
      queryParameters: {'location': vehicleId},
    );
    final rows = _readResults(response.data);

    return [
      for (final row in rows)
        VehicleStockItem(
          productId: _readInt(row['product']),
          productName: _readString(row['product_name']),
          quantity: _readInt(row['quantity']),
          sellingPrice: _readString(row['selling_price']),
        ),
    ];
  }

  @override
  Future<List<WarehouseOption>> fetchWarehouses() async {
    final response = await client.dio.get('/inventory/locations/');
    final rows = _readResults(response.data);

    return [
      for (final row in rows)
        if (_readString(row['location_type']) == 'MAIN_WAREHOUSE')
          WarehouseOption(
            id: _readInt(row['id']),
            name: _readString(row['name']),
          ),
    ];
  }

  @override
  Future<List<WarehouseManager>> fetchWarehouseManagers({required int warehouseId}) async {
    final response = await client.dio.get(
      '/inventory/warehouse-managers/',
      queryParameters: {'warehouse': warehouseId},
    );
    final rows = _readList(response.data);

    return [
      for (final row in rows)
        WarehouseManager(
          id: _readInt(row['id']),
          name: _readString(row['name']),
          username: _readString(row['username']),
        ),
    ];
  }

  @override
  Future<List<StockTransferRequest>> fetchStockTransferRequests() async {
    final response = await client.dio.get('/inventory/transfer-requests/');
    final rows = _readResults(response.data);

    return [for (final row in rows) _mapRequest(row)];
  }

  @override
  Future<StockTransferRequest> createLoadingRequest({
    required int warehouseId,
    required int warehouseManagerId,
    required List<StockTransferRequestItem> items,
    String reference = '',
  }) async {
    final response = await client.dio.post(
      '/inventory/transfer-requests/',
      data: {
        'request_type': 'WAREHOUSE_TO_VEHICLE',
        'warehouse': warehouseId,
        'warehouse_manager': warehouseManagerId,
        'reference': reference,
        'items': [
          for (final item in items)
            {
              'product': item.productId,
              'quantity': item.quantity,
            },
        ],
      },
    );
    return _mapRequest(Map<String, dynamic>.from(response.data as Map));
  }

  @override
  Future<StockTransferRequest> createReturnRequest({
    required int warehouseId,
    required int warehouseManagerId,
    required int invoiceId,
    required List<StockTransferRequestItem> items,
    String reference = '',
  }) async {
    final response = await client.dio.post(
      '/inventory/transfer-requests/',
      data: {
        'request_type': 'VEHICLE_TO_WAREHOUSE',
        'warehouse': warehouseId,
        'warehouse_manager': warehouseManagerId,
        'invoice': invoiceId,
        'reference': reference,
        'items': [
          for (final item in items)
            {
              'product': item.productId,
              'quantity': item.quantity,
              'invoice_item': item.invoiceItemId,
            },
        ],
      },
    );
    return _mapRequest(Map<String, dynamic>.from(response.data as Map));
  }

  StockTransferRequest _mapRequest(Map<String, dynamic> row) {
    final requestType = _readString(row['request_type']);
    final status = _readString(row['status']);
    final rawItems = _readList(row['items']);

    return StockTransferRequest(
      id: _readInt(row['id']),
      type: requestType == 'VEHICLE_TO_WAREHOUSE'
          ? StockTransferRequestType.vehicleToWarehouse
          : StockTransferRequestType.warehouseToVehicle,
      status: switch (status) {
        'approved' => StockTransferRequestStatus.approved,
        'rejected' => StockTransferRequestStatus.rejected,
        'cancelled' => StockTransferRequestStatus.cancelled,
        _ => StockTransferRequestStatus.pending,
      },
      warehouseId: _readInt(row['warehouse']),
      warehouseName: _readString(row['warehouse_name']),
      warehouseManagerId: _readInt(row['warehouse_manager']),
      warehouseManagerName: _readString(row['warehouse_manager_name']),
      items: [
        for (final item in rawItems)
          StockTransferRequestItem(
            productId: _readInt(item['product']),
            productName: _readString(item['product_name']),
            quantity: _readInt(item['quantity']),
            invoiceItemId: _readNullableInt(item['invoice_item_id']),
          ),
      ],
      reference: _readString(row['reference']),
      rejectionReason: _readString(row['rejection_reason']),
      createdAt: DateTime.tryParse(_readString(row['created_at'])) ?? DateTime.fromMillisecondsSinceEpoch(0),
      reviewedAt: DateTime.tryParse(_readString(row['reviewed_at'])),
    );
  }

  List<Map<String, dynamic>> _readResults(dynamic payload) {
    if (payload is Map && payload['results'] is List) {
      return _readList(payload['results']);
    }
    return _readList(payload);
  }

  List<Map<String, dynamic>> _readList(dynamic payload) {
    if (payload is! List) return const [];
    return [
      for (final item in payload)
        if (item is Map) Map<String, dynamic>.from(item),
    ];
  }

  String _readString(dynamic value) => value?.toString() ?? '';

  int _readInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int? _readNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    return int.tryParse(value.toString());
  }
}
