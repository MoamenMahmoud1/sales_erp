import 'package:flutter/material.dart';

import '../data/local_sale_repository.dart';

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  final _repository = LocalSaleRepository();
  late Future<List<Map<String, Object?>>> _invoices;

  @override
  void initState() {
    super.initState();
    _invoices = _repository.getInvoices();
  }

  String _money(Object? value) {
    return '${(value as num?)?.toDouble().toStringAsFixed(2) ?? '0.00'} EGP';
  }

  String _statusLabel(Object? value) {
    switch (value) {
      case 'paid':
        return 'Paid';
      case 'pending':
        return 'Pending transfer';
      default:
        return 'Unpaid';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Invoices')),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _invoices,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Failed to load invoices: ${snapshot.error}'));
          }
          final invoices = snapshot.data ?? const [];
          if (invoices.isEmpty) return const Center(child: Text('No invoices yet.'));
          return ListView.builder(
            itemCount: invoices.length,
            itemBuilder: (context, index) {
              final invoice = invoices[index];
              final total = (invoice['total'] as num?)?.toDouble() ?? 0;
              final paid = (invoice['paid_amount'] as num?)?.toDouble() ?? 0;
              final pending = (invoice['pending_amount'] as num?)?.toDouble() ?? 0;
              final remaining = (total - paid).clamp(0, total).toDouble();

              return ListTile(
                title: Text('Invoice #${invoice['id']}'),
                subtitle: Text(
                  '${invoice['customer_name']}\n'
                  'Total: ${_money(total)}  •  Paid: ${_money(paid)}\n'
                  'Remaining: ${_money(remaining)}'
                  '${pending > 0 ? '  •  Pending: ${_money(pending)}' : ''}',
                ),
                isThreeLine: true,
                trailing: Chip(label: Text(_statusLabel(invoice['payment_status']))),
              );
            },
          );
        },
      ),
    );
  }
}
