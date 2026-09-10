import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/ui/app_card.dart';
import '../../domain/entities/stock_transfer_request.dart';
import '../representative_vehicle_controller.dart';

class CreateLoadingRequestSheet extends StatefulWidget {
  final RepresentativeVehicleController controller;

  const CreateLoadingRequestSheet({
    super.key,
    required this.controller,
  });

  @override
  State<CreateLoadingRequestSheet> createState() => _CreateLoadingRequestSheetState();
}

class _CreateLoadingRequestSheetState extends State<CreateLoadingRequestSheet> {
  final Map<int, TextEditingController> _quantityControllers = {};
  int? _selectedWarehouseId;
  int? _selectedManagerId;

  @override
  void dispose() {
    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  TextEditingController _quantityController(int productId) {
    return _quantityControllers.putIfAbsent(
      productId,
      () => TextEditingController(),
    );
  }

  List<StockTransferRequestItem> _selectedItems() {
    final result = <StockTransferRequestItem>[];
    for (final stockItem in widget.controller.selectedWarehouseStock) {
      final text = _quantityController(stockItem.productId).text.trim();
      final quantity = int.tryParse(text) ?? 0;
      if (quantity <= 0) continue;
      if (quantity > stockItem.quantity) continue;
      result.add(
        StockTransferRequestItem(
          productId: stockItem.productId,
          productName: stockItem.productName,
          quantity: quantity,
          invoiceItemId: null,
        ),
      );
    }
    return result;
  }

  Future<void> _submit() async {
    final warehouseId = _selectedWarehouseId;
    final managerId = _selectedManagerId;
    if (warehouseId == null || managerId == null) {
      _showMessage('Select the warehouse and warehouse manager first.');
      return;
    }

    final items = _selectedItems();
    if (items.isEmpty) {
      _showMessage('Select at least one item and enter a valid quantity.');
      return;
    }

    final exceedsStock = widget.controller.selectedWarehouseStock.any((item) {
      final value = int.tryParse(_quantityController(item.productId).text.trim()) ?? 0;
      return value > item.quantity;
    });
    if (exceedsStock) {
      _showMessage('Requested quantity cannot exceed warehouse stock.');
      return;
    }

    final success = await widget.controller.createLoadingRequest(
      warehouseId: warehouseId,
      warehouseManagerId: managerId,
      items: items,
    );
    if (!mounted) return;

    if (success) {
      Navigator.of(context).pop(true);
      return;
    }
    _showMessage(widget.controller.errorMessage ?? 'Failed to create stock request.');
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (context, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Request goods',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
                ),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<int>(
                  value: _selectedWarehouseId,
                  decoration: const InputDecoration(
                    labelText: 'Warehouse',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final warehouse in widget.controller.warehouses)
                      DropdownMenuItem(
                        value: warehouse.id,
                        child: Text(warehouse.name),
                      ),
                  ],
                  onChanged: widget.controller.isSubmittingRequest
                      ? null
                      : (warehouseId) async {
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
                  onChanged: widget.controller.isSubmittingRequest
                      ? null
                      : (managerId) => setState(() => _selectedManagerId = managerId),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_selectedWarehouseId != null && widget.controller.selectedWarehouseStock.isEmpty)
                  Text(
                    'No available warehouse stock.',
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  )
                else if (widget.controller.selectedWarehouseStock.isNotEmpty)
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: widget.controller.selectedWarehouseStock.length,
                        separatorBuilder: (_, __) => const Divider(height: 16),
                        itemBuilder: (context, index) {
                          final item = widget.controller.selectedWarehouseStock[index];
                          final quantityController = _quantityController(item.productId);
                          return AppCard(
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(item.productName, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      const SizedBox(height: 2),
                                      Text('Available: ${item.quantity}', style: TextStyle(color: colors.textSecondary, fontSize: 12)),
                                    ],
                                  ),
                                ),
                                SizedBox(
                                  width: 90,
                                  child: TextField(
                                    controller: quantityController,
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
                        : const Icon(Icons.send_rounded),
                    label: Text(widget.controller.isSubmittingRequest ? 'Sending...' : 'Send request'),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
