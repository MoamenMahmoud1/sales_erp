import 'package:flutter/material.dart';

import '../../payment/data/local_payment_repository.dart';
import '../../payment/domain/payment.dart';
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
  final _paymentRepository = LocalPaymentRepository();

  List<Map<String, Object?>> _invoices = [];
  List<Payment> _payments = [];

  bool _isLoadingPayments = true;

  double _subtotal = 0;
  double _couponDiscount = 0;
  double _total = 0;

  double _paid = 0;
  double _cashPaid = 0;
  double _transferPaid = 0;
  double _pendingTransfers = 0;
  double _balance = 0;

  @override
  void initState() {
    super.initState();

    _loadData();
  }

  Future<void> _loadData() async {
    await Future.wait([
      _loadInvoices(),
      _loadPayments(),
    ]);
  }

  Future<void> _loadInvoices() async {
    final invoices =
        await _saleRepository.getCustomerInvoices(
      widget.customer.id,
    );

    double subtotal = 0;
    double couponDiscount = 0;
    double total = 0;

    for (final invoice in invoices) {
      subtotal +=
          (invoice['subtotal'] as num?)
                  ?.toDouble() ??
              0;

      couponDiscount +=
          (invoice['coupon_discount'] as num?)
                  ?.toDouble() ??
              0;

      total +=
          (invoice['total'] as num?)
                  ?.toDouble() ??
              0;
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _invoices = invoices;
      _subtotal = subtotal;
      _couponDiscount = couponDiscount;
      _total = total;

      _recalculateBalance();
    });
  }

  Future<void> _loadPayments() async {
    setState(() {
      _isLoadingPayments = true;
    });

    final payments =
        await _paymentRepository.getPaymentsForCustomer(
      widget.customer.id,
    );

    double paid = 0;
    double cashPaid = 0;
    double transferPaid = 0;
    double pendingTransfers = 0;

    for (final payment in payments) {
      if (payment.status == PaymentStatus.paid) {
        paid += payment.amount;

        if (payment.method == PaymentMethod.cash) {
          cashPaid += payment.amount;
        } else {
          transferPaid += payment.amount;
        }
      } else if (
          payment.method == PaymentMethod.transfer &&
          payment.status == PaymentStatus.pending) {
        pendingTransfers += payment.amount;
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _payments = payments;
      _paid = paid;
      _cashPaid = cashPaid;
      _transferPaid = transferPaid;
      _pendingTransfers = pendingTransfers;
      _isLoadingPayments = false;

      _recalculateBalance();
    });
  }

  void _recalculateBalance() {
    final balance =
        _total - _paid - _pendingTransfers;

    _balance = balance > 0 ? balance : 0;
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
      await _loadData();
    }
  }

  Future<void> _editInvoice(
    int invoiceId,
  ) async {
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
      await _loadData();
    }
  }

  Future<void> _deleteInvoice(
    int invoiceId,
  ) async {
    await _saleRepository.deleteInvoice(
      invoiceId,
    );

    await _loadData();
  }

  Future<void> _confirmTransfer(
    Payment payment,
  ) async {
    await _paymentRepository.confirmTransfer(
      payment.id,
    );

    await _loadPayments();
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();

    final day =
        local.day.toString().padLeft(2, '0');

    final month =
        local.month.toString().padLeft(2, '0');

    final hour =
        local.hour.toString().padLeft(2, '0');

    final minute =
        local.minute.toString().padLeft(2, '0');

    return '$day/$month/${local.year} '
        '$hour:$minute';
  }

  String _formatMoney(double value) {
    return '${value.toStringAsFixed(2)} EGP';
  }

  Widget _financialRow(
    String title,
    double value, {
    bool bold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontWeight: bold
                    ? FontWeight.bold
                    : FontWeight.normal,
              ),
            ),
          ),
          Text(
            _formatMoney(value),
            style: TextStyle(
              fontWeight: bold
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummary() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Financial Summary',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge,
            ),
            const SizedBox(height: 12),

            _financialRow(
              'Invoice Subtotal',
              _subtotal,
            ),

            _financialRow(
              'Coupon Discounts',
              _couponDiscount,
            ),

            _financialRow(
              'Total Sales',
              _total,
              bold: true,
            ),

            const Divider(height: 20),

            _financialRow(
              'Cash Paid',
              _cashPaid,
            ),

            _financialRow(
              'Transfers Paid',
              _transferPaid,
            ),

            _financialRow(
              'Pending Transfers',
              _pendingTransfers,
            ),

            const Divider(height: 20),

            _financialRow(
              'Paid',
              _paid,
              bold: true,
            ),

            _financialRow(
              'Outstanding',
              _balance,
              bold: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentsSection() {
    if (_isLoadingPayments) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Payments',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge,
            ),
            const SizedBox(height: 12),

            if (_payments.isEmpty)
              const Text(
                'No payments yet.',
              )
            else
              ..._payments.map(
                _buildPaymentTile,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentTile(
    Payment payment,
  ) {
    final isPending =
        payment.status == PaymentStatus.pending;

    final method =
        payment.method == PaymentMethod.cash
            ? 'Cash'
            : 'Transfer';

    final status =
        isPending ? 'Pending' : 'Paid';

    return Card(
      margin: const EdgeInsets.only(
        bottom: 8,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  payment.method ==
                          PaymentMethod.cash
                      ? Icons.payments
                      : Icons.account_balance,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    method,
                    style: const TextStyle(
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  _formatMoney(payment.amount),
                  style: const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 6),

            Text(
              'Invoice #${payment.invoiceId}',
            ),

            Text(
              'Date: '
              '${_formatDate(payment.createdAt)}',
            ),

            Text(
              'Status: $status',
            ),

            if (payment.reference != null &&
                payment.reference!.isNotEmpty)
              Text(
                'Reference: '
                '${payment.reference}',
              ),

            if (isPending) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _confirmTransfer(payment),
                  icon: const Icon(
                    Icons.check,
                  ),
                  label: const Text(
                    'CONFIRM TRANSFER',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInvoicesSection() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Invoices',
          style: Theme.of(context)
              .textTheme
              .titleLarge,
        ),
        const SizedBox(height: 12),

        if (_invoices.isEmpty)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(
              child: Text(
                'No invoices yet.',
              ),
            ),
          )
        else
          ..._invoices.map(
            (invoice) {
              final invoiceId =
                  invoice['id'] as int;

              final createdAt =
                  invoice['created_at'] as String;

              final updatedAt =
                  invoice['updated_at'] as String;

              final subtotal =
                  (invoice['subtotal'] as num?)
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
                        CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),

                      Text(
                        'Created: '
                        '${_formatDate(
                          DateTime.parse(
                            createdAt,
                          ),
                        )}',
                      ),

                      Text(
                        'Updated: '
                        '${_formatDate(
                          DateTime.parse(
                            updatedAt,
                          ),
                        )}',
                      ),

                      const SizedBox(height: 6),

                      Text(
                        'Subtotal: '
                        '${_formatMoney(subtotal)}',
                      ),

                      if (couponDiscount > 0)
                        Text(
                          'Coupon discount: '
                          '${_formatMoney(
                            couponDiscount,
                          )}',
                        ),

                      Text(
                        'Total: '
                        '${_formatMoney(total)}',
                        style:
                            const TextStyle(
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

                    await _loadData();
                  },
                  trailing:
                      PopupMenuButton<String>(
                    onSelected: (value) {
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
                        child: Text('Delete'),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.customer.name,
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: ListView(
          padding: const EdgeInsets.all(16),
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

            const SizedBox(height: 20),

            _buildFinancialSummary(),

            const SizedBox(height: 16),

            _buildPaymentsSection(),

            const SizedBox(height: 20),

            _buildInvoicesSection(),

            const SizedBox(height: 100),
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