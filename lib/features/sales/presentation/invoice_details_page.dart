import 'package:flutter/material.dart';

import '../../customers/domain/customer.dart';
import '../data/local_sale_repository.dart';

class InvoiceDetailsPage extends StatelessWidget {
  final Customer customer;
  final int invoiceId;

  const InvoiceDetailsPage({
    super.key,
    required this.customer,
    required this.invoiceId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Invoice #$invoiceId')),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: LocalSaleRepository().getCustomerInvoices(customer.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final matches = (snapshot.data ?? const [])
              .where((invoice) => invoice['id'] == invoiceId)
              .toList();
          if (matches.isEmpty) return const Center(child: Text('Invoice not found.'));
          final invoice = matches.first;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('Customer: ${customer.name}'),
              Text('Subtotal: ${invoice['subtotal']}'),
              Text('Discount: ${invoice['coupon_discount']}'),
              Text('Total: ${invoice['total']}'),
            ],
          );
        },
      ),
    );
  }
}
