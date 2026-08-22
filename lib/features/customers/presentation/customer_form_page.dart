import 'package:flutter/material.dart';

import '../data/local_customer_repository.dart';
import '../domain/customer.dart';

class CustomerFormPage extends StatefulWidget {
  final Customer? customer;

  const CustomerFormPage({
    super.key,
    this.customer,
  });

  bool get isEditing => customer != null;

  @override
  State<CustomerFormPage> createState() =>
      _CustomerFormPageState();
}

class _CustomerFormPageState
    extends State<CustomerFormPage> {
  final _formKey = GlobalKey<FormState>();

  final _repository = LocalCustomerRepository();

  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;

  CustomerPaymentType _paymentType =
      CustomerPaymentType.cash;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final customer = widget.customer;

    _nameController = TextEditingController(
      text: customer?.name ?? '',
    );

    _phoneController = TextEditingController(
      text: customer?.phone ?? '',
    );

    _addressController = TextEditingController(
      text: customer?.address ?? '',
    );

    _paymentType =
        customer?.paymentType ??
        CustomerPaymentType.cash;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null ||
        value.trim().isEmpty) {
      return 'Name is required.';
    }

    return null;
  }

  String? _validatePhone(String? value) {
    if (value == null ||
        value.trim().isEmpty) {
      return 'Phone is required.';
    }

    if (value.trim().length < 8) {
      return 'Enter a valid phone number.';
    }

    return null;
  }

  String? _validateAddress(String? value) {
    if (value == null ||
        value.trim().isEmpty) {
      return 'Address is required.';
    }

    return null;
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final customer = Customer(
      id: widget.customer?.id ?? 0,
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      paymentType: _paymentType,
    );

    try {
      if (widget.isEditing) {
        await _repository.updateCustomer(
          customer,
        );
      } else {
        await _repository.createCustomer(
          customer,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to save customer: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing
              ? 'Edit Customer'
              : 'New Customer',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              textCapitalization:
                  TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Customer name',
                prefixIcon: Icon(
                  Icons.person_outline,
                ),
                border: OutlineInputBorder(),
              ),
              validator: _validateName,
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone',
                prefixIcon: Icon(
                  Icons.phone_outlined,
                ),
                border: OutlineInputBorder(),
              ),
              validator: _validatePhone,
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _addressController,
              textCapitalization:
                  TextCapitalization.sentences,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Address',
                prefixIcon: Icon(
                  Icons.location_on_outlined,
                ),
                border: OutlineInputBorder(),
              ),
              validator: _validateAddress,
            ),

            const SizedBox(height: 24),

            Text(
              'Payment method',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),

            const SizedBox(height: 8),

            DropdownButtonFormField<CustomerPaymentType>(
                initialValue: _paymentType,
                decoration: const InputDecoration(
                  labelText: 'Payment method',
                  prefixIcon: Icon(
                    Icons.payment_outlined,
                  ),
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: CustomerPaymentType.cash,
                    child: Text('Cash'),
                  ),
                  DropdownMenuItem(
                    value: CustomerPaymentType.bankTransfer,
                    child: Text('Bank Transfer'),
                  ),
                ],
                onChanged: _isSaving
                    ? null
                    : (value) {
                        if (value == null) {
                          return;
                        }
              
                        setState(() {
                          _paymentType = value;
                        });
                      },
              ),
            const SizedBox(height: 32),

            SizedBox(
              height: 52,
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _isSaving
                      ? 'Saving...'
                      : widget.isEditing
                          ? 'Save Changes'
                          : 'Create Customer',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

