import 'package:flutter/material.dart';

import '../data/local_customer_repository.dart';
import '../domain/customer.dart';
import '../domain/customer_repository.dart';
import 'customer_details_page.dart';
import 'customer_form_page.dart';

class CustomersPage extends StatefulWidget {
  final CustomerRepository? repository;

  const CustomersPage({
    super.key,
    this.repository,
  });

  @override
  State<CustomersPage> createState() =>
      _CustomersPageState();
}

class _CustomersPageState
    extends State<CustomersPage> {
  final _repository =
      LocalCustomerRepository();

    CustomerRepository get _dataSource =>
      widget.repository ?? _repository;

  final _searchController =
      TextEditingController();

  List<Customer> _customers = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _loadCustomers();

    _searchController.addListener(
      _searchCustomers,
    );
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_searchCustomers)
      ..dispose();

    super.dispose();
  }

  Future<void> _loadCustomers() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final customers =
          await _dataSource.getCustomers();

      if (!mounted) {
        return;
      }

      setState(() {
        _customers = customers;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Failed to load customers.';
      });
    }
  }

  Future<void> _searchCustomers() async {
    try {
      final customers =
          await _dataSource.searchCustomers(
        _searchController.text,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _customers = customers;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage =
            'Failed to search customers.';
      });
    }
  }

  Future<void> _openCustomerForm({
    Customer? customer,
  }) async {
    final saved =
        await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CustomerFormPage(
          customer: customer,
        ),
      ),
    );

    if (saved == true && mounted) {
      await _loadCustomers();
    }
  }

  Future<void> _openCustomer(
    Customer customer,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CustomerDetailsPage(
          customer: customer,
        ),
      ),
    );

    if (mounted) {
      await _loadCustomers();
    }
  }

  Future<void> _deleteCustomer(
    Customer customer,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Delete customer?',
          ),
          content: Text(
            'Delete ${customer.name}?',
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
      await _dataSource.deleteCustomer(
        customer.id,
      );

      if (!mounted) {
        return;
      }

      await _loadCustomers();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Customer deleted.',
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
            'Failed to delete customer: $error',
          ),
        ),
      );
    }
  }

  Widget _buildCustomerCard(
    Customer customer,
  ) {
    final initial = customer.name
        .trim()
        .isEmpty
        ? '?'
        : customer.name
            .trim()[0]
            .toUpperCase();

    return Card(
      margin: const EdgeInsets.only(
        bottom: 12,
      ),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        leading: CircleAvatar(
          child: Text(initial),
        ),
        title: Text(
          customer.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(customer.phone),
            const SizedBox(height: 2),
            Text(
              customer.paymentTypeName,
            ),
          ],
        ),
        trailing:
            PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _openCustomerForm(
                customer: customer,
              );
            } else if (value == 'delete') {
              _deleteCustomer(
                customer,
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
        onTap: () =>
            _openCustomer(customer),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign:
                    TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed:
                    _loadCustomers,
                child: const Text(
                  'Retry',
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_customers.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadCustomers,
        child: ListView(
          children: [
            const SizedBox(height: 160),
            Icon(
              Icons.people_outline,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .outline,
            ),
            const SizedBox(height: 16),
            Center(
              child: Text(
                _searchController.text
                        .trim()
                        .isEmpty
                    ? 'No customers yet.'
                    : 'No customers found.',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCustomers,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          16,
          12,
          16,
          100,
        ),
        itemCount: _customers.length,
        itemBuilder: (context, index) {
          return _buildCustomerCard(
            _customers[index],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Customers',
        ),
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
                    'Search by name or phone',
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
            child: _buildBody(),
          ),
        ],
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed:
            _openCustomerForm,
        icon:
            const Icon(Icons.person_add),
        label:
            const Text('Customer'),
      ),
    );
  }
}

