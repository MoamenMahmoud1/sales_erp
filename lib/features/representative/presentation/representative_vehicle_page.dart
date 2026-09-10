import 'package:flutter/material.dart';

import '../../../core/repositories/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/section_header.dart';
import '../../../core/ui/status_badge.dart';
import 'representative_sale_controller.dart';
import 'representative_sale_page.dart';
import 'representative_vehicle_controller.dart';
import 'widgets/create_loading_request_sheet.dart';
import 'widgets/create_return_request_sheet.dart';
import 'widgets/stock_transfer_requests_card.dart';
import 'widgets/vehicle_stock_card.dart';

class RepresentativeVehiclePage extends StatefulWidget {
  final RepresentativeVehicleController? controller;

  const RepresentativeVehiclePage({
    super.key,
    this.controller,
  });

  @override
  State<RepresentativeVehiclePage> createState() => _RepresentativeVehiclePageState();
}

class _RepresentativeVehiclePageState extends State<RepresentativeVehiclePage> {
  late final RepresentativeVehicleController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? RepresentativeVehicleController(
      repository: AppServices.instance.representativeVehicleRepository,
    );
    _controller.load();
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  Future<void> _openLoadingRequest() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => CreateLoadingRequestSheet(controller: _controller),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stock request sent for warehouse approval.')),
      );
    }
  }

  Future<void> _openReturnRequest() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => CreateReturnRequestSheet(controller: _controller),
    );
    if (created == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Return request sent for warehouse approval.')),
      );
    }
  }

  Future<void> _openSale() async {
    final vehicle = _controller.vehicle;
    if (vehicle == null || _controller.vehicleStock.isEmpty) return;

    final saleController = RepresentativeSaleController(
      repository: AppServices.instance.representativeSaleRepository,
    );
    final invoiceId = await Navigator.of(context).push<int>(
      MaterialPageRoute(
        builder: (_) => RepresentativeSalePage(
          vehicleStock: _controller.vehicleStock,
          controller: saleController,
        ),
      ),
    );
    saleController.dispose();

    if (invoiceId != null && mounted) {
      await _controller.load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invoice #$invoiceId created from vehicle stock.')),
      );
    }
  }

  StatusType _vehicleStatusType(bool available) {
    return available ? StatusType.success : StatusType.warning;
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Vehicle'),
            actions: [
              IconButton(
                tooltip: 'Refresh',
                icon: const Icon(Icons.refresh_rounded),
                onPressed: _controller.isLoading ? null : _controller.load,
              ),
            ],
          ),
          body: _controller.isLoading && _controller.vehicle == null
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _controller.load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      if (_controller.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.md),
                          child: AppCard(
                            child: Text(
                              _controller.errorMessage!,
                              style: TextStyle(color: colors.error, fontSize: 13),
                            ),
                          ),
                        ),
                      SectionHeader(
                        title: 'Current vehicle',
                        trailing: _controller.vehicle == null
                            ? null
                            : StatusBadge(
                                type: _vehicleStatusType(true),
                                label: 'Open shift',
                                icon: Icons.play_circle_outline_rounded,
                              ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppCard(
                        child: _controller.vehicle == null
                            ? Row(
                                children: [
                                  Icon(Icons.local_shipping_outlined, color: colors.textSecondary),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Text(
                                      'No vehicle is assigned to the current shift.',
                                      style: TextStyle(color: colors.textSecondary, fontSize: 13),
                                    ),
                                  ),
                                ],
                              )
                            : Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: colors.primaryContainer,
                                      borderRadius: AppRadius.mdAll,
                                    ),
                                    child: Icon(Icons.local_shipping_rounded, color: colors.primary),
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _controller.vehicle!.vehicleName,
                                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          'Shift #${_controller.vehicle!.shiftId} · ${_controller.vehicle!.businessDate}',
                                          style: TextStyle(color: colors.textSecondary, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      const SectionHeader(title: 'Vehicle stock'),
                      const SizedBox(height: AppSpacing.md),
                      VehicleStockCard(items: _controller.vehicleStock),
                      const SizedBox(height: AppSpacing.md),
                      if (_controller.vehicle != null && _controller.vehicle!.vehicleId > 0) ...[
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _controller.vehicleStock.isEmpty ? null : _openSale,
                            icon: const Icon(Icons.point_of_sale_rounded),
                            label: const Text('New sale'),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _controller.isSubmittingRequest ? null : _openLoadingRequest,
                            icon: const Icon(Icons.add_box_rounded),
                            label: const Text('Request goods from warehouse'),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _controller.isSubmittingRequest ? null : _openReturnRequest,
                            icon: const Icon(Icons.undo_rounded),
                            label: const Text('Request a return to warehouse'),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.xl),
                      StockTransferRequestsCard(requests: _controller.transferRequests),
                      const SizedBox(height: AppSpacing.xxl),
                    ],
                  ),
                ),
        );
      },
    );
  }
}
