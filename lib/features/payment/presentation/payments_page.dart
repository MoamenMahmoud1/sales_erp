import 'package:flutter/material.dart';

import '../../../core/presentation/payment_time_picker.dart';
import '../data/local_payment_repository.dart';
import '../data/payment_date_actions.dart';
import '../domain/payment.dart';
import '../domain/payment_status.dart';
import '../../customers/domain/payment_method.dart';

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({super.key});

  @override
  State<PaymentsPage> createState() => _PaymentsPageState();
}

class _PaymentsPageState extends State<PaymentsPage> {
  final _repository = LocalPaymentRepository();
  final _searchController = TextEditingController();

  List<Payment> _allPayments = const [];
  List<Payment> _payments = const [];
  bool _isLoading = true;
  String? _errorMessage;
  PaymentStatus? _statusFilter;
  PaymentMethod? _methodFilter;
  int? _editingPaymentId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterPayments);
    _loadPayments();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_filterPayments)
      ..dispose();
    super.dispose();
  }

  Future<void> _loadPayments() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final payments = await _repository.getPayments();
      if (!mounted) return;
      setState(() {
        _allPayments = payments;
        _payments = _applyFilters(payments);
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load payments.';
      });
    }
  }

  List<Payment> _applyFilters(List<Payment> source) {
    final query = _searchController.text.trim().toLowerCase();
    return source.where((payment) {
      if (_statusFilter != null && payment.status != _statusFilter) return false;
      if (_methodFilter != null && payment.method != _methodFilter) return false;
      if (query.isEmpty) return true;

      return payment.id.toString().contains(query) ||
          payment.invoiceId.toString().contains(query) ||
          payment.customerId.toString().contains(query) ||
          (payment.reference?.toLowerCase().contains(query) ?? false);
    }).toList(growable: false);
  }

  void _filterPayments() {
    if (!mounted) return;
    setState(() => _payments = _applyFilters(_allPayments));
  }

  Future<void> _editPaymentDate(Payment payment) async {
    final selected = await pickPaymentDateTime(
      context,
      initial: payment.effectivePaymentAt,
    );
    if (selected == null || !mounted) return;

    setState(() => _editingPaymentId = payment.id);
    try {
      await _repository.setPaymentDate(payment.id, selected);
      final updated = await _repository.getPayments();
      if (!mounted) return;
      setState(() {
        _allPayments = updated;
        _payments = _applyFilters(updated);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment date updated.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update payment date: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _editingPaymentId = null);
    }
  }

  Future<void> _confirmTransfer(Payment payment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm transfer?'),
        content: Text('Mark payment #${payment.id} as paid?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _repository.confirmTransfer(payment.id);
      await _loadPayments();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Transfer confirmed.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to confirm transfer: $error')),
        );
      }
    }
  }

  String _formatMoney(double value) => '${value.toStringAsFixed(2)} EGP';

  String _formatDate(DateTime value) => formatPaymentDateTime(value);

  String _methodName(PaymentMethod method) =>
      method == PaymentMethod.cash ? 'Cash' : 'Transfer';

  Widget _statusChip(Payment payment) {
    final paid = payment.isPaid;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: paid ? scheme.primaryContainer : scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            paid ? Icons.check_circle_rounded : Icons.schedule_rounded,
            size: 15,
            color: paid ? scheme.onPrimaryContainer : scheme.onTertiaryContainer,
          ),
          const SizedBox(width: 5),
          Text(
            paid ? 'Paid' : 'Pending',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: paid ? scheme.onPrimaryContainer : scheme.onTertiaryContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentCard(Payment payment) {
    final scheme = Theme.of(context).colorScheme;
    final editing = _editingPaymentId == payment.id;
    final isCash = payment.method == PaymentMethod.cash;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: scheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    isCash
                        ? Icons.payments_rounded
                        : Icons.account_balance_rounded,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _methodName(payment.method),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Payment #${payment.id}',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                _statusChip(payment),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_available_rounded, color: scheme.primary),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Payment date',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _formatDate(payment.effectivePaymentAt),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Edit payment date',
                    onPressed: editing ? null : () => _editPaymentDate(payment),
                    icon: editing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.edit_calendar_rounded),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 11),
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 430;
                final info = [
                  _infoTile(Icons.receipt_long_rounded, 'Invoice', '#${payment.invoiceId}'),
                  _infoTile(Icons.person_outline_rounded, 'Customer', '#${payment.customerId}'),
                  _infoTile(Icons.account_balance_wallet_rounded, 'Amount', _formatMoney(payment.amount)),
                ];
                if (narrow) {
                  return Column(
                    children: [
                      for (var i = 0; i < info.length; i++) ...[
                        info[i],
                        if (i != info.length - 1) const SizedBox(height: 7),
                      ],
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: info[0]),
                    const SizedBox(width: 7),
                    Expanded(child: info[1]),
                    const SizedBox(width: 7),
                    Expanded(child: info[2]),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.save_outlined, size: 15, color: scheme.onSurfaceVariant),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Recorded: ${_formatDate(payment.createdAt)}',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            if (payment.reference?.isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.tag_rounded, size: 15, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Reference: ${payment.reference}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
            if (payment.confirmedAt != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  Icon(Icons.verified_rounded, size: 15, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      'Confirmed: ${_formatDate(payment.confirmedAt!)}',
                      style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],
            if (payment.isPending && payment.method == PaymentMethod.transfer) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _confirmTransfer(payment),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Confirm transfer'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoTile(IconData icon, String label, String value) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 9),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: scheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 9.5, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 1),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _filterChip('All', _statusFilter == null && _methodFilter == null, () {
            setState(() {
              _statusFilter = null;
              _methodFilter = null;
              _payments = _applyFilters(_allPayments);
            });
          }),
          const SizedBox(width: 8),
          _filterChip('Paid', _statusFilter == PaymentStatus.paid, () {
            setState(() {
              _statusFilter = _statusFilter == PaymentStatus.paid ? null : PaymentStatus.paid;
              _payments = _applyFilters(_allPayments);
            });
          }),
          const SizedBox(width: 8),
          _filterChip('Pending', _statusFilter == PaymentStatus.pending, () {
            setState(() {
              _statusFilter = _statusFilter == PaymentStatus.pending ? null : PaymentStatus.pending;
              _payments = _applyFilters(_allPayments);
            });
          }),
          const SizedBox(width: 8),
          _filterChip('Cash', _methodFilter == PaymentMethod.cash, () {
            setState(() {
              _methodFilter = _methodFilter == PaymentMethod.cash ? null : PaymentMethod.cash;
              _payments = _applyFilters(_allPayments);
            });
          }),
          const SizedBox(width: 8),
          _filterChip('Transfer', _methodFilter == PaymentMethod.transfer, () {
            setState(() {
              _methodFilter = _methodFilter == PaymentMethod.transfer ? null : PaymentMethod.transfer;
              _payments = _applyFilters(_allPayments);
            });
          }),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payments')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search payment, invoice, or reference...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: _searchController.clear,
                        icon: const Icon(Icons.clear_rounded),
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildFilters(),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 48),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _loadPayments, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_payments.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadPayments,
        child: ListView(
          padding: const EdgeInsets.only(top: 120),
          children: [
            Icon(
              Icons.payments_outlined,
              size: 64,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                _searchController.text.trim().isEmpty &&
                        _statusFilter == null &&
                        _methodFilter == null
                    ? 'No payments yet.'
                    : 'No payments found.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadPayments,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _payments.length,
        itemBuilder: (context, index) => _paymentCard(_payments[index]),
      ),
    );
  }
}
