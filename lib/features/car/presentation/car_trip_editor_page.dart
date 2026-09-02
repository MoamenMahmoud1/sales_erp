import 'package:flutter/material.dart';

import '../../../core/repositories/app_services.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/dialogs.dart';
import '../../products/domain/product.dart';
import '../../products/presentation/products_page.dart';
import '../application/usecases/confirm_car_trip.dart';
import '../application/usecases/create_and_confirm_car_trip.dart';
import '../application/usecases/create_car_trip.dart';
import '../application/usecases/revise_car_trip.dart';
import '../application/usecases/update_car_trip_draft.dart';
import '../domain/entities/car_load_item.dart';
import '../domain/entities/car_trip.dart';
import '../domain/entities/car_trip_status.dart';
import '../domain/entities/money.dart';
import '../domain/entities/sales_car.dart';
import '../domain/entities/warehouse.dart';
import '../domain/services/car_calculator.dart';
import '../presentation/animations/car_closing_animation.dart';
import 'widgets/car_metric_card.dart';

class CarTripEditorPage extends StatefulWidget {
  final int? tripId;

  const CarTripEditorPage({super.key, this.tripId});

  @override
  State<CarTripEditorPage> createState() => _CarTripEditorPageState();
}

class _CarTripEditorPageState extends State<CarTripEditorPage> {
  final _catalog = AppServices.instance.carCatalogRepository;
  final _trips = AppServices.instance.carTripRepository;
  final _products = AppServices.instance.productRepository;
  final _calculator = const CarCalculator();

  late final CreateCarTrip _create = CreateCarTrip(_trips);
  late final CreateAndConfirmCarTrip _createAndConfirmUseCase =
      CreateAndConfirmCarTrip(_trips);
  late final UpdateCarTripDraft _update = UpdateCarTripDraft(_trips);
  late final ConfirmCarTrip _confirm = ConfirmCarTrip(_trips);
  late final ReviseCarTrip _revise = ReviseCarTrip(_trips);

  List<SalesCar> _cars = const [];
  List<Warehouse> _warehouses = const [];
  List<Product> _productsList = const [];

  SalesCar? _selectedCar;
  Warehouse? _selectedWarehouse;
  DateTime? _dueDate;
  String? _displayNumber;
  CarTrip? _original;

  final Map<int, int> _loaded = {};
  final Map<int, int> _returned = {};
  final Map<int, double> _discounts = {};
  final Map<int, CarMoney> _unitPrices = {};
  final Map<int, String> _productNames = {};

  bool _loading = true;
  bool _saving = false;
  String? _error;
  double _globalDiscountPercent = 0;
  final _globalDiscountController = TextEditingController(text: '0');

