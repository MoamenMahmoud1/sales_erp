import '../../customers/domain/payment_method.dart';
import '../../payment/domain/payment_status.dart';

class Invoice {
  final int id;
  final int customerId;

  final DateTime createdAt;
  final DateTime updatedAt;

  final Map<int, int> products;

  final double subtotal;
  final double couponDiscount;
  final double total;

  final PaymentMethod paymentMethod;
  final PaymentStatus paymentStatus;

  const Invoice({
    required this.id,
    required this.customerId,
    required this.createdAt,
    required this.updatedAt,
    required this.products,
    required this.subtotal,
    required this.couponDiscount,
    required this.total,
    required this.paymentMethod,
    required this.paymentStatus,
  });

  double get calculatedTotal {
    final result = subtotal - couponDiscount;

    return result < 0 ? 0 : result;
  }

  bool get hasCouponDiscount {
    return couponDiscount > 0;
  }

  bool get isPaid {
    return paymentStatus == PaymentStatus.paid;
  }

  bool get isPending {
    return paymentStatus == PaymentStatus.pending;
  }

  double get outstandingAmount {
    return isPaid ? 0 : calculatedTotal;
  }

  factory Invoice.fromMap(
    Map<String, Object?> map, {
    Map<int, int> products = const {},
  }) {
    return Invoice(
      id: map['id'] as int,

      customerId: map['customer_id'] as int,

      createdAt: DateTime.parse(
        map['created_at'] as String,
      ),

      updatedAt: DateTime.parse(
        map['updated_at'] as String,
      ),

      products: Map<int, int>.unmodifiable(
        products,
      ),

      subtotal:
          (map['subtotal'] as num?)?.toDouble() ?? 0,

      couponDiscount:
          (map['coupon_discount'] as num?)
                  ?.toDouble() ??
              0,

      total:
          (map['total'] as num?)?.toDouble() ?? 0,

      paymentMethod: paymentMethodFromValue(
        map['payment_method'] as String?,
      ),

      paymentStatus: PaymentStatus.fromValue(
        map['payment_status'] as String?,
      ),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'created_at':
          createdAt.toUtc().toIso8601String(),
      'updated_at':
          updatedAt.toUtc().toIso8601String(),
      'subtotal': subtotal,
      'coupon_discount': couponDiscount,
      'total': total,
      'payment_method': paymentMethod.value,
      'payment_status': paymentStatus.value,
    };
  }
}