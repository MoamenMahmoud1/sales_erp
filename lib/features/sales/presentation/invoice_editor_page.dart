import 'package:flutter/material.dart';

import '../../../core/presentation/payment_time_picker.dart';
import '../../customers/domain/customer.dart';
import '../../customers/domain/payment_method.dart';
import '../../payment/data/local_payment_repository.dart';
import '../../payment/data/payment_date_actions.dart';
import '../../payment/domain/payment.dart';
import '../../products/data/local_product_repository.dart';
import '../../products/domain/product.dart';
import '../data/local_sale_repository.dart';
import 'widgets/quantity_stepper.dart';

class InvoiceEditorPage extends StatefulWidget {
  final Customer customer;
  final int? invoiceId;

  const InvoiceEditorPage({
    super.key,
    required this.customer,
    this.invoiceId,
  });

  @override
  State<InvoiceEditorPage> createState() => _InvoiceEditorPageState();
}

class _InvoiceEditorPageState extends State<InvoiceEditorPage> {
  final _productRepository = LocalProductRepository();
  final _saleRepository = LocalSaleRepository();
  final _paymentRepository = LocalPaymentRepository();
  final _discountController = TextEditingController(text: '0');
  final _paymentController = TextEditingController(text: '0');
  final Map<int, int> _quantities = {};
  final Map<int, DateTime> _paymentDates = {};

  List<Product> _products = const [];
  List<Payment> _existingPayments = const [];
  bool _loading = true;
  bool _saving = false;
  double _existingPaid = 0;
  double _existingPending = 0;
  String? _error;

