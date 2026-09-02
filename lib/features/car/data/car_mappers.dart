import '../domain/entities/car_financial_summary.dart';
import '../domain/entities/car_load_item.dart';
import '../domain/entities/car_payment.dart';
import '../domain/entities/car_payment_allocation.dart';
import '../domain/entities/car_payment_transaction.dart';
import '../domain/entities/car_revision.dart';
import '../domain/entities/car_trip.dart';
import '../domain/entities/car_trip_status.dart';
import '../domain/entities/car_trip_summary_view.dart';
import '../domain/entities/money.dart';
import '../domain/entities/sales_car.dart';
import '../domain/entities/warehouse.dart';
import '../domain/services/car_calculator.dart';

/// Row ⇄ domain mappers. Dates are stored as UTC ISO strings (reliable string
/// range filtering); money is always integer minor units.
class CarMappers {
  const CarMappers();
  static const CarCalculator _calculator = CarCalculator();

  // ---------------------------------------------------------------
  // SalesCar
  // ---------------------------------------------------------------

  Map<String, Object?> salesCarToInsertRow(SalesCar car) => {
        'name': car.name,
        'plate': car.plate,
        'is_active': car.isActive ? 1 : 0,
        'created_at': car.createdAt.toUtc().toIso8601String(),
      };

  SalesCar salesCarFromRow(Map<String, Object?> row) => SalesCar(
        id: row['id'] as int,
        name: row['name'] as String,
        plate: (row['plate'] as String?) ?? '',
        isActive: (row['is_active'] as int?) != 0,
        createdAt: DateTime.parse(row['created_at'] as String),
      );

  // ---------------------------------------------------------------
  // Warehouse
  // ---------------------------------------------------------------

  Map<String, Object?> warehouseToInsertRow(Warehouse w) => {
        'name': w.name,
        'location': w.location,
        'is_active': w.isActive ? 1 : 0,
        'created_at': w.createdAt.toUtc().toIso8601String(),
      };

  Warehouse warehouseFromRow(Map<String, Object?> row) => Warehouse(
        id: row['id'] as int,
        name: row['name'] as String,
        location: row['location'] as String?,
        isActive: (row['is_active'] as int?) != 0,
        createdAt: DateTime.parse(row['created_at'] as String),
      );

  // ---------------------------------------------------------------
  // CarLoadItem
  // ---------------------------------------------------------------

  Map<String, Object?> itemToRow(CarLoadItem item, int tripId) => {
        'trip_id': tripId,
        'product_id': item.productId,
        'product_name': item.productName,
        'unit_price_minor': item.unitPrice.minorUnits,
        'loaded_cartons': item.loadedCartons,
        'returned_cartons': item.returnedCartons,
        'discount_percent': item.discountPercent,
      };

  CarLoadItem itemFromRow(Map<String, Object?> row) => CarLoadItem(
        productId: row['product_id'] as int,
        productName: row['product_name'] as String,
        unitPrice: CarMoney(row['unit_price_minor'] as int),
        loadedCartons: row['loaded_cartons'] as int,
        returnedCartons: row['returned_cartons'] as int,
        discountPercent: (row['discount_percent'] as num?)?.toDouble() ?? 0,
      );

  // ---------------------------------------------------------------
  // CarTrip
  // ---------------------------------------------------------------