  bool get _editing => widget.tripId != null;
  List<int> get _selectedProductIds => _loaded.keys.toList(growable: false);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _globalDiscountController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        _catalog.getCars(activeOnly: true),
        _catalog.getWarehouses(activeOnly: true),
        _products.getProducts(),
      ]);
      _cars = results[0] as List<SalesCar>;
      _warehouses = results[1] as List<Warehouse>;
      _productsList = results[2] as List<Product>;

      if (_editing) {
        final trip = await _trips.getTripById(widget.tripId!);
        if (trip == null) throw StateError('Car invoice not found.');
        _original = trip;
        _selectedCar = _cars.where((c) => c.id == trip.salesCarId).firstOrNull;
        _selectedWarehouse =
            _warehouses.where((w) => w.id == trip.warehouseId).firstOrNull;
        _dueDate = trip.dueDate?.toLocal();
        _displayNumber = trip.displayNumber;
        _globalDiscountPercent = trip.globalDiscountPercent;
        _globalDiscountController.text =
            trip.globalDiscountPercent.toStringAsFixed(2);
        for (final item in trip.items) {
          _loaded[item.productId] = item.loadedCartons;
          _returned[item.productId] = item.returnedCartons;
          _discounts[item.productId] = item.discountPercent;
          _unitPrices[item.productId] = item.unitPrice;
          _productNames[item.productId] = item.productName;
        }
      } else {
        if (_cars.length == 1) _selectedCar = _cars.first;
        if (_warehouses.length == 1) _selectedWarehouse = _warehouses.first;
      }

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  Future<void> _reloadProducts() async {
    _productsList = await _products.getProducts();
    if (mounted) setState(() {});
  }

  List<CarLoadItem> get _items => [
        for (final id in _selectedProductIds) _itemFor(id),
      ];

  CarLoadItem _itemFor(int id) {
    final product = _productsList.firstWhere((p) => p.id == id);
    return CarLoadItem(
      productId: id,
      productName: _productNames[id] ?? product.name,
      unitPrice: _unitPrices[id] ?? CarMoney.fromUnits(product.price),
      loadedCartons: _loaded[id] ?? 0,
      returnedCartons: _returned[id] ?? 0,
      discountPercent: _discounts[id] ?? 0,
    );
  }

  CarTrip _buildTrip({required bool closed}) {
    final now = DateTime.now().toUtc();
    return CarTrip(
      id: _original?.id ?? 0,
      displayNumber: _displayNumber ?? _original?.displayNumber ?? '',
      salesCarId: _selectedCar!.id,
      salesCarName: _selectedCar!.name,
      warehouseId: _selectedWarehouse!.id,
      warehouseName: _selectedWarehouse!.name,
      openedAt: _original?.openedAt ?? now,
      closedAt: closed ? (_original?.closedAt ?? now) : _original?.closedAt,
      dueDate: _dueDate?.toUtc(),
      status: closed ? CarTripStatus.closed : CarTripStatus.open,
      items: _items,
      globalDiscountPercent: _globalDiscountPercent,
      payment: _original?.payment ?? const CarPayment(),
    );
  }

  bool _validateHeader() {
    if (_selectedCar == null) {
      _showError('Select a Car.');
      return false;
    }
    if (_selectedWarehouse == null) {
      _showError('Select a Warehouse.');
      return false;
    }
    if (_items.isEmpty) {
      _showError('Add at least one product.');
      return false;
    }
    return true;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveDraft() async {
    if (_saving || !_validateHeader()) return;
    setState(() => _saving = true);
    try {
      final saved = _editing
          ? await _update(_buildTrip(closed: false))
          : await _create(_buildTrip(closed: false));
      _original = saved;
      _displayNumber = saved.displayNumber;
      AppServices.instance.carTripEvents.publish(saved);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Draft ${saved.displayNumber} saved.')),
      );
      if (!_editing) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _showError('$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmAndClose() async {
    if (_saving || !_validateHeader()) return;

    final preview = _buildTrip(closed: true);
    final issues = _calculator.validate(preview);
    if (issues.isNotEmpty) {
      _showError(issues.first.message);
      return;
    }

    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Confirm Car invoice?',
      message:
          'This will finalize the daily load/return calculation and create an immutable historical revision.',
      confirmLabel: 'Confirm',
    );
    if (!confirmed || !mounted) return;

    setState(() => _saving = true);
    try {
      final persisted = !_editing
          ? await _createAndConfirmUseCase(
              _buildTrip(closed: false),
              triggeredBy: 'invoice_close',
            )
          : _original!.isClosed
              ? await _revise(preview, triggeredBy: 'invoice_edit')
              : await _confirm(preview, triggeredBy: 'invoice_close');

      final summary = _calculator.summary(persisted);
      AppServices.instance.carTripEvents.publish(persisted);
      if (!mounted) return;
      await Navigator.of(context).push(
        PageRouteBuilder(
          opaque: true,
          pageBuilder: (_, animation, __) => CarClosingAnimation(
            displayNumber: persisted.displayNumber,
            summary: summary,
          ),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 180),
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _showError('$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addProduct() async {
    final available = _productsList
        .where((product) => !_loaded.containsKey(product.id))
        .toList(growable: false);
    if (available.isEmpty) {
      _showError('All available products are already on this Car invoice.');
      return;
    }

    final chosen = await showModalBottomSheet<Product>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(
              title: Text('Add product'),
              subtitle: Text('Select a product for this Car load'),
            ),
            for (final product in available)
              ListTile(
                title: Text(product.name),
                subtitle: Text(
                  '${product.price.toStringAsFixed(2)} EGP / carton',
                ),
                trailing: const Icon(Icons.add_rounded),
                onTap: () => Navigator.of(context).pop(product),
              ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Create a new product'),
              onTap: () async {
                Navigator.of(context).pop();
                await Navigator.of(this.context).push(
                  MaterialPageRoute(builder: (_) => const ProductsPage()),
                );
                await _reloadProducts();
              },
            ),
          ],
        ),
      ),
    );

    if (chosen == null || !mounted) return;
    setState(() {
      _loaded[chosen.id] = 1;
      _returned[chosen.id] = 0;
      _discounts[chosen.id] = 0;
      _unitPrices[chosen.id] = CarMoney.fromUnits(chosen.price);
      _productNames[chosen.id] = chosen.name;
    });
  }

  Future<void> _createCar() async {
    final controller = TextEditingController();
    try {
      final name = await _textDialog(
        title: 'New Car',
        label: 'Car name',
        controller: controller,
      );
      if (name == null || name.trim().isEmpty) return;
      final car = await _catalog.createCar(
        SalesCar(name: name.trim(), createdAt: DateTime.now().toUtc()),
      );
      _cars = [..._cars, car]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (mounted) setState(() => _selectedCar = car);
    } finally {
      controller.dispose();
    }
  }

  Future<void> _createWarehouse() async {
    final controller = TextEditingController();
    try {
      final name = await _textDialog(
        title: 'New Warehouse',
        label: 'Warehouse name',
        controller: controller,
      );
      if (name == null || name.trim().isEmpty) return;
      final warehouse = await _catalog.createWarehouse(
        Warehouse(name: name.trim(), createdAt: DateTime.now().toUtc()),
      );
      _warehouses = [..._warehouses, warehouse]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (mounted) setState(() => _selectedWarehouse = warehouse);
    } finally {
      controller.dispose();
    }
  }

  Future<String?> _textDialog({
    required String title,
    required String label,
    required TextEditingController controller,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Car invoice')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, size: 48),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit Car Invoice' : 'New Car Invoice')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Products',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton.icon(
                onPressed: _saving ? null : _addProduct,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add product'),
              ),
            ],
          ),
          if (_selectedProductIds.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.inventory_2_outlined),
                title: Text('No products yet'),
                subtitle: Text('Add cartons loaded on the Car.'),
              ),
            )
          else
            for (final id in _selectedProductIds) _productCard(id),
          const SizedBox(height: 18),
          _buildDiscountSection(),
          const SizedBox(height: 18),
          _buildSummary(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : _saveDraft,
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                child: const Text('Save draft'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _saving ? null : _confirmAndClose,
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check_circle_outline_rounded),
                label: Text(_saving ? 'Processing...' : 'Confirm & close'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: _dropdown<SalesCar>(
                    label: 'Car',
                    value: _selectedCar,
                    items: _cars,
                    labelOf: (car) => car.name,
                    onChanged: (value) => setState(() => _selectedCar = value),
                  ),
                ),
                IconButton(
                  tooltip: 'Create Car',
                  onPressed: _saving ? null : _createCar,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _dropdown<Warehouse>(
                    label: 'Warehouse',
                    value: _selectedWarehouse,
                    items: _warehouses,
                    labelOf: (warehouse) => warehouse.name,
                    onChanged: (value) =>
                        setState(() => _selectedWarehouse = value),
                  ),
                ),
                IconButton(
                  tooltip: 'Create Warehouse',
                  onPressed: _saving ? null : _createWarehouse,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            InkWell(
              borderRadius: AppRadius.lgAll,
              onTap: _saving ? null : _pickDueDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Payment due date',
                  prefixIcon: const Icon(Icons.event_outlined),
                  border: OutlineInputBorder(borderRadius: AppRadius.lgAll),
                ),
                child: Text(
                  _dueDate == null ? 'Not specified' : _formatDate(_dueDate!),
                  style: TextStyle(
                    color: _dueDate == null
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dropdown<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) labelOf,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: AppRadius.lgAll),
      ),
      items: [
        for (final item in items)
          DropdownMenuItem<T>(
            value: item,
            child: Text(labelOf(item), overflow: TextOverflow.ellipsis),
          ),
      ],
      onChanged: onChanged,
    );
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
      initialDate: _dueDate ?? now,
    );
    if (picked != null && mounted) setState(() => _dueDate = picked);
  }

  Widget _productCard(int id) {
    final product = _productsList.firstWhere((p) => p.id == id);
    final loaded = _loaded[id] ?? 0;
    final returned = _returned[id] ?? 0;
    final sold = loaded - returned;
    final discount = _discounts[id] ?? 0;
    final scheme = Theme.of(context).colorScheme;
    final line = _calculator.itemLine(_itemFor(id));

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _productNames[id] ?? product.name,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${line.item.unitPrice.units.toStringAsFixed(2)} EGP / carton',
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remove product',
                  onPressed: _saving
                      ? null
                      : () => setState(() {
                            _loaded.remove(id);
                            _returned.remove(id);
                            _discounts.remove(id);
                            _unitPrices.remove(id);
                            _productNames.remove(id);
                          }),
                  icon: Icon(Icons.close_rounded, color: scheme.error),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _quantityField(
                    label: 'Loaded',
                    value: loaded,
                    onChanged: (value) => setState(() => _loaded[id] = value),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _quantityField(
                    label: 'Returned',
                    value: returned,
                    max: loaded,
                    onChanged: (value) => setState(() => _returned[id] = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    initialValue: discount.toStringAsFixed(2),
                    key: ValueKey('discount-$id-$discount'),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Product discount %',
                      suffixText: '%',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      final parsed = double.tryParse(value);
                      if (parsed == null) return;
                      setState(() => _discounts[id] = parsed.clamp(0, 100).toDouble());
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('$sold sold', style: const TextStyle(fontWeight: FontWeight.w900)),
                      const SizedBox(height: 3),
                      Text(
                        _money(line.netValue),
                        style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quantityField({
    required String label,
    required int value,
    required ValueChanged<int> onChanged,
    int? max,
  }) {
    final cappedMax = max ?? 1000000;
    return Row(
      children: [
        IconButton(
          onPressed: _saving || value <= 0 ? null : () => onChanged(value - 1),
          icon: const Icon(Icons.remove_circle_outline_rounded),
        ),
        Expanded(
          child: TextFormField(
            key: ValueKey('$label-$value'),
            initialValue: '$value',
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(border: OutlineInputBorder()),
            onChanged: (raw) {
              final parsed = int.tryParse(raw);
              if (parsed == null) return;
              onChanged(parsed.clamp(0, cappedMax).toInt());
            },
          ),
        ),
        IconButton(
          onPressed: _saving || value >= cappedMax ? null : () => onChanged(value + 1),
          icon: const Icon(Icons.add_circle_outline_rounded),
        ),
      ],
    );
  }

  Widget _buildDiscountSection() {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _globalDiscountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Global discount %',
                  suffixText: '%',
                  border: OutlineInputBorder(),
                ),
                onChanged: (raw) {
                  final parsed = double.tryParse(raw);
                  if (parsed == null) return;
                  setState(() => _globalDiscountPercent = parsed.clamp(0, 100).toDouble());
                },
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Applied after all product-level discounts.',
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    if (_selectedProductIds.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final summary = _calculator.summary(_buildTrip(closed: false));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Calculation summary', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 2.3,
          children: [
            CarMetricCard(label: 'Loaded cartons', value: '${summary.totalLoadedCartons}', icon: Icons.outbox_rounded),
            CarMetricCard(label: 'Returned cartons', value: '${summary.totalReturnedCartons}', icon: Icons.assignment_return_rounded),
            CarMetricCard(label: 'Sold cartons', value: '${summary.totalSoldCartons}', icon: Icons.point_of_sale_rounded),
            CarMetricCard(label: 'Gross sold value', value: _money(summary.grossSubtotal), icon: Icons.receipt_long_outlined),
          ],
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _summaryRow('Product discounts', summary.productDiscountTotal),
                _summaryRow('After product discounts', summary.subtotalAfterProducts),
                _summaryRow('Global discount', summary.globalDiscountAmount),
                const Divider(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Actual sold value', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
                    Text(_money(summary.finalTotalSoldValue), style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: scheme.primary)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, CarMoney amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(_money(amount), style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  String _money(CarMoney value) => 'EGP ${value.units.toStringAsFixed(2)}';

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
