import 'package:flutter/material.dart';

import '../../customers/data/local_customer_repository.dart';
import '../../customers/domain/customer.dart';
import '../data/local_sale_repository.dart';
import 'invoice_details_page.dart';
import 'invoice_editor_page.dart';

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({
    super.key,
  });

  @override
  State<InvoicesPage> createState() =>
      _InvoicesPageState();
}

class _InvoicesPageState
    extends State<InvoicesPage> {
  final _saleRepository =
      LocalSaleRepository();

  final _customerRepository =
      LocalCustomerRepository();

  final _searchController =
      TextEditingController();

  List<Map<String, Object?>>
      _allInvoices = [];

  List<Map<String, Object?>>
      _invoices = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(
      _filterInvoices,
    );

    _loadInvoices();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_filterInvoices)
      ..dispose();

    super.dispose();
  }

  Future<void> _loadInvoices() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final invoices =
          await _saleRepository
              .getInvoices();

      if (!mounted) {
        return;
      }

      setState(() {
        _allInvoices = invoices;
        _invoices = invoices;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Failed to load invoices.';
      });
    }
  }

  void _filterInvoices() {
    final query =
        _searchController.text
            .trim()
            .toLowerCase();

    if (query.isEmpty) {
      setState(() {
        _invoices =
            List.from(_allInvoices);
      });

      return;
    }

    final filtered =
        _allInvoices.where((invoice) {
      final id =
          '${invoice['id'] ?? ''}';

      final customerName =
          '${invoice['customer_name'] ?? ''}'
              .toLowerCase();

      final customerPhone =
          '${invoice['customer_phone'] ?? ''}'
              .toLowerCase();

      return id.contains(query) ||
          customerName.contains(query) ||
          customerPhone.contains(query);
    }).toList();

    setState(() {
      _invoices = filtered;
    });
  }

  Future<void> _createInvoice() async {
    final customers =
        await _customerRepository
            .getCustomers();

    if (!mounted) {
      return;
    }

    if (customers.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Create a customer first.',
          ),
        ),
      );

      return;
    }

    final customer =
        await showDialog<Customer>(
      context: context,
      builder: (context) {
        return _CustomerPickerDialog(
          customers: customers,
        );
      },
    );

    if (customer == null ||
        !mounted) {
      return;
    }

    final saved =
        await Navigator.of(context)
            .push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            InvoiceEditorPage(
          customer: customer,
        ),
      ),
    );

    if (saved == true && mounted) {
      await _loadInvoices();
    }
  }

  Future<void> _editInvoice(
    int invoiceId,
    int customerId,
  ) async {
    final customer =
        await _customerRepository
            .getCustomerById(
      customerId,
    );

    if (customer == null ||
        !mounted) {
      return;
    }

    final saved =
        await Navigator.of(context)
            .push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            InvoiceEditorPage(
          customer: customer,
          invoiceId: invoiceId,
        ),
      ),
    );

    if (saved == true && mounted) {
      await _loadInvoices();
    }
  }

  Future<void> _openInvoice(
    Map<String, Object?> invoice,
  ) async {
    final invoiceId =
        invoice['id'] as int;

    final customerId =
        invoice['customer_id'] as int;

    final customer =
        await _customerRepository
            .getCustomerById(
      customerId,
    );

    if (customer == null ||
        !mounted) {
      return;
    }

    await Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) =>
            InvoiceDetailsPage(
          customer: customer,
          invoiceId: invoiceId,
        ),
      ),
    );

    if (mounted) {
      await _loadInvoices();
    }
  }

  Future<void> _deleteInvoice(
    int invoiceId,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Delete invoice?',
          ),
          content: Text(
            'Invoice #$invoiceId will be permanently deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context)
                      .pop(false),
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context)
                      .pop(true),
              child: const Text(
                'Delete',
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
      await _saleRepository
          .deleteInvoice(
        invoiceId,
      );

      if (!mounted) {
        return;
      }

      await _loadInvoices();

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Invoice deleted.',
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
            'Failed to delete invoice: $error',
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
    String value,
  ) {
    final date =
        DateTime.parse(value)
            .toLocal();

    final day =
        date.day
            .toString()
            .padLeft(2, '0');

    final month =
        date.month
            .toString()
            .padLeft(2, '0');

    final hour =
        date.hour
            .toString()
            .padLeft(2, '0');

    final minute =
        date.minute
            .toString()
            .padLeft(2, '0');

    return '$day/$month/${date.year} '
        '$hour:$minute';
  }

  Widget _buildStatusChip(
    String status,
  ) {
    final isPaid =
        status == 'paid';

    return Chip(
      label: Text(
        isPaid ? 'Paid' : 'Pending',
      ),
      avatar: Icon(
        isPaid
            ? Icons.check_circle_outline
            : Icons.schedule_outlined,
        size: 18,
      ),
      visualDensity:
          VisualDensity.compact,
    );
  }

  Widget _buildInvoiceCard(
    Map<String, Object?> invoice,
  ) {
    final invoiceId =
        invoice['id'] as int;

    final customerName =
        invoice['customer_name']
                as String? ??
            'Unknown customer';

    final customerPhone =
        invoice['customer_phone']
                as String? ??
            '';

    final total =
        (invoice['total'] as num?)
                ?.toDouble() ??
            0;

    final status =
        invoice['payment_status']
                as String? ??
            'paid';

    final createdAt =
        invoice['created_at']
                as String;

    final customerId =
        invoice['customer_id'] as int;

    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      clipBehavior:
          Clip.antiAlias,
      child: InkWell(
        onTap: () =>
            _openInvoice(invoice),
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
                    child:
                        const Icon(
                      Icons.receipt_long,
                    ),
                  ),

                  const SizedBox(
                    width: 12,
                  ),

                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,
                      children: [
                        Text(
                          'Invoice #$invoiceId',
                          style: const TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                        const SizedBox(
                          height: 3,
                        ),
                        Text(
                          customerName,
                        ),
                      ],
                    ),
                  ),

                  _buildStatusChip(
                    status,
                  ),

                  PopupMenuButton<
                      String>(
                    onSelected: (value) {
                      if (value ==
                          'edit') {
                        _editInvoice(
                          invoiceId,
                          customerId,
                        );
                      } else if (
                          value ==
                              'delete') {
                        _deleteInvoice(
                          invoiceId,
                        );
                      }
                    },
                    itemBuilder: (_) =>
                        const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text(
                          'Edit',
                        ),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text(
                          'Delete',
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(
                height: 14,
              ),

              Row(
                children: [
                  const Icon(
                    Icons.phone_outlined,
                    size: 18,
                  ),
                  const SizedBox(
                    width: 6,
                  ),
                  Expanded(
                    child:
                        Text(
                      customerPhone.isEmpty
                          ? 'No phone'
                          : customerPhone,
                    ),
                  ),
                  Text(
                    _formatMoney(
                      total,
                    ),
                    style:
                        const TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.bold,
                    ),
                  ),
                ],
              ),

              const SizedBox(
                height: 6,
              ),

              Text(
                'Created: '
                '${_formatDate(createdAt)}',
              ),
            ],
          ),
        ),
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
                    _loadInvoices,
                child:
                    const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_invoices.isEmpty) {
      return RefreshIndicator(
        onRefresh:
            _loadInvoices,
        child: ListView(
          padding:
              const EdgeInsets.only(
            top: 120,
          ),
          children: [
            Icon(
              Icons.receipt_long_outlined,
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
                        .isEmpty
                    ? 'No invoices yet.'
                    : 'No invoices found.',
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
          _loadInvoices,
      child: ListView.builder(
        padding:
            const EdgeInsets.fromLTRB(
          16,
          12,
          16,
          100,
        ),
        itemCount:
            _invoices.length,
        itemBuilder:
            (context, index) {
          return _buildInvoiceCard(
            _invoices[index],
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
            const Text('Invoices'),
      ),
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              4,
            ),
            child: TextField(
              controller:
                  _searchController,
              decoration:
                  InputDecoration(
                hintText:
                    'Search invoice or customer...',
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
          Expanded(
            child:
                _buildBody(),
          ),
        ],
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed:
            _createInvoice,
        icon: const Icon(
          Icons.add_shopping_cart,
        ),
        label:
            const Text('Invoice'),
      ),
    );
  }
}

class _CustomerPickerDialog
    extends StatefulWidget {
  final List<Customer> customers;

  const _CustomerPickerDialog({
    required this.customers,
  });

  @override
  State<_CustomerPickerDialog>
      createState() =>
          _CustomerPickerDialogState();
}

class _CustomerPickerDialogState
    extends State<
        _CustomerPickerDialog> {
  final _searchController =
      TextEditingController();

  late List<Customer>
      _customers;

  @override
  void initState() {
    super.initState();

    _customers =
        List.from(
      widget.customers,
    );

    _searchController.addListener(
      _filter,
    );
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_filter)
      ..dispose();

    super.dispose();
  }

  void _filter() {
    final query =
        _searchController.text
            .trim()
            .toLowerCase();

    setState(() {
      if (query.isEmpty) {
        _customers =
            List.from(
          widget.customers,
        );
      } else {
        _customers =
            widget.customers
                .where(
                  (customer) =>
                      customer.name
                          .toLowerCase()
                          .contains(query) ||
                      customer.phone
                          .toLowerCase()
                          .contains(query),
                )
                .toList();
      }
    });
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return AlertDialog(
      title:
          const Text('Select Customer'),
      content: SizedBox(
        width: double.maxFinite,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller:
                  _searchController,
              decoration:
                  const InputDecoration(
                hintText:
                    'Search customer...',
                prefixIcon:
                    Icon(Icons.search),
              ),
            ),

            const SizedBox(
              height: 12,
            ),

            Expanded(
              child: _customers.isEmpty
                  ? const Center(
                      child: Text(
                        'No customer found.',
                      ),
                    )
                  : ListView.builder(
                      itemCount:
                          _customers.length,
                      itemBuilder:
                          (context, index) {
                        final customer =
                            _customers[
                                index];

                        return ListTile(
                          leading:
                              const CircleAvatar(
                            child: Icon(
                              Icons.person,
                            ),
                          ),
                          title: Text(
                            customer.name,
                          ),
                          subtitle:
                              Text(
                            customer.phone,
                          ),
                          onTap: () {
                            Navigator.of(
                              context,
                            ).pop(
                              customer,
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

