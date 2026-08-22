import 'package:flutter/material.dart';

import '../data/local_payment_repository.dart';
import '../domain/payment.dart';
import '../domain/payment_status.dart';
import '../../customers/domain/payment_method.dart';

class PaymentsPage extends StatefulWidget {
  const PaymentsPage({
    super.key,
  });

  @override
  State<PaymentsPage> createState() =>
      _PaymentsPageState();
}

class _PaymentsPageState
    extends State<PaymentsPage> {
  final _repository =
      LocalPaymentRepository();

  final _searchController =
      TextEditingController();

  List<Payment> _allPayments = [];
  List<Payment> _payments = [];

  bool _isLoading = true;
  String? _errorMessage;

  PaymentStatus?
      _statusFilter;

  PaymentMethod?
      _methodFilter;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(
      _filterPayments,
    );

    _loadPayments();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(
        _filterPayments,
      )
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
      final payments =
          await _repository
              .getPayments();

      if (!mounted) {
        return;
      }

      setState(() {
        _allPayments = payments;
        _payments = payments;
        _isLoading = false;
      });

      _filterPayments();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Failed to load payments.';
      });
    }
  }

  void _filterPayments() {
    final query =
        _searchController.text
            .trim()
            .toLowerCase();

    final filtered =
        _allPayments.where((payment) {
      if (_statusFilter !=
              null &&
          payment.status !=
              _statusFilter) {
        return false;
      }

      if (_methodFilter !=
              null &&
          payment.method !=
              _methodFilter) {
        return false;
      }

      if (query.isEmpty) {
        return true;
      }

      final id =
          payment.id.toString();

      final invoiceId =
          payment.invoiceId
              .toString();

      final customerId =
          payment.customerId
              .toString();

      final reference =
          payment.reference
                  ?.toLowerCase() ??
              '';

      return id.contains(query) ||
          invoiceId.contains(query) ||
          customerId.contains(query) ||
          reference.contains(query);
    }).toList();

    if (!mounted) {
      return;
    }

    setState(() {
      _payments = filtered;
    });
  }

  Future<void> _confirmTransfer(
    Payment payment,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Confirm transfer?',
          ),
          content: Text(
            'Mark payment #${payment.id} '
            'as paid?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context)
                    .pop(false);
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context)
                    .pop(true);
              },
              child: const Text(
                'Confirm',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _repository.confirmTransfer(
        payment.id,
      );

      if (!mounted) {
        return;
      }

      await _loadPayments();

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Transfer confirmed.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Failed to confirm transfer: $error',
          ),
        ),
      );
    }
  }

  String _formatMoney(
    double value,
  ) {
    return '${value.toStringAsFixed(2)} EGP';
  }

  String _formatDate(
    DateTime date,
  ) {
    final local =
        date.toLocal();

    final day =
        local.day
            .toString()
            .padLeft(2, '0');

    final month =
        local.month
            .toString()
            .padLeft(2, '0');

    final hour =
        local.hour
            .toString()
            .padLeft(2, '0');

    final minute =
        local.minute
            .toString()
            .padLeft(2, '0');

    return '$day/$month/${local.year} '
        '$hour:$minute';
  }

  String _methodName(
    PaymentMethod method,
  ) {
    return method ==
            PaymentMethod.cash
        ? 'Cash'
        : 'Transfer';
  }

  Widget _statusChip(
    Payment payment,
  ) {
    final isPaid =
        payment.status ==
            PaymentStatus.paid;

    return Chip(
      avatar: Icon(
        isPaid
            ? Icons.check_circle_outline
            : Icons.schedule_outlined,
        size: 18,
      ),
      label: Text(
        isPaid
            ? 'Paid'
            : 'Pending',
      ),
      visualDensity:
          VisualDensity.compact,
    );
  }

  Widget _paymentCard(
    Payment payment,
  ) {
    final isCash =
        payment.method ==
            PaymentMethod.cash;

    final isPending =
        payment.status ==
            PaymentStatus.pending;

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  child: Icon(
                    isCash
                        ? Icons.payments_outlined
                        : Icons.account_balance_outlined,
                  ),
                ),

                const SizedBox(
                  width: 12,
                ),

                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        _methodName(
                          payment.method,
                        ),
                        style:
                            const TextStyle(
                          fontWeight:
                              FontWeight.bold,
                        ),
                      ),

                      const SizedBox(
                        height: 3,
                      ),

                      Text(
                        'Payment #${payment.id}',
                      ),
                    ],
                  ),
                ),

                _statusChip(
                  payment,
                ),
              ],
            ),

            const SizedBox(
              height: 14,
            ),

            Row(
              children: [
                const Icon(
                  Icons.receipt_long_outlined,
                  size: 18,
                ),
                const SizedBox(
                  width: 6,
                ),
                Text(
                  'Invoice #${payment.invoiceId}',
                ),
                const Spacer(),
                Text(
                  _formatMoney(
                    payment.amount,
                  ),
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 8,
            ),

            Text(
              'Customer #${payment.customerId}',
            ),

            const SizedBox(
              height: 4,
            ),

            Text(
              'Date: '
              '${_formatDate(payment.createdAt)}',
            ),

            if (payment.reference !=
                    null &&
                payment
                    .reference!
                    .isNotEmpty) ...[
              const SizedBox(
                height: 4,
              ),
              Text(
                'Reference: '
                '${payment.reference}',
              ),
            ],

            if (payment.confirmedAt !=
                null) ...[
              const SizedBox(
                height: 4,
              ),
              Text(
                'Confirmed: '
                '${_formatDate(
                  payment.confirmedAt!,
                )}',
              ),
            ],

            if (isPending &&
                payment.method ==
                    PaymentMethod
                        .transfer) ...[
              const SizedBox(
                height: 12,
              ),
              SizedBox(
                width: double.infinity,
                child:
                    FilledButton.icon(
                  onPressed:
                      () =>
                          _confirmTransfer(
                    payment,
                  ),
                  icon:
                      const Icon(
                    Icons.check,
                  ),
                  label:
                      const Text(
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

  Widget _buildFilters() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection:
            Axis.horizontal,
        children: [
          FilterChip(
            label:
                const Text('All'),
            selected:
                _statusFilter ==
                    null &&
                _methodFilter ==
                    null,
            onSelected: (_) {
              setState(() {
                _statusFilter = null;
                _methodFilter = null;
              });

              _filterPayments();
            },
          ),

          const SizedBox(
            width: 8,
          ),

          FilterChip(
            label:
                const Text('Paid'),
            selected:
                _statusFilter ==
                    PaymentStatus
                        .paid,
            onSelected: (_) {
              setState(() {
                _statusFilter =
                    _statusFilter ==
                            PaymentStatus.paid
                        ? null
                        : PaymentStatus.paid;
              });

              _filterPayments();
            },
          ),

          const SizedBox(
            width: 8,
          ),

          FilterChip(
            label:
                const Text('Pending'),
            selected:
                _statusFilter ==
                    PaymentStatus
                        .pending,
            onSelected: (_) {
              setState(() {
                _statusFilter =
                    _statusFilter ==
                            PaymentStatus.pending
                        ? null
                        : PaymentStatus.pending;
              });

              _filterPayments();
            },
          ),

          const SizedBox(
            width: 8,
          ),

          FilterChip(
            label:
                const Text('Cash'),
            selected:
                _methodFilter ==
                    PaymentMethod.cash,
            onSelected: (_) {
              setState(() {
                _methodFilter =
                    _methodFilter ==
                            PaymentMethod.cash
                        ? null
                        : PaymentMethod.cash;
              });

              _filterPayments();
            },
          ),

          const SizedBox(
            width: 8,
          ),

          FilterChip(
            label:
                const Text('Transfer'),
            selected:
                _methodFilter ==
                    PaymentMethod.transfer,
            onSelected: (_) {
              setState(() {
                _methodFilter =
                    _methodFilter ==
                            PaymentMethod.transfer
                        ? null
                        : PaymentMethod.transfer;
              });

              _filterPayments();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
              ),
              const SizedBox(
                height: 12,
              ),
              Text(
                _errorMessage!,
                textAlign:
                    TextAlign.center,
              ),
              const SizedBox(
                height: 16,
              ),
              FilledButton(
                onPressed:
                    _loadPayments,
                child:
                    const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_payments.isEmpty) {
      return RefreshIndicator(
        onRefresh:
            _loadPayments,
        child: ListView(
          padding:
              const EdgeInsets.only(
            top: 120,
          ),
          children: [
            Icon(
              Icons.payments_outlined,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .outline,
            ),
            const SizedBox(
              height: 16,
            ),
            Center(
              child: Text(
                _searchController.text
                            .trim()
                            .isEmpty &&
                        _statusFilter ==
                            null &&
                        _methodFilter ==
                            null
                    ? 'No payments yet.'
                    : 'No payments found.',
                style:
                    Theme.of(context)
                        .textTheme
                        .titleMedium,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh:
          _loadPayments,
      child: ListView.builder(
        padding:
            const EdgeInsets.fromLTRB(
          16,
          12,
          16,
          100,
        ),
        itemCount:
            _payments.length,
        itemBuilder:
            (context, index) {
          return _paymentCard(
            _payments[index],
          );
        },
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Payments'),
      ),
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              8,
            ),
            child: TextField(
              controller:
                  _searchController,
              decoration:
                  InputDecoration(
                hintText:
                    'Search payment, invoice, or reference...',
                prefixIcon:
                    const Icon(
                  Icons.search,
                ),
                suffixIcon:
                    _searchController
                            .text
                            .isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController
                                  .clear();
                            },
                            icon:
                                const Icon(
                              Icons.clear,
                            ),
                          ),
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                ),
              ),
            ),
          ),

          Padding(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 16,
            ),
            child:
                _buildFilters(),
          ),

          Expanded(
            child:
                _buildBody(),
          ),
        ],
      ),
    );
  }
}

