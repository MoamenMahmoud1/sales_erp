import 'package:flutter/material.dart';

import '../../../core/repositories/app_services.dart';
import '../../products/domain/product.dart';
import '../../products/presentation/product_form_page.dart';
import '../application/usecases/confirm_car_trip.dart';
import '../application/usecases/create_and_confirm_car_trip.dart';
import '../application/usecases/create_car_trip.dart';
import '../application/usecases/revise_car_trip.dart';
import '../application/usecases/update_car_trip_draft.dart';
import '../domain/entities/car_load_item.dart';
import '../domain/entities/car_trip.dart';
import '../domain/entities/money.dart';
import '../domain/entities/sales_car.dart';
import '../domain/entities/warehouse.dart';
import '../domain/services/car_calculator.dart';
import '../presentation/animations/car_closing_animation.dart';
import 'car_trip_details_page.dart';
import 'widgets/car_metric_card.dart';

enum _CreateProductAction { create }

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
  late final CreateAndConfirmCarTrip _createAndConfirm =
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
  final Map<int, CarMoney> _sellingPrices = {};
  final Map<int, CarMoney> _purchasePrices = {};
  final Map<int, String> _productNames = {};

  bool _loading = true;
  bool _saving = false;
  String? _error;
  double _globalDiscountPercent = 0;
  double _globalDiscountEgp = 0;

  final _globalDiscountController = TextEditingController(text: '0');
  final _globalDiscountEgpController = TextEditingController(text: '0');

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
    _globalDiscountEgpController.dispose();
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
        _selectedCar =
            _cars.where((car) => car.id == trip.salesCarId).firstOrNull;
        _selectedWarehouse =
            _warehouses.where((warehouse) => warehouse.id == trip.warehouseId).firstOrNull;
        _dueDate = trip.dueDate?.toLocal();
        _displayNumber = trip.displayNumber;
        _globalDiscountPercent = trip.globalDiscountPercent;
        _globalDiscountEgp = trip.globalDiscountEgp.units;

        _globalDiscountController.text = _formatInput(_globalDiscountPercent);
        _globalDiscountEgpController.text = _formatInput(_globalDiscountEgp);

        for (final item in trip.items) {
          _loaded[item.productId] = item.loadedCartons;
          _returned[item.productId] = item.returnedCartons;
          _discounts[item.productId] = item.discountPercent;
          _sellingPrices[item.productId] = item.sellingPrice;
          _purchasePrices[item.productId] = item.purchasePrice;
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

  String _formatInput(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);

  List<CarLoadItem> get _items => [for (final id in _selectedProductIds) _itemFor(id)];

  CarLoadItem _itemFor(int id) {
    final product = _productsList.firstWhere((item) => item.id == id);
    return CarLoadItem(
      productId: id,
      productName: _productNames[id] ?? product.name,
      unitPrice:
          _sellingPrices[id] ?? CarMoney.fromUnits(product.sellingPrice),
      purchasePrice:
          _purchasePrices[id] ?? CarMoney.fromUnits(product.purchasePrice),
      loadedCartons: _loaded[id] ?? 0,
      returnedCartons: _returned[id] ?? 0,
      discountPercent: _discounts[id] ?? 0,
    );
  }

  CarTrip? _buildTripOrNull({bool closed = false}) {
    final car = _selectedCar;
    final warehouse = _selectedWarehouse;
    if (car == null || warehouse == null) return null;

    final now = DateTime.now().toUtc();
    return CarTrip(
      id: _original?.id ?? 0,
      displayNumber: _displayNumber ?? _original?.displayNumber ?? '',
      salesCarId: car.id,
      salesCarName: car.name,
      warehouseId: warehouse.id,
      warehouseName: warehouse.name,
      openedAt: _original?.openedAt ?? now,
      closedAt: closed ? (_original?.closedAt ?? now) : _original?.closedAt,
      dueDate: _dueDate?.toUtc(),
      status: closed ? CarTripStatus.closed : CarTripStatus.open,
      items: _items,
      globalDiscountPercent: _globalDiscountPercent,
      globalDiscountEgp: CarMoney.fromUnits(_globalDiscountEgp),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _saveDraft() async {
    if (_saving || !_validateHeader()) return;
    setState(() => _saving = true);

    try {
      final trip = _buildTripOrNull();
      if (trip == null) throw StateError('Select a Car and Warehouse.');

      final saved = _editing ? await _update(trip) : await _create(trip);
      _original = saved;
      _displayNumber = saved.displayNumber;

      if (!mounted) return;
      AppServices.instance.carTripEvents.publish(saved);
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

    final preview = _buildTripOrNull(closed: true);
    if (preview == null) {
      _showError('Select a Car and Warehouse before confirming.');
      return;
    }

    final issues = _calculator.validate(preview);
    if (issues.isNotEmpty) {
      _showError(issues.first.message);
      return;
    }

    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Confirm Car invoice?',
      message: 'Finalize this Car load and save the historical revision.',
      confirmLabel: 'Confirm',
    );
    if (!confirmed || !mounted) return;

    setState(() => _saving = true);
    try {
      final persisted = !_editing
          ? await _createAndConfirm(
              _buildTripOrNull()!,
              triggeredBy: 'invoice_close',
            )
          : _original!.isClosed
              ? await _revise(preview, triggeredBy: 'invoice_edit')
              : await _confirm(preview, triggeredBy: 'invoice_close');

      final summary = _calculator.summary(persisted);
      AppServices.instance.carTripEvents.publish(persisted);
      if (!mounted) return;

      final result = await Navigator.of(context).push<bool>(
        PageRouteBuilder(
          opaque: true,
          pageBuilder: (_, __, ___) => CarClosingAnimation(
            displayNumber: persisted.displayNumber,
            summary: summary,
          ),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 180),
        ),
      );

      if (!mounted) return;
      if (result == true) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => CarTripDetailsPage(tripId: persisted.id),
          ),
        );
      } else {
        Navigator.of(context).pop(true);
      }
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

    final chosen = await showModalBottomSheet<Object?>(
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
                  'Sell ${product.sellingPrice.toStringAsFixed(2)} EGP · Buy ${product.purchasePrice.toStringAsFixed(2)} EGP / carton',
                ),
                trailing: const Icon(Icons.add_rounded),
                onTap: () => Navigator.of(context).pop(product),
              ),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Create a new product'),
              onTap: () => Navigator.of(context).pop(_CreateProductAction.create),
            ),
          ],
        ),
      ),
    );

    if (!mounted || chosen == null) return;

    if (chosen == _CreateProductAction.create) {
      final created = await Navigator.of(context).push<Product>(
        MaterialPageRoute(
          builder: (_) => ProductFormPage(
            repository: _products,
            carMode: true,
          ),
        ),
      );
      if (!mounted || created == null) return;

      _productsList = [..._productsList, created]
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      setState(() {
        _loaded[created.id] = 1;
        _returned[created.id] = 0;
        _discounts[created.id] = 0;
        _sellingPrices[created.id] = CarMoney.fromUnits(created.sellingPrice);
        _purchasePrices[created.id] = CarMoney.fromUnits(created.purchasePrice);
        _productNames[created.id] = created.name;
      });
      return;
    }

    if (chosen is Product) {
      setState(() {
        _loaded[chosen.id] = 1;
        _returned[chosen.id] = 0;
        _discounts[chosen.id] = 0;
        _sellingPrices[chosen.id] = CarMoney.fromUnits(chosen.sellingPrice);
        _purchasePrices[chosen.id] = CarMoney.fromUnits(chosen.purchasePrice);
        _productNames[chosen.id] = chosen.name;
      });
    }
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
        SalesCar(
          name: name.trim(),
          createdAt: DateTime.now().toUtc(),
        ),
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
        Warehouse(
          name: name.trim(),
          createdAt: DateTime.now().toUtc(),
        ),
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
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
      appBar: AppBar(
        title: Text(_editing ? 'Edit Car Invoice' : 'New Car Invoice'),
      ),
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
          const SizedBox(height: 16),
          _buildDiscountSection(),
          const SizedBox(height: 16),
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
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                child: const Text('Save draft'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                onPressed: _saving ? null : _confirmAndClose,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
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
              borderRadius: BorderRadius.circular(14),
              onTap: _saving ? null : _pickDueDate,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: 'Payment due date',
                  prefixIcon: const Icon(Icons.event_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
        ),
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
    if (picked != null && mounted) {
      setState(() => _dueDate = picked);
    }
  }

  Widget _productCard(int id) {
    final product = _productsList.firstWhere((item) => item.id == id);
    final line = _calculator.itemLine(_itemFor(id));
    final loaded = _loaded[id] ?? 0;
    final returned = _returned[id] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Sell ${_money(line.item.sellingPrice)}  ·  Buy ${_money(line.item.purchasePrice)} / carton',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
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
                            _sellingPrices.remove(id);
                            _purchasePrices.remove(id);
                            _productNames.remove(id);
                          }),
                  icon: Icon(
                    Icons.close_rounded,
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _QuantityField(
                    label: 'Loaded',
                    value: loaded,
                    min: 0,
                    onChanged: (value) {
                      setState(() {
                        _loaded[id] = value;
                        if ((_returned[id] ?? 0) > value) {
                          _returned[id] = value;
                        }
                      });
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _QuantityField(
                    label: 'Returned',
                    value: returned,
                    min: 0,
                    max: loaded,
                    onChanged: (value) =>
                        setState(() => _returned[id] = value),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _NumberInputField(
              label: 'Product discount',
              suffix: '%',
              value: _discounts[id] ?? 0,
              min: 0,
              max: 100,
              decimals: true,
              onChanged: (value) => setState(() => _discounts[id] = value),
            ),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$line.soldCartons sold',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Sell ${_money(line.grossValue)}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiscountSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: _ControllerNumberField(
                controller: _globalDiscountController,
                label: 'Global discount',
                suffix: '%',
                onChanged: (value) => setState(() =>
                    _globalDiscountPercent = value.clamp(0.0, 100.0).toDouble()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ControllerNumberField(
                controller: _globalDiscountEgpController,
                label: 'Global discount',
                suffix: 'EGP',
                onChanged: (value) => setState(
                  () => _globalDiscountEgp = value < 0 ? 0 : value,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummary() {
    if (_selectedProductIds.isEmpty) return const SizedBox.shrink();

    final trip = _buildTripOrNull();
    if (trip == null) {
      return const Card(
        child: ListTile(
          leading: Icon(Icons.info_outline_rounded),
          title: Text('Select Car and Warehouse'),
          subtitle: Text('Select both to preview the calculations.'),
        ),
      );
    }

    final summary = _calculator.summary(trip);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Calculation summary',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: 10),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 2.55,
              children: [
                CarMetricCard(
                  label: 'Loaded',
                  value: '${summary.totalLoadedCartons}',
                  icon: Icons.outbox_rounded,
                ),
                CarMetricCard(
                  label: 'Returned',
                  value: '${summary.totalReturnedCartons}',
                  icon: Icons.assignment_return_rounded,
                ),
                CarMetricCard(
                  label: 'Sold',
                  value: '${summary.totalSoldCartons}',
                  icon: Icons.point_of_sale_rounded,
                ),
                CarMetricCard(
                  label: 'Selling',
                  value: _money(summary.finalTotalSoldValue),
                  icon: Icons.receipt_long_outlined,
                ),
              ],
            ),
            const SizedBox(height: 10),
            _summaryRow('Product discounts', summary.productDiscountTotal),
            _summaryRow('Buying after product discounts', summary.subtotalAfterProducts),
            _summaryRow('Global % discount', summary.globalDiscountPercentAmount),
            _summaryRow('Global EGP discount', summary.globalDiscountFixedAmount),
            _summaryRow('Final buying cost', summary.totalPurchaseCost),
            const Divider(height: 18),
            _summaryRow('Profit', summary.profit, strong: true),
            _summaryRow('Selling total', summary.finalTotalSoldValue, strong: true),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(
    String label,
    CarMoney amount, {
    bool strong = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            _money(amount),
            style: TextStyle(
              fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _money(CarMoney value) =>
      'EGP ${value.units.toStringAsFixed(2)}';

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _ControllerNumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? suffix;
  final ValueChanged<double> onChanged;

  const _ControllerNumberField({
    required this.controller,
    required this.label,
    required this.onChanged,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: const OutlineInputBorder(),
      ),
      onChanged: (raw) {
        final parsed = double.tryParse(raw.trim());
        if (parsed != null) onChanged(parsed);
      },
    );
  }
}

class _NumberInputField extends StatefulWidget {
  final String label;
  final String? suffix;
  final double value;
  final double? min;
  final double? max;
  final bool decimals;
  final ValueChanged<double> onChanged;

  const _NumberInputField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.suffix,
    this.min,
    this.max,
    this.decimals = false,
  });

  @override
  State<_NumberInputField> createState() => _NumberInputFieldState();
}

class _NumberInputFieldState extends State<_NumberInputField> {
  late final TextEditingController _controller = TextEditingController(
    text: _format(widget.value),
  );

  @override
  void didUpdateWidget(covariant _NumberInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final parsed = double.tryParse(_controller.text.trim());
      if (parsed == null || parsed != widget.value) {
        _setText(widget.value);
      }
    }
  }

  String _format(double value) =>
      widget.decimals ? value.toStringAsFixed(2) : value.round().toString();

  void _setText(double value) {
    final next = _format(value);
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  void _emit(String raw) {
    final parsed = double.tryParse(raw.trim());
    if (parsed == null) return;
    var next = parsed;
    if (widget.min != null && next < widget.min!) next = widget.min!;
    if (widget.max != null && next > widget.max!) next = widget.max!;
    if (!widget.decimals) next = next.roundToDouble();
    widget.onChanged(next);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: TextInputType.numberWithOptions(decimal: widget.decimals),
      decoration: InputDecoration(
        labelText: widget.label,
        suffixText: widget.suffix,
        border: const OutlineInputBorder(),
      ),
      onChanged: _emit,
    );
  }
}

class _QuantityField extends StatefulWidget {
  final String label;
  final int value;
  final int min;
  final int? max;
  final ValueChanged<int> onChanged;

  const _QuantityField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max,
  });

  @override
  State<_QuantityField> createState() => _QuantityFieldState();
}

class _QuantityFieldState extends State<_QuantityField> {
  late final TextEditingController _controller =
      TextEditingController(text: '${widget.value}');

  @override
  void didUpdateWidget(covariant _QuantityField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final parsed = int.tryParse(_controller.text.trim());
      if (parsed == null || parsed != widget.value) {
        _setText(widget.value);
      }
    }
  }

  void _setText(int value) {
    final text = '$value';
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  int _clamp(int value) {
    var next = value < widget.min ? widget.min : value;
    final max = widget.max;
    if (max != null && next > max) next = max;
    return next;
  }

  void _emit(String raw) {
    final parsed = int.tryParse(raw.trim());
    if (parsed == null) return;
    widget.onChanged(_clamp(parsed));
  }

  void _increment() => widget.onChanged(
        _clamp(widget.value + 1),
      );

  void _decrement() => widget.onChanged(
        _clamp(widget.value - 1),
      );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecorator(
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      ),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            padding: EdgeInsets.zero,
            onPressed: widget.value > widget.min ? _decrement : null,
            icon: const Icon(Icons.remove_rounded, size: 19),
            color: scheme.primary,
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: _emit,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
            padding: EdgeInsets.zero,
            onPressed:
                widget.max == null || widget.value < widget.max! ? _increment : null,
            icon: const Icon(Icons.add_rounded, size: 19),
            color: scheme.primary,
          ),
        ],
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
