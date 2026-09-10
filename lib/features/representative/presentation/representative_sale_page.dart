import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/quantity_stepper.dart';
import '../../../core/ui/section_header.dart';
import '../../../customers/domain/payment_method.dart';
import '../domain/entities/vehicle_stock_item.dart';
import 'representative_sale_controller.dart';

class RepresentativeSalePage extends StatefulWidget {
  final List<VehicleStockItem> vehicleStock;
  final RepresentativeSaleController controller;

  const RepresentativeSalePage({
    super.key,
    required this.vehicleStock,
    required this.controller,
  });

  @override
  State<RepresentativeSalePage> createState() => _RepresentativeSalePageState();
}

class _RepresentativeSalePageState extends State<RepresentativeSalePage> {
  final _paymentAmountController = TextEditingController(text: '0');

  @override
  void initState() {
    super.initState();
    widget.controller.load(vehicleStock: widget.vehicleStock);
  }

  @override
  void dispose() {
    _paymentAmountController.dispose();
    super.dispose();
  }

  void _setPaymentAmount(String value) {
    widget.controller.setPaymentAmount(double.tryParse(value) ?? 0);
  }

  Future<void> _submit() async {
    final invoiceId = await widget.controller.submit();
    if (!mounted) return;

    if (invoiceId != null) {
      Navigator.of(context).pop(invoiceId);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.controller.errorMessage ?? 'Failed to create sale.'),
      ),
    );
  }

  String _money(String value) {
    return '${double.tryParse(value)?.toStringAsFixed(2) ?? '0.00'} EGP';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('New sale')),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          if (widget.controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (widget.controller.errorMessage != null && widget.controller.customers.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline_rounded, size: 44, color: colors.error),
                    const SizedBox(height: AppSpacing.md),
                    Text(widget.controller.errorMessage!, textAlign: TextAlign.center),
                  ],
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.xxl,
            ),
            children: [
              const SectionHeader(title: 'Customer'),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<int>(
                value: widget.controller.selectedCustomer?.id,
                decoration: const InputDecoration(
                  labelText: 'Customer',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final customer in widget.controller.customers)
                    DropdownMenuItem<int>(
                      value: customer.id,
                      child: Text(
                        customer.phone.trim().isEmpty
                            ? customer.name
                            : '${customer.name} · ${customer.phone}',
                      ),
                    ),
                ],
                onChanged: widget.controller.isSubmitting
                    ? null
                    : (customerId) {
                        final customer = customerId == null
                            ? null
                            : widget.controller.customers.firstWhere((item) => item.id == customerId);
                        widget.controller.selectCustomer(customer);
                      },
              ),
              const SizedBox(height: AppSpacing.xl),
              const SectionHeader(title: 'Vehicle stock'),
              const SizedBox(height: AppSpacing.md),
              if (widget.controller.vehicleStock.isEmpty)
                AppCard(
                  child: Text(
                    'There is no available stock in the vehicle.',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                )
              else
                for (final product in widget.controller.vehicleStock)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: AppCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.productName,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_money(product.sellingPrice)} · Available: ${product.quantity}',
                                  style: TextStyle(
                                    color: colors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          QuantityStepper(
                            value: widget.controller.quantities[product.productId] ?? 0,
                            max: product.quantity,
                            onChanged: (quantity) => widget.controller.setQuantity(
                              product.productId,
                              quantity,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              const SizedBox(height: AppSpacing.md),
              const SectionHeader(title: 'Payment'),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<PaymentMethod>(
                value: widget.controller.paymentMethod,
                decoration: const InputDecoration(
                  labelText: 'Payment method',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final method in PaymentMethod.values)
                    DropdownMenuItem(
                      value: method,
                      child: Text(method.displayName),
                    ),
                ],
                onChanged: widget.controller.isSubmitting
                    ? null
                    : (method) {
                        if (method != null) widget.controller.setPaymentMethod(method);
                      },
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _paymentAmountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Payment amount',
                  suffixText: 'EGP',
                  border: OutlineInputBorder(),
                ),
                onChanged: _setPaymentAmount,
              ),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton.icon(
                  onPressed: widget.controller.totalAmount <= 0 || widget.controller.isSubmitting
                      ? null
                      : () {
                          _paymentAmountController.text = widget.controller.totalAmount.toStringAsFixed(2);
                          widget.controller.fillFullPayment();
                        },
                  icon: const Icon(Icons.done_all_rounded),
                  label: const Text('Pay full amount'),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AppCard(
                child: Column(
                  children: [
                    _summaryRow('Total', widget.controller.totalAmount),
                    _summaryRow('Payment now', widget.controller.paymentAmount),
                    const Divider(height: 20),
                    _summaryRow(
                      'Remaining',
                      widget.controller.remainingAfterPayment,
                      emphasized: true,
                    ),
                  ],
                ),
              ),
              if (widget.controller.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.md),
                  child: Text(
                    widget.controller.errorMessage!,
                    style: TextStyle(color: colors.error, fontSize: 12),
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: widget.controller.canSubmit ? _submit : null,
                  icon: widget.controller.isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(widget.controller.isSubmitting ? 'Saving...' : 'Create sale'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryRow(String label, double value, {bool emphasized = false}) {
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
          Text('${value.toStringAsFixed(2)} EGP', style: style),
        ],
      ),
    );
  }
}
