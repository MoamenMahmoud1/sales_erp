import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import 'local_sale_repository.dart';

class HybridInvoiceRepository {
  final ApiClient client;
  final LocalSaleRepository local;

  HybridInvoiceRepository(
    this.client, {
    LocalSaleRepository? local,
  }) : local = local ?? LocalSaleRepository();

  Future<List<Map<String, Object?>>> getInvoices() async {
    try {
      final response = await client.dio.get(
        '/invoices/',
        queryParameters: {
          'ordering': '-created_at',
          'page_size': 100,
        },
      );
      return _readInvoiceList(response.data);
    } on DioException catch (error) {
      if (_canUseLocalFallback(error)) return local.getInvoices();
      rethrow;
    }
  }

  Future<Map<String, Object?>?> getInvoiceWithItems(int invoiceId) async {
    if (invoiceId <= 0) throw ArgumentError('Invalid invoice id.');

    try {
      final response = await client.dio.get('/invoices/$invoiceId/');
      return _readInvoice(response.data);
    } on DioException catch (error) {
      if (_canUseLocalFallback(error)) {
        return local.getInvoiceWithItems(invoiceId);
      }
      rethrow;
    }
  }

  bool _canUseLocalFallback(DioException error) {
    final status = error.response?.statusCode;
    return status == null || status >= 500;
  }

  List<Map<String, Object?>> _readInvoiceList(dynamic payload) {
    final rows = payload is Map ? payload['results'] : payload;
    if (rows is! List) return const [];

    return [
      for (final row in rows)
        if (row is Map) _mapSummary(Map<String, dynamic>.from(row)),
    ];
  }

  Map<String, Object?>? _readInvoice(dynamic payload) {
    if (payload is! Map) return null;
    return _mapDetails(Map<String, dynamic>.from(payload));
  }

  Map<String, Object?> _mapSummary(Map<String, dynamic> row) {
    final total = _number(row['total']);
    final paid = _number(row['paid_amount']);
    final outstanding = _number(row['outstanding_amount']);

    return {
      'id': _integer(row['id']),
      'customer_id': _integer(row['customer']),
      'customer_name': row['customer_name']?.toString() ?? 'Customer',
      'created_at': row['created_at']?.toString() ?? '',
      'updated_at': row['updated_at']?.toString() ?? '',
      'subtotal': _number(row['subtotal']),
      'coupon_discount': _number(row['coupon_discount']),
      'total': total,
      'paid_amount': paid,
      'pending_amount': 0.0,
      'payment_status': outstanding <= 0
          ? 'paid'
          : paid > 0
              ? 'unpaid'
              : 'unpaid',
    };
  }

  Map<String, Object?> _mapDetails(Map<String, dynamic> row) {
    final summary = _mapSummary(row);
    final items = row['items'];

    return {
      ...summary,
      'customer_phone': '',
      'payment_method': null,
      'items': [
        if (items is List)
          for (final item in items)
            if (item is Map)
              {
                'product_id': _integer(item['product']),
                'product_name': item['product_name']?.toString() ?? 'Product',
                'quantity': _integer(item['quantity']),
                'unit_price': _number(item['unit_price']),
              },
      ],
    };
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _integer(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
