import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../../../customers/domain/payment_method.dart';
import '../domain/entities/representative_customer.dart';
import '../domain/repositories/representative_sale_repository.dart';

class DioRepresentativeSaleRepository implements RepresentativeSaleRepository {
  final ApiClient client;

  const DioRepresentativeSaleRepository(this.client);

  @override
  Future<List<RepresentativeCustomer>> fetchCustomers({String search = ''}) async {
    final response = await client.dio.get(
      '/customers/customers/',
      queryParameters: {
        if (search.trim().isNotEmpty) 'search': search.trim(),
        'page_size': 100,
      },
    );

    final rows = _readResults(response.data);
    return [
      for (final row in rows)
        RepresentativeCustomer(
          id: _readInt(row['id']),
          name: _readString(row['name']),
          phone: _readString(row['phone']),
        ),
    ];
  }

  @override
  Future<int> createAndConfirmSale({
    required int customerId,
    required Map<int, int> quantities,
    required PaymentMethod paymentMethod,
    required double paymentAmount,
  }) async {
    if (quantities.isEmpty) {
      throw ArgumentError('A sale must contain at least one item.');
    }
    if (!paymentAmount.isFinite || paymentAmount < 0) {
      throw ArgumentError('Payment amount must be zero or greater.');
    }

    final createResponse = await client.dio.post(
      '/invoices/',
      data: {
        'customer': customerId,
        'items': [
          for (final entry in quantities.entries)
            {
              'product': entry.key,
              'quantity': entry.value,
            },
        ],
      },
    );

    final invoice = Map<String, dynamic>.from(createResponse.data as Map);
    final invoiceId = _readInt(invoice['id']);
    if (invoiceId <= 0) {
      throw StateError('The server did not return a valid invoice id.');
    }

    await client.dio.post('/invoices/$invoiceId/confirm/');

    if (paymentAmount > 0) {
      await client.dio.post(
        '/payments/collections/',
        options: Options(
          headers: {
            'Idempotency-Key':
                'rep-sale-$invoiceId-${DateTime.now().microsecondsSinceEpoch}',
          },
        ),
        data: {
          'customer': customerId,
          'cash_amount': paymentMethod == PaymentMethod.cash ? paymentAmount : 0,
          'transfer_amount': paymentMethod == PaymentMethod.transfer ? paymentAmount : 0,
        },
      );
    }

    return invoiceId;
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
}
