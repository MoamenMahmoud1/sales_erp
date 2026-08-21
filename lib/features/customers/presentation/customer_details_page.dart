import 'package:flutter/material.dart';

import '../../sales/data/local_sale_repository.dart';
import '../../sales/presentation/invoice_details_page.dart';
import '../../sales/presentation/invoice_editor_page.dart';
import '../domain/customer.dart';

class CustomerDetailsPage extends StatefulWidget {
  final Customer customer;

  const CustomerDetailsPage({
    super.key,
    required this.customer,
  });

  @override
  State<CustomerDetailsPage> createState() =>
      _CustomerDetailsPageState();
}

class _CustomerDetailsPageState
    extends State<CustomerDetailsPage> {
  final _saleRepository = LocalSaleRepository();

  List<Map<String, Object?>> _invoices = [];

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    final invoices =
        await _saleRepository.getCustomerInvoices(
      widget.customer.id,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _invoices = invoices;
    });
  }

  Future<void> _createInvoice() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceEditorPage(
          customer: widget.customer,
        ),
      ),
    );

    if (saved == true) {
      await _loadInvoices();
    }
  }

  Future<void> _editInvoice(int invoiceId) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceEditorPage(
          customer: widget.customer,
          invoiceId: invoiceId,
        ),
      ),
    );

    if (saved == true) {
      await _loadInvoices();
    }
  }

  Future<void> _deleteInvoice(int invoiceId) async {
    await _saleRepository.deleteInvoice(invoiceId);
    await _loadInvoices();
  }

  String _formatDate(String value) {
    final date = DateTime.parse(value).toLocal();

    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');

    final hour = date.hour.toString().padLeft(2, '0');
    final minute =
        date.minute.toString().padLeft(2, '0');

    return '$day/$month/${date.year} $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customer.name),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.customer.name,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(widget.customer.phone),
            Text(widget.customer.address),
            const SizedBox(height: 24),
            Text(
              'Invoices',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge,
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _invoices.isEmpty
                  ? const Center(
                      child: Text(
                        'No invoices yet.',
                      ),
                    )
                  : ListView.builder(
                      itemCount: _invoices.length,
                      itemBuilder: (
                        context,
                        index,
                      ) {
                        final invoice =
                            _invoices[index];

                        final invoiceId =
                            invoice['id'] as int;

                        final createdAt =
                            invoice['created_at']
                                as String;

                        final updatedAt =
                            invoice['updated_at']
                                as String;

                        final subtotal =
                            (invoice['subtotal']
                                    as num?)
                                ?.toDouble() ??
                            0;

                        final couponDiscount =
                            (invoice[
                                        'coupon_discount']
                                    as num?)
                                ?.toDouble() ??
                            0;

                        final total =
                            (invoice['total'] as num?)
                                ?.toDouble() ??
                            subtotal -
                                couponDiscount;

                        return Card(
                          margin:
                              const EdgeInsets.only(
                            bottom: 12,
                          ),
                          child: ListTile(
                            title: Text(
                              'Invoice #$invoiceId',
                            ),
                            subtitle: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,
                              children: [
                                const SizedBox(
                                  height: 4,
                                ),
                                Text(
                                  'Created: '
                                  '${_formatDate(createdAt)}',
                                ),
                                Text(
                                  'Updated: '
                                  '${_formatDate(updatedAt)}',
                                ),
                                const SizedBox(
                                  height: 6,
                                ),
                                Text(
                                  'Subtotal: '
                                  '${subtotal.toStringAsFixed(2)} EGP',
                                ),
                                if (couponDiscount >
                                    0)
                                  Text(
                                    'Coupon discount: '
                                    '${couponDiscount.toStringAsFixed(2)} EGP',
                                  ),
                                Text(
                                  'Total: '
                                  '${total.toStringAsFixed(2)} EGP',
                                  style: const TextStyle(
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      InvoiceDetailsPage(
                                    customer:
                                        widget.customer,
                                    invoiceId:
                                        invoiceId,
                                  ),
                                ),
                              );

                              if (!mounted) {
                                return;
                              }

                              await _loadInvoices();
                            },
                            trailing: PopupMenuButton<
                                String>(
                              onSelected: (
                                value,
                              ) {
                                if (value == 'edit') {
                                  _editInvoice(
                                    invoiceId,
                                  );
                                }

                                if (value == 'delete') {
                                  _deleteInvoice(
                                    invoiceId,
                                  );
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Text('Edit'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    'Delete',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: _createInvoice,
          icon: const Icon(Icons.add),
          label: const Text('New Invoice'),
        ),
      ),
    );
  }
}

