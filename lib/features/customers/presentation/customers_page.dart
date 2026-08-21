import 'package:flutter/material.dart';

import '../data/local_customer_repository.dart';
import '../domain/customer.dart';

import 'customer_details_page.dart';
class CustomersPage extends StatefulWidget {
  const CustomersPage({super.key});

  @override
  State<CustomersPage> createState() => _CustomersPageState();
}

class _CustomersPageState extends State<CustomersPage> {
  final _repository = LocalCustomerRepository();

  List<Customer> _customers = [];

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    final customers = await _repository.getCustomers();

    if (!mounted) return;

    setState(() {
      _customers = customers;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
      ),
      body: ListView.builder(
        itemCount: _customers.length,
        itemBuilder: (context, index) {
          final customer = _customers[index];

          return ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.person),
            ),
            title: Text(customer.name),
            subtitle: Text(customer.phone),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CustomerDetailsPage(
                    customer: customer,
                  ),
                ),
              );
        },
    );
        },
      ),
    );
  }
}