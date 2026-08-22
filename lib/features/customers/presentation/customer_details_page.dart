import 'package:flutter/material.dart';

import '../../payment/data/local_payment_repository.dart';
import '../../payment/domain/payment.dart';
import '../../payment/domain/payment_status.dart';
import '../../sales/data/local_sale_repository.dart';
import '../../sales/presentation/invoice_details_page.dart';
import '../../sales/presentation/invoice_editor_page.dart';
import '../domain/customer.dart';
import '../domain/payment_method.dart';

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

  bool _isLoading = true;
  String? _errorMessage;

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
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final results = await Future.wait([
        _saleRepository.getCustomerInvoices(
          widget.customer.id,
        ),
        _paymentRepository.getPaymentsForCustomer(
          widget.customer.id,
        ),
      ]);

      final invoices =
          results[0] as List<Map<String, Object?>>;

      final payments =
          results[1] as List<Payment>;

      _calculateInvoiceTotals(invoices);
      _calculatePaymentTotals(payments);

      if (!mounted) {
        return;
      }

      setState(() {
        _invoices = invoices;
        _payments = payments;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Failed to load customer data.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load customer data: $error',
          ),
        ),
      );
    }
  }

  void _calculateInvoiceTotals(
    List<Map<String, Object?>> invoices,
  ) {
    double subtotal = 0;
    double couponDiscount = 0;
    double total = 0;

    for (final invoice in invoices) {
      subtotal +=
          (invoice['subtotal'] as num?)?.toDouble() ?? 0;

      couponDiscount +=
          (invoice['coupon_discount'] as num?)
                  ?.toDouble() ??
              0;

      total +=
          (invoice['total'] as num?)?.toDouble() ?? 0;
    }

    _subtotal = subtotal;
    _couponDiscount = couponDiscount;
    _total = total;
  }

  void _calculatePaymentTotals(
    List<Payment> payments,
  ) {
    double paid = 0;
    double cashPaid = 0;
    double transferPaid = 0;
    double pendingTransfers = 0;

    for (final payment in payments) {
      if (payment.status == PaymentStatus.paid) {
        paid += payment.amount;

        if (payment.method == PaymentMethod.cash) {
          cashPaid += payment.amount;
        } else if (
            payment.method == PaymentMethod.transfer) {
          transferPaid += payment.amount;
        }
      } else if (
          payment.method == PaymentMethod.transfer &&
          payment.status == PaymentStatus.pending) {
        pendingTransfers += payment.amount;
      }
    }

    _paid = paid;
    _cashPaid = cashPaid;
    _transferPaid = transferPaid;
    _pendingTransfers = pendingTransfers;

    _recalculateBalance();
  }

  void _recalculateBalance() {
    final balance =
        _total - _paid - _pendingTransfers;

    _balance = balance > 0 ? balance : 0;
  }

  Future<void> _createInvoice() async {
    final saved =
        await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => InvoiceEditorPage(
          customer: widget.customer,
        ),
      ),
    );

    if (saved == true && mounted) {
      await _loadData();
    }
  }

  Future<void> _editInvoice(
    int invoiceId,
  ) async {
    final saved =
        await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => InvoiceEditorPage(
          customer: widget.customer,
          invoiceId: invoiceId,
        ),
      ),
    );

    if (saved == true && mounted) {
      await _loadData();
    }
  }

  Future<void> _deleteInvoice(
    int invoiceId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Delete invoice?',
          ),
          content: Text(
            'Invoice #$invoiceId will be deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _saleRepository.deleteInvoice(
        invoiceId,
      );

      if (!mounted) {
        return;
      }

      await _loadData();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to delete invoice: $error',
          ),
        ),
      );
    }
  }

  Future<void> _confirmTransfer(
    Payment payment,
  ) async {
    try {
      await _paymentRepository.confirmTransfer(
        payment.id,
      );

      if (!mounted) {
        return;
      }

      await _loadData();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to confirm transfer: $error',
          ),
        ),
      );
    }
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
    final textStyle = TextStyle(
      fontWeight:
          bold ? FontWeight.bold : FontWeight.normal,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 5,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: textStyle,
            ),
          ),
          Text(
            _formatMoney(value),
            style: textStyle,
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
              style:
                  Theme.of(context).textTheme.titleLarge,
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Payments',
              style:
                  Theme.of(context).textTheme.titleLarge,
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

    final isCash =
        payment.method == PaymentMethod.cash;

    final method =
        isCash ? 'Cash' : 'Transfer';

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
                  isCash
                      ? Icons.payments
                      : Icons.account_balance,
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: Text(
                    method,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                Text(
                  _formatMoney(payment.amount),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
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
                'Reference: ${payment.reference}',
              ),

            if (isPending) ...[
              const SizedBox(height: 8),

              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _confirmTransfer(payment),
                  icon: const Icon(Icons.check),
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
          style:
              Theme.of(context).textTheme.titleLarge,
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
            _buildInvoiceTile,
          ),
      ],
    );
  }

  Widget _buildInvoiceTile(
    Map<String, Object?> invoice,
  ) {
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
        (invoice['coupon_discount'] as num?)
                ?.toDouble() ??
            0;

    final total =
        (invoice['total'] as num?)
                ?.toDouble() ??
            (subtotal - couponDiscount);

    return Card(
      margin: const EdgeInsets.only(
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
                DateTime.parse(createdAt),
              )}',
            ),

            Text(
              'Updated: '
              '${_formatDate(
                DateTime.parse(updatedAt),
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
                '${_formatMoney(couponDiscount)}',
              ),

            Text(
              'Total: ${_formatMoney(total)}',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => InvoiceDetailsPage(
                customer: widget.customer,
                invoiceId: invoiceId,
              ),
            ),
          );

          if (mounted) {
            await _loadData();
          }
        },

        trailing: PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _editInvoice(invoiceId);
            } else if (value == 'delete') {
              _deleteInvoice(invoiceId);
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
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
            ),

            const SizedBox(height: 12),

            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 16),

            FilledButton(
              onPressed: _loadData,
              child: const Text(
                'Retry',
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(widget.customer.name),
        ),
        body: _buildErrorState(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customer.name),
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
          label: const Text(
            'New Invoice',
          ),
        ),
      ),
    );
  }
}