  /// Full row (including created_at) used for inserts.
  Map<String, Object?> tripToRow(
    CarTrip trip,
    CarFinancialSummary summary, {
    required DateTime updatedAt,
  }) {
    return {
      'display_number': trip.displayNumber,
      'sales_car_id': trip.salesCarId,
      'sales_car_name': trip.salesCarName,
      'warehouse_id': trip.warehouseId,
      'warehouse_name': trip.warehouseName,
      'opened_at': trip.openedAt.toUtc().toIso8601String(),
      'closed_at': trip.closedAt?.toUtc().toIso8601String(),
      'due_date': trip.dueDate?.toUtc().toIso8601String(),
      'status': trip.status.value,
      'global_discount_percent': trip.globalDiscountPercent,
      'gross_subtotal_minor': summary.grossSubtotal.minorUnits,
      'product_discount_total_minor': summary.productDiscountTotal.minorUnits,
      'subtotal_after_products_minor':
          summary.subtotalAfterProducts.minorUnits,
      'global_discount_amount_minor': summary.globalDiscountAmount.minorUnits,
      'final_total_value_minor': summary.finalTotalSoldValue.minorUnits,
      'total_loaded_cartons': summary.totalLoadedCartons,
      'total_returned_cartons': summary.totalReturnedCartons,
      'total_sold_cartons': summary.totalSoldCartons,
      'paid_cash_minor': trip.payment.cashAmount.minorUnits,
      'paid_transfer_minor': trip.payment.transferAmount.minorUnits,
      'created_at': trip.openedAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  CarTrip tripFromRow(Map<String, Object?> row, List<CarLoadItem> items) {
    return CarTrip(
      id: row['id'] as int,
      displayNumber: row['display_number'] as String,
      salesCarId: row['sales_car_id'] as int,
      salesCarName: row['sales_car_name'] as String,
      warehouseId: row['warehouse_id'] as int,
      warehouseName: row['warehouse_name'] as String,
      openedAt: DateTime.parse(row['opened_at'] as String),
      closedAt: _nullableDate(row['closed_at']),
      dueDate: _nullableDate(row['due_date']),
      status: CarTripStatus.fromValue(row['status'] as String?),
      items: items,
      globalDiscountPercent:
          (row['global_discount_percent'] as num?)?.toDouble() ?? 0,
      payment: CarPayment(
        cashAmount: CarMoney((row['paid_cash_minor'] as num?)?.toInt() ?? 0),
        transferAmount:
            CarMoney((row['paid_transfer_minor'] as num?)?.toInt() ?? 0),
      ),
    );
  }

  CarTripSummaryView tripSummaryFromRow(Map<String, Object?> row) {
    return CarTripSummaryView(
      id: row['id'] as int,
      displayNumber: row['display_number'] as String,
      salesCarName: row['sales_car_name'] as String,
      warehouseName: row['warehouse_name'] as String,
      openedAt: DateTime.parse(row['opened_at'] as String),
      closedAt: _nullableDate(row['closed_at']),
      dueDate: _nullableDate(row['due_date']),
      status: CarTripStatus.fromValue(row['status'] as String?),
      totalLoadedCartons: row['total_loaded_cartons'] as int,
      totalReturnedCartons: row['total_returned_cartons'] as int,
      totalSoldCartons: row['total_sold_cartons'] as int,
      grossSubtotal: CarMoney(row['gross_subtotal_minor'] as int),
      productDiscountTotal:
          CarMoney(row['product_discount_total_minor'] as int),
      subtotalAfterProducts:
          CarMoney(row['subtotal_after_products_minor'] as int),
      globalDiscountAmount:
          CarMoney(row['global_discount_amount_minor'] as int),
      finalValue: CarMoney(row['final_total_value_minor'] as int),
      paidCash: CarMoney(row['paid_cash_minor'] as int),
      paidTransfer: CarMoney(row['paid_transfer_minor'] as int),
    );
  }

  // ---------------------------------------------------------------
  // CarRevision
  // ---------------------------------------------------------------

  /// Maps a revision to a row. The summary columns are computed from the
  /// revision's own (frozen) snapshot items — never from current products.
  Map<String, Object?> revisionToRow(CarRevision r) {
    final summary = _calculator.summary(_revisionAsTrip(r));
    return {
      'trip_id': r.tripId,
      'display_number': r.displayNumber,
      'revision_number': r.revisionNumber,
      'created_at': r.createdAt.toUtc().toIso8601String(),
      'triggered_by': r.triggeredBy,
      'status': r.status.value,
      'opened_at': r.openedAt.toUtc().toIso8601String(),
      'closed_at': r.closedAt?.toUtc().toIso8601String(),
      'due_date': r.dueDate?.toUtc().toIso8601String(),
      'global_discount_percent': r.globalDiscountPercent,
      'gross_subtotal_minor': summary.grossSubtotal.minorUnits,
      'product_discount_total_minor': summary.productDiscountTotal.minorUnits,
      'subtotal_after_products_minor':
          summary.subtotalAfterProducts.minorUnits,
      'global_discount_amount_minor': summary.globalDiscountAmount.minorUnits,
      'final_total_value_minor': summary.finalTotalSoldValue.minorUnits,
      'total_loaded_cartons': summary.totalLoadedCartons,
      'total_returned_cartons': summary.totalReturnedCartons,
      'total_sold_cartons': summary.totalSoldCartons,
      'paid_cash_minor': r.payment.cashAmount.minorUnits,
      'paid_transfer_minor': r.payment.transferAmount.minorUnits,
    };
  }

  CarRevision revisionFromRow(
    Map<String, Object?> row,
    List<CarLoadItem> items,
  ) {
    return CarRevision(
      id: row['id'] as int,
      tripId: row['trip_id'] as int,
      displayNumber: row['display_number'] as String,
      revisionNumber: row['revision_number'] as int,
      createdAt: DateTime.parse(row['created_at'] as String),
      triggeredBy: row['triggered_by'] as String?,
      status: CarTripStatus.fromValue(row['status'] as String?),
      openedAt: DateTime.parse(row['opened_at'] as String),
      closedAt: _nullableDate(row['closed_at']),
      dueDate: _nullableDate(row['due_date']),
      items: items,
      globalDiscountPercent:
          (row['global_discount_percent'] as num?)?.toDouble() ?? 0,
      payment: CarPayment(
        cashAmount: CarMoney((row['paid_cash_minor'] as num?)?.toInt() ?? 0),
        transferAmount:
            CarMoney((row['paid_transfer_minor'] as num?)?.toInt() ?? 0),
      ),
    );
  }

  Map<String, Object?> revisionItemToRow(CarLoadItem item, int revisionId) => {
        'revision_id': revisionId,
        'product_id': item.productId,
        'product_name': item.productName,
        'unit_price_minor': item.unitPrice.minorUnits,
        'loaded_cartons': item.loadedCartons,
        'returned_cartons': item.returnedCartons,
        'discount_percent': item.discountPercent,
      };

  // ---------------------------------------------------------------
  // Payments
  // ---------------------------------------------------------------

  Map<String, Object?> paymentTransactionToRow(CarPaymentTransaction t) => {
        'cash_amount_minor': t.cashAmount.minorUnits,
        'transfer_amount_minor': t.transferAmount.minorUnits,
        'reference': t.reference,
        'created_at': t.createdAt.toUtc().toIso8601String(),
      };

  CarPaymentTransaction paymentTransactionFromRow(Map<String, Object?> row) =>
      CarPaymentTransaction(
        id: row['id'] as int,
        cashAmount: CarMoney(row['cash_amount_minor'] as int),
        transferAmount: CarMoney(row['transfer_amount_minor'] as int),
        reference: row['reference'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
      );

  Map<String, Object?> allocationToRow(
    CarPaymentAllocation a,
    int transactionId,
  ) =>
      {
        'payment_transaction_id': transactionId,
        'trip_id': a.tripId,
        'cash_amount_minor': a.cashAmount.minorUnits,
        'transfer_amount_minor': a.transferAmount.minorUnits,
      };

  CarPaymentAllocation allocationFromRow(Map<String, Object?> row) =>
      CarPaymentAllocation(
        id: row['id'] as int,
        transactionId: row['payment_transaction_id'] as int,
        tripId: row['trip_id'] as int,
        cashAmount: CarMoney(row['cash_amount_minor'] as int),
        transferAmount: CarMoney(row['transfer_amount_minor'] as int),
      );

  CarTrip _revisionAsTrip(CarRevision r) => CarTrip(
        id: r.tripId,
        displayNumber: r.displayNumber,
        salesCarId: 0,
        salesCarName: '',
        warehouseId: 0,
        warehouseName: '',
        openedAt: r.openedAt,
        closedAt: r.closedAt,
        dueDate: r.dueDate,
        status: r.status,
        items: r.items,
        globalDiscountPercent: r.globalDiscountPercent,
        payment: r.payment,
      );

  DateTime? _nullableDate(Object? value) =>
      value == null ? null : DateTime.parse(value as String);
}