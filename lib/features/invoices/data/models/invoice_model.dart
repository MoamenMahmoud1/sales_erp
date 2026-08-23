import '../../domain/entities/coupon.dart';
import '../../domain/entities/invoice.dart';
import '../../domain/entities/invoice_item.dart';
import '../../domain/entities/money.dart';
import '../../domain/entities/payment.dart';
import 'invoice_item_model.dart';
import 'payment_model.dart';

class InvoiceModel {
  final int id;
  final int customerId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? paidAt;
  final List<InvoiceItemModel> items;
  final Coupon? coupon;
  final PaymentModel payment;

  const InvoiceModel({
    required this.id,
    required this.customerId,
    required this.createdAt,
    required this.updatedAt,
    required this.paidAt,
    required this.items,
    required this.coupon,
    required this.payment,
  });

  factory InvoiceModel.fromMap(
    Map<String, dynamic> map, {
    required List<InvoiceItemModel> items,
    required PaymentModel payment,
    Coupon? coupon,
  }) {
    return InvoiceModel(
      id: map['id'] as int,
      customerId: map['customer_id'] as int,
      createdAt: DateTime.parse(
        map['created_at'] as String,
      ),
      updatedAt: DateTime.parse(
        map['updated_at'] as String,
      ),
      paidAt: map['paid_at'] == null
          ? null
          : DateTime.parse(
              map['paid_at'] as String,
            ),
      items: items,
      coupon: coupon,
      payment: payment,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'paid_at': paidAt?.toIso8601String(),
      'coupon_id': null,
    };
  }

  Invoice toEntity() {
    return Invoice(
      id: id,
      customerId: customerId,
      createdAt: createdAt,
      updatedAt: updatedAt,
      paidAt: paidAt,
      items: List<InvoiceItem>.unmodifiable(
        items.map(
          (item) => item.toEntity(),
        ),
      ),
      coupon: coupon,
      payment: payment.toEntity(),
    );
  }

  factory InvoiceModel.fromEntity(
    Invoice entity, {
    required List<InvoiceItemModel> items,
    required PaymentModel payment,
  }) {
    return InvoiceModel(
      id: entity.id,
      customerId: entity.customerId,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      paidAt: entity.paidAt,
      items: items,
      coupon: entity.coupon,
      payment: payment,
    );
  }
}