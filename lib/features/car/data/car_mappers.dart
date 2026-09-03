import '../domain/entities/car_financial_summary.dart';
import '../domain/entities/car_load_item.dart';
import '../domain/entities/car_payment_allocation.dart';
import '../domain/entities/car_payment_transaction.dart';
import '../domain/entities/car_revision.dart';
import '../domain/entities/car_trip.dart';
import '../domain/entities/car_trip_summary_view.dart';
import '../domain/entities/money.dart';
import '../domain/entities/sales_car.dart';
import '../domain/entities/warehouse.dart';
import '../domain/services/car_calculator.dart';

/// Thin database-row ↔ domain mapping helpers for the Car module.
class CarMappers {
  const CarMappers();

  static const _calculator = CarCalculator();

  Map<String, Object?> salesCarToInsertRow(SalesCar car) => {
        'name': car.name.trim(),
        'plate': car.plate.trim(),
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

  Map<String, Object?> warehouseToInsertRow(Warehouse warehouse) => {
        'name': warehouse.name.trim(),
        'location': warehouse.location?.trim(),
        'is_active': warehouse.isActive ? 1 : 0,
        'created_at': warehouse.createdAt.toUtc().toIso8601String(),
      };

  Warehouse warehouseFromRow(Map<String, Object?> row) => Warehouse(
        id: row['id'] as int,
        name: row['name'] as String,
        location: row['location'] as String?,
        isActive: (row['is_active'] as int?) != 0,
        createdAt: DateTime.parse(row['created_at'] as String),
      );

  Map<String, Object?> itemToRow(CarLoadItem item, int tripId) => {
        'trip_id': tripId,
        'product_id': item.productId,
        'product_name': item.productName,
        'unit_price_minor': item.sellingPrice.minorUnits,
        'purchase_price_minor': item.purchasePrice.minorUnits,
        'loaded_cartons': item.loadedCartons,
        'returned_cartons': item.returnedCartons,
        'discount_percent': item.discountPercent,
      };

  CarLoadItem itemFromRow(Map<String, Object?> row) => CarLoadItem(
        productId: row['product_id'] as int,
        productName: row['product_name'] as String,
        unitPrice: CarMoney((row['unit_price_minor'] as num).toInt()),
        purchasePrice: CarMoney(
          (row['purchase_price_minor'] as num?)?.toInt() ??
              (row['unit_price_minor'] as num).toInt(),
        ),
        loadedCartons: (row['loaded_cartons'] as num).toInt(),
        returnedCartons: (row['returned_cartons'] as num).toInt(),
        discountPercent: (row['discount_percent'] as num?)?.toDouble() ?? 0,
      );

  Map<String, Object?> tripToRow(
    CarTrip trip,
    CarFinancialSummary summary, {
    required DateTime updatedAt,
  }) => {
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
        'subtotal_after_products_minor': summary.subtotalAfterProducts.minorUnits,
        'global_discount_amount_minor': summary.globalDiscountAmount.minorUnits,
        'final_total_value_minor': summary.finalTotalSoldValue.minorUnits,
        'total_loaded_cartons': summary.totalLoadedCartons,
        'total_returned_cartons': summary.totalReturnedCartons,
        'total_returned_value_minor': summary.totalReturnedValue.minorUnits,
        'total_sold_cartons': summary.totalSoldCartons,
        'paid_cash_minor': trip.payment.cashAmount.minorUnits,
        'paid_transfer_minor': trip.payment.transferAmount.minorUnits,
        'created_at': trip.openedAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  CarTrip tripFromRow(Map<String, Object?> row, List<CarLoadItem> items) =>
      CarTrip(
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
        globalDiscountEgp: _fixedGlobalDiscount(row, items),
        payment: CarPayment(
          cashAmount: CarMoney((row['paid_cash_minor'] as num?)?.toInt() ?? 0),
          transferAmount:
              CarMoney((row['paid_transfer_minor'] as num?)?.toInt() ?? 0),
        ),
      );

  CarTripSummaryView tripSummaryFromRow(Map<String, Object?> row) =>
      CarTripSummaryView(
        id: row['id'] as int,
        displayNumber: row['display_number'] as String,
        salesCarName: row['sales_car_name'] as String,
        warehouseName: row['warehouse_name'] as String,
        openedAt: DateTime.parse(row['opened_at'] as String),
        closedAt: _nullableDate(row['closed_at']),
        dueDate: _nullableDate(row['due_date']),
        status: CarTripStatus.fromValue(row['status'] as String?),
        totalLoadedCartons: (row['total_loaded_cartons'] as num).toInt(),
        totalReturnedCartons: (row['total_returned_cartons'] as num).toInt(),
        totalSoldCartons: (row['total_sold_cartons'] as num).toInt(),
        totalReturnedValue:
            CarMoney((row['total_returned_value_minor'] as num?)?.toInt() ?? 0),
        grossSubtotal: CarMoney((row['gross_subtotal_minor'] as num).toInt()),
        productDiscountTotal:
            CarMoney((row['product_discount_total_minor'] as num).toInt()),
        subtotalAfterProducts:
            CarMoney((row['subtotal_after_products_minor'] as num).toInt()),
        globalDiscountAmount:
            CarMoney((row['global_discount_amount_minor'] as num).toInt()),
        finalValue: CarMoney((row['final_total_value_minor'] as num).toInt()),
        paidCash: CarMoney((row['paid_cash_minor'] as num).toInt()),
        paidTransfer: CarMoney((row['paid_transfer_minor'] as num).toInt()),
      );

  Map<String, Object?> revisionToRow(CarRevision revision) {
    final summary = _calculator.summary(_revisionAsTrip(revision));
    return {
      'trip_id': revision.tripId,
      'display_number': revision.displayNumber,
      'revision_number': revision.revisionNumber,
      'created_at': revision.createdAt.toUtc().toIso8601String(),
      'triggered_by': revision.triggeredBy,
      'sales_car_id': revision.salesCarId,
      'sales_car_name': revision.salesCarName,
      'warehouse_id': revision.warehouseId,
      'warehouse_name': revision.warehouseName,
      'status': revision.status.value,
      'opened_at': revision.openedAt.toUtc().toIso8601String(),
      'closed_at': revision.closedAt?.toUtc().toIso8601String(),
      'due_date': revision.dueDate?.toUtc().toIso8601String(),
      'global_discount_percent': revision.globalDiscountPercent,
      'gross_subtotal_minor': summary.grossSubtotal.minorUnits,
      'product_discount_total_minor': summary.productDiscountTotal.minorUnits,
      'subtotal_after_products_minor': summary.subtotalAfterProducts.minorUnits,
      'global_discount_amount_minor': summary.globalDiscountAmount.minorUnits,
      'final_total_value_minor': summary.finalTotalSoldValue.minorUnits,
      'total_loaded_cartons': summary.totalLoadedCartons,
      'total_returned_cartons': summary.totalReturnedCartons,
      'total_returned_value_minor': summary.totalReturnedValue.minorUnits,
      'total_sold_cartons': summary.totalSoldCartons,
      'paid_cash_minor': revision.payment.cashAmount.minorUnits,
      'paid_transfer_minor': revision.payment.transferAmount.minorUnits,
    };
  }

  CarRevision revisionFromRow(
    Map<String, Object?> row,
    List<CarLoadItem> items,
  ) {
    final fixedGlobalDiscount = _fixedGlobalDiscount(row, items);
    return CarRevision(
      id: row['id'] as int,
      tripId: row['trip_id'] as int,
      displayNumber: row['display_number'] as String,
      revisionNumber: row['revision_number'] as int,
      createdAt: DateTime.parse(row['created_at'] as String),
      triggeredBy: row['triggered_by'] as String?,
      salesCarId: row['sales_car_id'] as int,
      salesCarName: row['sales_car_name'] as String,
      warehouseId: row['warehouse_id'] as int,
      warehouseName: row['warehouse_name'] as String,
      status: CarTripStatus.fromValue(row['status'] as String?),
      openedAt: DateTime.parse(row['opened_at'] as String),
      closedAt: _nullableDate(row['closed_at']),
      dueDate: _nullableDate(row['due_date']),
      items: items,
      globalDiscountPercent:
          (row['global_discount_percent'] as num?)?.toDouble() ?? 0,
      globalDiscountEgp: fixedGlobalDiscount,
      globalDiscountAmount:
          CarMoney((row['global_discount_amount_minor'] as num?)?.toInt() ?? 0),
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
        'unit_price_minor': item.sellingPrice.minorUnits,
        'purchase_price_minor': item.purchasePrice.minorUnits,
        'loaded_cartons': item.loadedCartons,
        'returned_cartons': item.returnedCartons,
        'discount_percent': item.discountPercent,
      };

  Map<String, Object?> paymentTransactionToRow(CarPaymentTransaction transaction) => {
        'cash_amount_minor': transaction.cashAmount.minorUnits,
        'transfer_amount_minor': transaction.transferAmount.minorUnits,
        'reference': transaction.reference,
        'created_at': transaction.createdAt.toUtc().toIso8601String(),
      };

  CarPaymentTransaction paymentTransactionFromRow(Map<String, Object?> row) =>
      CarPaymentTransaction(
        id: row['id'] as int,
        cashAmount: CarMoney((row['cash_amount_minor'] as num).toInt()),
        transferAmount: CarMoney((row['transfer_amount_minor'] as num).toInt()),
        reference: row['reference'] as String?,
        createdAt: DateTime.parse(row['created_at'] as String),
      );

  Map<String, Object?> allocationToRow(
    CarPaymentAllocation allocation,
    int transactionId,
  ) => {
        'payment_transaction_id': transactionId,
        'trip_id': allocation.tripId,
        'cash_amount_minor': allocation.cashAmount.minorUnits,
        'transfer_amount_minor': allocation.transferAmount.minorUnits,
      };

  CarPaymentAllocation allocationFromRow(Map<String, Object?> row) =>
      CarPaymentAllocation(
        id: row['id'] as int,
        transactionId: row['payment_transaction_id'] as int,
        tripId: row['trip_id'] as int,
        cashAmount: CarMoney((row['cash_amount_minor'] as num).toInt()),
        transferAmount: CarMoney((row['transfer_amount_minor'] as num).toInt()),
      );

  CarTrip _revisionAsTrip(CarRevision revision) => CarTrip(
        id: revision.tripId,
        displayNumber: revision.displayNumber,
        salesCarId: revision.salesCarId,
        salesCarName: revision.salesCarName,
        warehouseId: revision.warehouseId,
        warehouseName: revision.warehouseName,
        openedAt: revision.openedAt,
        closedAt: revision.closedAt,
        dueDate: revision.dueDate,
        status: revision.status,
        items: revision.items,
        globalDiscountPercent: revision.globalDiscountPercent,
        globalDiscountEgp: revision.globalDiscountEgp,
        payment: revision.payment,
      );

  CarMoney _fixedGlobalDiscount(
    Map<String, Object?> row,
    List<CarLoadItem> items,
  ) {
    final storedTotal =
        CarMoney((row['global_discount_amount_minor'] as num?)?.toInt() ?? 0);
    final purchaseAfterProducts = items.fold<CarMoney>(
      CarMoney.zero,
      (sum, item) {
        final gross = item.purchasePrice * (item.loadedCartons - item.returnedCartons);
        return sum + gross - gross.percentOf(item.discountPercent);
      },
    );
    final percent = purchaseAfterProducts.percentOf(
      (row['global_discount_percent'] as num?)?.toDouble() ?? 0,
    );
    final fixed = storedTotal - percent;
    return fixed.isNegative ? CarMoney.zero : fixed;
  }

  DateTime? _nullableDate(Object? value) =>
      value == null ? null : DateTime.parse(value as String);
}
