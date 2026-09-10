import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/ui/app_card.dart';
import '../../domain/entities/returnable_invoice.dart';
import '../../domain/entities/stock_transfer_request.dart';
import '../representative_vehicle_controller.dart';

class CreateReturnRequestSheet extends StatefulWidget {
  final RepresentativeVehicleController controller;

  const CreateReturnRequestSheet({
    super.key,
    required this.controller,
  });

  @override
  State<CreateReturnRequestSheet> createState() => _CreateReturnRequestSheetState();
}

class _CreateReturnRequestSheetState extends State<CreateReturnRequestSheet> {
  final _invoiceIdController = TextEditingController();
  final Map<int, TextEditingController> _quantityControllers = {};

  ReturnableInvoice? _invoice;
  int? _selectedWarehouseId;
  int? _selectedManagerId;
  bool _loadingInvoice = false;

  @override
  void dispose() {
    _invoiceIdController.dispose();
    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _quantityController(int invoiceItemId) {
    return _quantityControllers.putIfAbsent(
      invoiceItemId,
      () => TextEditingController(),
    );
  }

  Future<void> _loadInvoice() async {
    final invoiceId = int.tryParse(_invoiceIdController.text.trim());
    if (invoiceId == null || invoiceId <= 0) {
      _showMessage('Enter a valid invoice number.');
      return;
    }

    setState(() => _loadingInvoice = true);
    try {
      final invoice = await widget.controller.fetchReturnableInvoice(invoiceId: invoiceId);
      if (!mounted) return;
      setState(() => _invoice = invoice);
      if (invoice == null) {
        _showMessage('Invoice not found.');
      }
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    } finally {
      if (mounted) setState(() => _loadingInvoice = false);
    }
  }

  List<StockTransferRequestItem> _selectedItems() {
    final result = <StockTransferRequestItem>[];
    for (final item in _invoice?.items ?? const <ReturnableInvoiceItem>[]) {
      final remaining = item.remainingQuantity;
      if (remaining <= 0) continue;
      final quantity = int.tryParse(_quantityController(item.invoiceItemId).text.trim()) ?? 0;
      if (quantity <= 0 || quantity > remaining) continue;
      result.add(
        StockTransferRequestItem(
          productId: item.productId,
          productName: item.productName,
          quantity: quantity,
          invoiceItemId: item.invoiceItemId,
        ),
      );
    }
    return result;
  }

  Future<void> _submit() async {
    final invoice = _invoice;
    final warehouseId = _selectedWarehouseId;
    final managerId = _selectedManagerId;
    if (invoice == null) {
      _showMessage('Load the paid invoice first.');
      return;
    }
    if (invoice.status != 'paid') {
      _showMessage('Only paid invoices can be returned.');
      return;
    }
    if (warehouseId == null || managerId == null) {
      _showMessage('Select the warehouse and warehouse manager first.');
      return;
    }

    final items = _selectedItems();
    if (items.isEmpty) {
      _showMessage('Enter a valid return quantity for at least one item.');
      return;
    }

    final invalidQuantity = invoice.items.any((item) {
      final value = int.tryParse(_quantityController(item.invoiceItemId).text.trim()) ?? 0;
      return value > item.remainingQuantity;
    });
    if (invalidQuantity) {
      _showMessage('Return quantity cannot exceed the remaining quantity.');
      return;
    }

    final success = await widget.controller.createReturnRequest(
      warehouseId: warehouseId,
      warehouseManagerId: managerId,
      invoiceId: invoice.id,
      items: items,
    );
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
      return;
    }
    _showMessage(widget.controller.errorMessage ?? 'Failed to create return request.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Request return', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: AppSpacing.lg),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _invoiceIdController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Invoice number',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    IconButton.filled(
                      onPressed: _loadingInvoice ? null : _loadInvoice,
                      icon: _loadingInvoice
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.search_rounded),
                    ),
                  ],
                ),
                if (_invoice != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Invoice #${_invoice!.id} · ${_invoice!.customerName}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<int>(
                    value: _selectedWarehouseId,
                    decoration: const InputDecoration(
                      labelText: 'Return warehouse',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final warehouse in widget.controller.warehouses)
                        DropdownMenuItem(
                          value: warehouse.id,
                          child: Text(warehouse.name),
                        ),
                    ],
                    onChanged: (warehouseId) async {
                      if (warehouseId == null) return;
                      setState(() {
                        _selectedWarehouseId = warehouseId;
                        _selectedManagerId = null;
                      });
                      await widget.controller.selectWarehouse(warehouseId);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<int>(
                    value: _selectedManagerId,
                    decoration: const InputDecoration(
                      labelText: 'Warehouse manager',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final manager in widget.controller.warehouseManagers)
                        DropdownMenuItem(
                          value: manager.id,
                          child: Text(manager.name),
                        ),
                    ],
                    onChanged: (managerId) => setState(() => _selectedManagerId = managerId),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (_invoice!.items.every((item) => item.remainingQuantity <= 0))
                    Text(
                      'There is no remaining quantity to return from this invoice.',
                      style: TextStyle(color: colors.textSecondary, fontSize: 13),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _invoice!.items.length,
                        separatorBuilder: (_, __) => const Divider(height: 16),
                        itemBuilder: (context, index) {
                          final item = _invoice!.items[index];
                          final remaining = item.remainingQuantity;
                          if (remaining <= 0) return const SizedBox.shrink();
                          return AppCard(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Sold: ${item.soldQuantity} · Remaining: $remaining',
                                        style: TextStyle(color: colors.textSecondary, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 90,
                                  child: TextField(
                                    controller: _quantityController(item.invoiceItemId),
                                    keyboardType: TextInputType.number,
                                    decoration: const InputDecoration(
                                      labelText: 'Qty',
                                      isDense: true,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: widget.controller.isSubmittingRequest ? null : _submit,
                      icon: widget.controller.isSubmittingRequest
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.undo_rounded),
                      label: Text(widget.controller.isSubmittingRequest ? 'Sending...' : 'Send return request'),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