  bool get editing => widget.invoiceId != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _discountController.dispose();
    _paymentController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final products = await _productRepository.getProducts();
      if (widget.invoiceId != null) {
        final invoice = await _saleRepository.getInvoiceWithItems(widget.invoiceId!);
        if (invoice == null) throw StateError('Invoice not found.');

        final rawItems = invoice['items'] as List? ?? const [];
        for (final raw in rawItems) {
          final item = Map<String, Object?>.from(raw as Map);
          final id = (item['product_id'] as num).toInt();
          final quantity = (item['quantity'] as num).toInt();
          if (quantity > 0) _quantities[id] = quantity;
        }

        _discountController.text =
            ((invoice['coupon_discount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2);
        _existingPaid = (invoice['paid_amount'] as num?)?.toDouble() ?? 0;
        _existingPending = (invoice['pending_amount'] as num?)?.toDouble() ?? 0;

        final payments = await _paymentRepository.getPaymentsForInvoice(widget.invoiceId!);
        _existingPayments = List.unmodifiable(payments);
        for (final payment in payments) {
          _paymentDates[payment.id] = payment.effectivePaymentAt;
        }
      }

      if (!mounted) return;
      setState(() {
        _products = products;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  void _setQuantity(int productId, int quantity) {
    setState(() {
      if (quantity <= 0) {
        _quantities.remove(productId);
      } else {
        _quantities[productId] = quantity;
      }
    });
  }

  double get _subtotal => _products.fold<double>(
        0,
        (total, product) => total + product.price * (_quantities[product.id] ?? 0),
      );

  double get _discount {
    final value = double.tryParse(_discountController.text) ?? 0;
    if (!value.isFinite || value <= 0) return 0;
    return value.clamp(0, _subtotal).toDouble();
  }

  double get _total => _subtotal - _discount;

  double get _paymentNow {
    final value = double.tryParse(_paymentController.text) ?? 0;
    if (!value.isFinite || value <= 0) return 0;
    return value;
  }

  double get _remainingBeforeNewPayment =>
      (_total - _existingPaid - _existingPending).clamp(0, _total).toDouble();

  double get _remainingAfterNewPayment =>
      (_remainingBeforeNewPayment - _paymentNow)
          .clamp(0, _remainingBeforeNewPayment)
          .toDouble();

  bool get _isTransfer =>
      widget.customer.paymentType == CustomerPaymentType.bankTransfer;

  void _fillFullPayment() {
    _paymentController.text = _remainingBeforeNewPayment.toStringAsFixed(2);
    setState(() {});
  }

  Future<void> _pickExistingPaymentDate(Payment payment) async {
    final selected = await pickPaymentDateTime(
      context,
      initial: _paymentDates[payment.id] ?? payment.effectivePaymentAt,
    );
    if (selected == null || !mounted) return;
    setState(() => _paymentDates[payment.id] = selected);
  }

  Future<void> _save() async {
    if (_quantities.isEmpty || _saving) return;
    if (_paymentNow > _remainingBeforeNewPayment) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment exceeds the remaining invoice balance.')),
      );
      return;
    }

    DateTime? newPaymentAt;
    if (_paymentNow > 0) {
      newPaymentAt = await resolvePaymentTime(context);
      if (newPaymentAt == null || !mounted) return;
    }

    setState(() => _saving = true);
    try {
      final method = _isTransfer ? PaymentMethod.transfer : PaymentMethod.cash;
      final products = Map.of(_quantities);
      late final int invoiceId;

      if (!editing) {
        invoiceId = await _saleRepository.createInvoice(
          customerId: widget.customer.id,
          products: products,
          paymentMethod: method,
          couponDiscount: _discount,
          initialPaymentAmount: _paymentNow,
        );
      } else {
        invoiceId = widget.invoiceId!;
        await _saleRepository.updateInvoice(
          invoiceId: invoiceId,
          customerId: widget.customer.id,
          products: products,
          paymentMethod: method,
          couponDiscount: _discount,
          additionalPaymentAmount: _paymentNow,
        );
      }

      if (editing) {
        for (final payment in _existingPayments) {
          final selected = _paymentDates[payment.id];
          if (selected == null) continue;
          if (selected.toUtc() != payment.effectivePaymentAt.toUtc()) {
            await _paymentRepository.setPaymentDate(payment.id, selected);
          }
        }
      }

      if (_paymentNow > 0 && newPaymentAt != null) {
        await _paymentRepository.setLatestPaymentDate(invoiceId, newPaymentAt);
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit Invoice' : 'New Invoice'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorState()
              : _body(),
      bottomNavigationBar: !_loading && _error == null ? _saveBar() : null,
    );
  }

  Widget _body() {
    final scheme = Theme.of(context).colorScheme;
    final remainingBeforePayment = _remainingBeforeNewPayment;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  child: Text(
                    widget.customer.name.trim().isEmpty
                        ? '?'
                        : widget.customer.name.trim()[0].toUpperCase(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.customer.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.customer.phone,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Products', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final product in _products)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${product.price.toStringAsFixed(2)} EGP / carton',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  QuantityStepper(
                    value: _quantities[product.id] ?? 0,
                    onChanged: (value) => _setQuantity(product.id, value),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 14),
        Text('Global discount', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _discountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Discount amount',
            suffixText: 'EGP',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Text(
          editingPaymentTitle,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _paymentController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: editingPaymentLabel,
            suffixText: 'EGP',
            border: const OutlineInputBorder(),
            helperText: _isTransfer
                ? 'Transfer payments stay pending until confirmed from Payments.'
                : 'Cash payments are recorded as paid immediately.',
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            onPressed: remainingBeforePayment <= 0 ? null : _fillFullPayment,
            icon: const Icon(Icons.done_all_rounded),
            label: Text(editing ? 'Pay remaining' : 'Pay full amount'),
          ),
        ),
        if (editing && _existingPayments.isNotEmpty) ...[
          const SizedBox(height: 6),
          _existingPaymentsCard(),
        ],
        if (editing) ...[
          const SizedBox(height: 4),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  _summaryRow('Already paid', _existingPaid),
                  if (_existingPending > 0)
                    _summaryRow('Pending transfer', _existingPending),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _summaryRow('Subtotal', _subtotal),
                if (_discount > 0) _summaryRow('Discount', -_discount),
                const Divider(height: 20),
                _summaryRow('Total', _total, emphasized: true),
                if (_paymentNow > 0)
                  _summaryRow(editing ? 'Payment now' : 'Paid now', _paymentNow),
                if (editing && _existingPending > 0)
                  _summaryRow('Pending already', _existingPending),
                const Divider(height: 20),
                _summaryRow(
                  'Remaining',
                  _remainingAfterNewPayment,
                  emphasized: true,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _existingPaymentsCard() {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.history_rounded, color: scheme.primary),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Payment details',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'You can update the payment date and time for any previous payment.',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            for (final payment in _existingPayments) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Row(
                  children: [
                    Icon(
                      payment.isCash
                          ? Icons.payments_rounded
                          : Icons.account_balance_rounded,
                      size: 19,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${payment.amount.toStringAsFixed(2)} EGP · ${payment.isPaid ? 'Paid' : 'Pending'}',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Payment date: ${formatPaymentDateTime(_paymentDates[payment.id] ?? payment.effectivePaymentAt)}',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _saving ? null : () => _pickExistingPaymentDate(payment),
                      icon: const Icon(Icons.edit_calendar_rounded, size: 17),
                      label: const Text('Edit date'),
                    ),
                  ],
                ),
              ),
              if (payment != _existingPayments.last) const SizedBox(height: 7),
            ],
          ],
        ),
      ),
    );
  }

  String get editingPaymentTitle =>
      editing ? 'Additional payment' : 'Payment at invoice creation';

  String get editingPaymentLabel =>
      editing ? 'Amount to pay now' : 'Amount paid now';

  Widget _summaryRow(String label, double amount, {bool emphasized = false}) {
    final style = TextStyle(
      fontSize: emphasized ? 17 : 14,
      fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
      color: emphasized ? Theme.of(context).colorScheme.primary : null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('${amount.toStringAsFixed(2)} EGP', style: style),
        ],
      ),
    );
  }

  Widget _saveBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: _saving || _quantities.isEmpty ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded),
          label: Text(_saving ? 'Saving...' : 'Save invoice'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
      ),
    );
  }

  Widget _errorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 46),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
}
