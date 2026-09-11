import 'package:flutter/material.dart';

import '../../../core/repositories/app_services.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/app_card.dart';
import '../../../core/ui/section_header.dart';
import '../domain/repositories/representative_sale_repository.dart';
import 'representative_sale_controller.dart';
import 'representative_sale_page.dart';
import 'representative_vehicle_controller.dart';
import 'widgets/create_loading_request_sheet.dart';
import 'widgets/create_return_request_sheet.dart';
import 'widgets/stock_transfer_requests_card.dart';
import 'widgets/vehicle_stock_card.dart';

class RepresentativeVehiclePage extends StatefulWidget {
  final RepresentativeVehicleController? controller;
  final bool canSell;

  const RepresentativeVehiclePage({
    super.key,
    this.controller,
    this.canSell = false,
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
      final message = _controller.lastRequestQueued
          ? 'Request saved locally. It will be sent when the connection returns.'
          : 'Stock request sent for warehouse approval.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
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
      final message = _controller.lastRequestQueued
          ? 'Return request saved locally. It will be sent when the connection returns.'
          : 'Return request sent for warehouse approval.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _openSale() async {
    final vehicle = _controller.vehicle;
    if (!widget.canSell || vehicle == null || _controller.vehicleStock.isEmpty) return;

    final saleController = RepresentativeSaleController(
      repository: AppServices.instance.representativeSaleRepository,
    );
    final submission = await Navigator.of(context).push<RepresentativeSaleSubmission>(
      MaterialPageRoute(
        builder: (_) => RepresentativeSalePage(
          vehicleStock: _controller.vehicleStock,
          controller: saleController,
        ),
      ),
    );
    saleController.dispose();

    if (!mounted || submission == null) return;
    if (submission.queued) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sale saved locally. It will be submitted automatically when the connection returns.',
          ),
        ),
      );
      return;
    }

    await _controller.load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invoice #${submission.invoiceId} created from vehicle stock.')),
    );
  }

  Future<void> _openVehicleActions() async {
    final vehicle = _controller.vehicle;
    if (vehicle == null) return;

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final nameController = TextEditingController(text: vehicle.vehicleName);
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            MediaQuery.viewInsetsOf(sheetContext).bottom + AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Vehicle name'),
              ),
              const SizedBox(height: AppSpacing.md),
              FilledButton(
                onPressed: () async {
                  final succeeded = await _controller.requestVehicleUpdate(
                    name: nameController.text.trim(),
                  );
                  if (!sheetContext.mounted) return;
                  Navigator.of(sheetContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        succeeded
                            ? _controller.lastVehicleMutationQueued
                                ? 'Vehicle update saved locally and waiting for manager approval.'
                                : 'Vehicle update request submitted for manager approval.'
                            : 'Unable to create vehicle update request.',
                      ),
                    ),
                  );
                },
                child: const Text('Request name change'),
              ),
              const SizedBox(height: AppSpacing.sm),
              OutlinedButton(
                onPressed: () async {
                  final succeeded = await _controller.requestVehicleDelete();
                  if (!sheetContext.mounted) return;
                  Navigator.of(sheetContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        succeeded
                            ? _controller.lastVehicleMutationQueued
                                ? 'Vehicle deletion saved locally and waiting for manager approval.'
                                : 'Vehicle deletion request submitted for manager approval.'
                            : 'Unable to create vehicle deletion request.',
                      ),
                    ),
                  );
                },
                child: const Text('Request vehicle deletion'),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_controller.vehicle?.vehicleName ?? 'My vehicle'),
        actions: [
          if (_controller.vehicle != null)
            IconButton(
              onPressed: _openVehicleActions,
              tooltip: 'Vehicle actions',
              icon: const Icon(Icons.more_horiz_rounded),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _controller.load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            120,
          ),
          children: [
            if (_controller.isLoading && _controller.vehicle == null)
              const LinearProgressIndicator(),
            if (_controller.errorMessage != null) ...[
              AppCard(
                child: Text(
                  _controller.errorMessage!,
                  style: TextStyle(color: colors.error),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
            SectionHeader(
              title: 'Vehicle stock',
              subtitle: _controller.vehicle == null
                  ? 'No active shift vehicle is assigned.'
                  : 'Current stock and selling prices.',
            ),
            const SizedBox(height: AppSpacing.sm),
            VehicleStockCard(items: _controller.vehicleStock),
            if (widget.canSell && _controller.vehicleStock.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.md),
              FilledButton.icon(
                onPressed: _openSale,
                icon: const Icon(Icons.point_of_sale_rounded),
                label: const Text('New sale'),
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            SectionHeader(
              title: 'Stock requests',
              subtitle: 'Loading and return requests with warehouse approval status.',
            ),
            const SizedBox(height: AppSpacing.sm),
            StockTransferRequestsCard(requests: _controller.transferRequests),
            const SizedBox(height: AppSpacing.md),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: [
                OutlinedButton.icon(
                  onPressed: _openLoadingRequest,
                  icon: const Icon(Icons.local_shipping_rounded),
                  label: const Text('Request goods'),
                ),
                OutlinedButton.icon(
                  onPressed: _openReturnRequest,
                  icon: const Icon(Icons.keyboard_return_rounded),
                  label: const Text('Return goods'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
