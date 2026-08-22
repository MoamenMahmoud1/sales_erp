import 'coupon.dart';
import 'invoice_item.dart';
import 'payment.dart';

class Invoice {
  final int id;
  final int customerId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? paidAt;
  final List<InvoiceItem> items;
  final Coupon? coupon;
  final Payment payment;

  const Invoice({
    required this.id,
    required this.customerId,
    required this.createdAt,
    required this.updatedAt,
    this.paidAt,
    required this.items,
    this.coupon,
    required this.payment,
  });
  Invoice copyWith({
  int? id,
  int? customerId,
  DateTime? createdAt,
  DateTime? updatedAt,
  DateTime? paidAt,
  List<InvoiceItem>? items,
  Coupon? coupon,
  Payment? payment,
  }) {
  return Invoice(
    id: id ?? this.id,
    customerId: customerId ?? this.customerId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    paidAt: paidAt ?? this.paidAt,
    items: items ?? this.items,
    coupon: coupon ?? this.coupon,
    payment: payment ?? this.payment,
  );
  }

  bool get isPaid => paidAt != null;
}