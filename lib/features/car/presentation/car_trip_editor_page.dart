import 'package:flutter/material.dart';

import '../../../core/repositories/app_services.dart';
import '../../../core/ui/dialogs.dart';
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
  late final CreateAndConfirmCarTrip _createAndConfirm = CreateAndConfirmCarTrip(_trips);
  late final UpdateCarTripDraft _update = UpdateCarTripDraft(_trips);
  late final ConfirmCarTrip _confirm = ConfirmCarTrip(_trips);
  late final ReviseCarTrip _revise = ReviseCarTrip(_trips);

  List<SalesCar> _cars = const [];
  List<Warehouse> _warehouses = const [];
  List<Product> _productsList = const [];

  SalesCar? _selectedCar;
  Warehouse? _selectedWarehouse;
  DateTime? _invoiceDate;
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
  final _globalPercentController = TextEditingController(text: '0');
  final _globalEgpController = TextEditingController(text: '0');

  bool get _editing => widget.tripId != null;
  List<int> get _selectedProductIds => _loaded.keys.toList(growable: false);

  @override
  void initState() {
    super.initState();
    _invoiceDate = DateTime.now();
    _load();
  }

  @override
  void dispose() {
    _globalPercentController.dispose();
    _globalEgpController.dispose();
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
        final opened = trip.openedAt.toLocal();
        _invoiceDate = DateTime(opened.year, opened.month, opened.day);
        _selectedCar = _cars.where((car) => car.id == trip.salesCarId).firstOrNull;
        _selectedWarehouse = _warehouses.where((warehouse) => warehouse.id == trip.warehouseId).firstOrNull;
        _dueDate = trip.dueDate?.toLocal();
        _displayNumber = trip.displayNumber;
        _globalDiscountPercent = trip.globalDiscountPercent;
        _globalDiscountEgp = trip.globalDiscountEgp.units;
        _globalPercentController.text = _formatInput(_globalDiscountPercent);
        _globalEgpController.text = _formatInput(_globalDiscountEgp);

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

  String _money(CarMoney value) => 'EGP ${value.units.toStringAsFixed(2)}';

  List<CarLoadItem> get _items => [for (final id in _selectedProductIds) _itemFor(id)];

  CarLoadItem _itemFor(int id) {
    final product = _productsList.firstWhere((item) => item.id == id);
    return CarLoadItem(
      productId: id,
      productName: _productNames[id] ?? product.name,
      unitPrice: _sellingPrices[id] ?? CarMoney.fromUnits(product.sellingPrice),
      purchasePrice: _purchasePrices[id] ?? CarMoney.fromUnits(product.purchasePrice),
      loadedCartons: _loaded[id] ?? 0,
      returnedCartons: _returned[id] ?? 0,
      discountPercent: _discounts[id] ?? 0,
    );
  }

  void _addProductsToTrip(Iterable<Product> products) {
    setState(() {
      for (final product in products) {
        _loaded[product.id] = _loaded[product.id] ?? 1;
        _returned[product.id] = _returned[product.id] ?? 0;
        _discounts[product.id] = _discounts[product.id] ?? 0;
        _sellingPrices[product.id] = _sellingPrices[product.id] ?? CarMoney.fromUnits(product.sellingPrice);
        _purchasePrices[product.id] = _purchasePrices[product.id] ?? CarMoney.fromUnits(product.purchasePrice);
        _productNames[product.id] = product.name;
      }
    });
  }

  Future<void> _addProduct() async {
    final result = await showModalBottomSheet<Object?>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CarProductPicker(
        products: _productsList,
        selectedIds: _selectedProductIds.toSet(),
      ),
    );

    if (!mounted || result == null) return;

    if (result is _CreateProductAction) {
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
      _addProductsToTrip([created]);
      return;
    }

    if (result is List<Product>) {
      _addProductsToTrip(result);
    }
  }

  CarTrip? _buildTripOrNull({bool closed = false}) {
    final car = _selectedCar;
    final warehouse = _selectedWarehouse;
    if (car == null || warehouse == null) return null;

    final now = DateTime.now().toUtc();
    final invoiceDate = _invoiceDate ?? now.toLocal();
    return CarTrip(
      id: _original?.id ?? 0,
      displayNumber: _displayNumber ?? _original?.displayNumber ?? '',
      salesCarId: car.id,
      salesCarName: car.name,
      warehouseId: warehouse.id,
      warehouseName: warehouse.name,
      openedAt: DateTime(
        invoiceDate.year,
        invoiceDate.month,
        invoiceDate.day,
      ).toUtc(),
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
    if (_invoiceDate == null) {
      _showError('Select an invoice date.');
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
          ? await _createAndConfirm(_buildTripOrNull()!, triggeredBy: 'invoice_close')
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
          MaterialPageRoute(builder: (_) => CarTripDetailsPage(tripId: persisted.id)),
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

  Future<void> _createCar() async {
    final controller = TextEditingController();
    try {
      final name = await _textDialog(title: 'New Car', label: 'Car name', controller: controller);
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
      final name = await _textDialog(title: 'New Warehouse', label: 'Warehouse name', controller: controller);
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
          decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: const Text('Create')),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
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
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _dropdown<Warehouse>(
                    label: 'Warehouse',
                    value: _selectedWarehouse,
                    items: _warehouses,
                    labelOf: (warehouse) => warehouse.name,
                    onChanged: (value) => setState(() => _selectedWarehouse = value),
                  ),
                ),
                IconButton(
                  tooltip: 'Create Warehouse',
                  onPressed: _saving ? null : _createWarehouse,
                  icon: const Icon(Icons.add_circle_outline_rounded),
                ),
              ],
            ),
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _saving ? null : _pickInvoiceDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Invoice date',
                  prefixIcon: Icon(Icons.receipt_long_outlined),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _invoiceDate == null ? 'Not specified' : _formatDate(_invoiceDate!),
                  style: TextStyle(
                    color: _invoiceDate == null ? scheme.onSurfaceVariant : scheme.onSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: _saving ? null : _pickDueDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Payment due date',
                  prefixIcon: Icon(Icons.event_outlined),
                  border: OutlineInputBorder(),
                ),
                child: Text(
                  _dueDate == null ? 'Not specified' : _formatDate(_dueDate!),
                  style: TextStyle(
                    color: _dueDate == null ? scheme.onSurfaceVariant : scheme.onSurface,
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
      decoration: const InputDecoration(border: OutlineInputBorder()).copyWith(labelText: label),
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

  Future<void> _pickInvoiceDate() async {
    final current = _invoiceDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDate: current,
    );
    if (picked != null && mounted) {
      setState(() {
        _invoiceDate = DateTime(picked.year, picked.month, picked.day);
      });
    }
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

  void _removeProduct(int id) {
    setState(() {
      _loaded.remove(id);
      _returned.remove(id);
      _discounts.remove(id);
      _sellingPrices.remove(id);
      _purchasePrices.remove(id);
      _productNames.remove(id);
    });
  }

  Widget _productCard(int id) {
    final product = _productsList.firstWhere((item) => item.id == id);
    final item = _itemFor(id);
    final line = _calculator.itemLine(item);
    final loaded = _loaded[id] ?? 0;
    final returned = _returned[id] ?? 0;
    final scheme = Theme.of(context).colorScheme;

    return _ExpandableProductCard(
      key: ValueKey(id),
      productName: _productNames[id] ?? product.name,
      category: product.category,
      buy: _money(item.purchasePrice),
      sell: _money(item.sellingPrice),
      loaded: loaded,
      returned: returned,
      discount: _discounts[id] ?? 0,
      cost: _money(line.purchaseCost),
      profit: _money(line.profitBeforeGlobalDiscount),
      discountAmount: _money(line.discountAmount),
      scheme: scheme,
      saving: _saving,
      onRemove: () => _removeProduct(id),
      onLoadedChanged: (value) => setState(() {
        _loaded[id] = value;
        if ((_returned[id] ?? 0) > value) _returned[id] = value;
      }),
      onReturnedChanged: (value) => setState(() => _returned[id] = value),
      onDiscountChanged: (value) => setState(() => _discounts[id] = value),
    );
  }

  Widget _buildDiscountSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 420;
            final fields = [
              _ControllerNumberField(
                controller: _globalPercentController,
                label: 'Global discount',
                suffix: '%',
                onChanged: (value) => setState(() => _globalDiscountPercent = value.clamp(0.0, 100.0).toDouble()),
              ),
              _ControllerNumberField(
                controller: _globalEgpController,
                label: 'Global discount',
                suffix: 'EGP',
                onChanged: (value) => setState(() => _globalDiscountEgp = value < 0 ? 0 : value),
              ),
            ];
            return compact
                ? Column(children: [fields[0], const SizedBox(height: 10), fields[1]])
                : Row(children: [Expanded(child: fields[0]), const SizedBox(width: 10), Expanded(child: fields[1])]);
          },
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
              child: Text('Calculation summary', style: Theme.of(context).textTheme.titleLarge),
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
                CarMetricCard(label: 'Loaded', value: '${summary.totalLoadedCartons}', icon: Icons.outbox_rounded),
                CarMetricCard(label: 'Returned', value: '${summary.totalReturnedCartons}', icon: Icons.assignment_return_rounded),
                CarMetricCard(label: 'Sold', value: '${summary.totalSoldCartons}', icon: Icons.point_of_sale_rounded),
                CarMetricCard(label: 'Selling', value: _money(summary.finalTotalSoldValue), icon: Icons.receipt_long_outlined),
              ],
            ),
            const SizedBox(height: 10),
            _summaryRow('Product discounts', summary.productDiscountTotal),
            _summaryRow('Buying after product discounts', summary.subtotalAfterProducts),
            _summaryRow('Global % discount', summary.globalDiscountPercentAmount),
            _summaryRow('Global EGP discount', summary.globalDiscountFixedAmount),
            _summaryRow('Final buying cost', summary.totalPurchaseCost, strong: true),
            const Divider(height: 18),
            _summaryRow('Profit', summary.profit, strong: true),
            _summaryRow('Selling total', summary.finalTotalSoldValue),
          ],
        ),
      ),
    );
  }

  Widget _summaryRow(String label, CarMoney amount, {bool strong = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: TextStyle(fontWeight: strong ? FontWeight.w800 : FontWeight.w500)),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              _money(amount),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(fontWeight: strong ? FontWeight.w900 : FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 150),
        children: [
          _buildHeader(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text('Products', style: Theme.of(context).textTheme.titleLarge),
              ),
              FilledButton.tonalIcon(
                onPressed: _saving ? null : _addProduct,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(_selectedProductIds.isEmpty ? 'Add products' : 'Add more'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (_selectedProductIds.isEmpty)
            const Card(
              child: ListTile(
                leading: Icon(Icons.inventory_2_outlined),
                title: Text('No products yet'),
                subtitle: Text('Tap Add products to browse by category.'),
              ),
            )
          else
            for (final id in _selectedProductIds) _productCard(id),
          const SizedBox(height: 6),
          _buildDiscountSection(),
          const SizedBox(height: 14),
          _buildSummary(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 520;
            final draft = OutlinedButton(
              onPressed: _saving ? null : _saveDraft,
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              child: const Text('Save draft'),
            );
            final confirm = FilledButton.icon(
              onPressed: _saving ? null : _confirmAndClose,
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              icon: _saving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.check_circle_outline_rounded),
              label: Text(_saving ? 'Processing...' : 'Confirm & close'),
            );

            return compact
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(width: double.infinity, child: confirm),
                      const SizedBox(height: 8),
                      SizedBox(width: double.infinity, child: draft),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: draft),
                      const SizedBox(width: 10),
                      Expanded(flex: 2, child: confirm),
                    ],
                  );
          },
        ),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _CarProductPicker extends StatefulWidget {
  final List<Product> products;
  final Set<int> selectedIds;

  const _CarProductPicker({required this.products, required this.selectedIds});

  @override
  State<_CarProductPicker> createState() => _CarProductPickerState();
}

class _CarProductPickerState extends State<_CarProductPicker> {
  final _searchController = TextEditingController();
  late final Set<int> _selectedIds = {...widget.selectedIds};
  final Set<String> _expandedCategories = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_refresh);
  }

  @override
  void dispose() {
    _searchController.removeListener(_refresh);
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  List<Product> get _filteredProducts {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return widget.products;
    return widget.products.where((product) {
      return product.name.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query);
    }).toList(growable: false);
  }

  Map<String, List<Product>> get _groups {
    final result = <String, List<Product>>{};
    for (final product in _filteredProducts) {
      result.putIfAbsent(product.category, () => []).add(product);
    }
    final entries = result.entries.toList()
      ..sort((a, b) => a.key.toLowerCase().compareTo(b.key.toLowerCase()));
    return {for (final entry in entries) entry.key: entry.value};
  }

  void _toggleCategory(String category, bool expanded) {
    setState(() {
      if (expanded) {
        _expandedCategories.add(category);
      } else {
        _expandedCategories.remove(category);
      }
    });
  }

  void _toggleProduct(Product product) {
    setState(() {
      if (_selectedIds.contains(product.id)) {
        _selectedIds.remove(product.id);
      } else {
        _selectedIds.add(product.id);
      }
    });
  }

  void _selectCategory(List<Product> products) {
    setState(() {
      final ids = products.map((p) => p.id).toSet();
      if (ids.every(_selectedIds.contains)) {
        _selectedIds.removeAll(ids);
      } else {
        _selectedIds.addAll(ids);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final groups = _groups;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: .82,
          minChildSize: .55,
          maxChildSize: .96,
          builder: (context, scrollController) {
            return Material(
              color: scheme.surface,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Add products', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
                              const SizedBox(height: 2),
                              Text('${_selectedIds.length} selected · choose by category', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.close_rounded),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search products or categories',
                        prefixIcon: const Icon(Icons.search_rounded),
                        suffixIcon: _searchController.text.isEmpty
                            ? null
                            : IconButton(
                                onPressed: _searchController.clear,
                                icon: const Icon(Icons.clear_rounded),
                              ),
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: groups.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('No products found.'),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            itemCount: groups.length + 1,
                            itemBuilder: (context, index) {
                              if (index == groups.length) {
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6, bottom: 2),
                                  child: ListTile(
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    tileColor: scheme.surfaceContainerHighest,
                                    leading: const Icon(Icons.inventory_2_outlined),
                                    title: const Text('Create a new product', style: TextStyle(fontWeight: FontWeight.w800)),
                                    subtitle: const Text('Add it to the local catalog'),
                                    trailing: const Icon(Icons.chevron_right_rounded),
                                    onTap: () => Navigator.of(context).pop(_CreateProductAction.create),
                                  ),
                                );
                              }

                              final entry = groups.entries.elementAt(index);
                              final category = entry.key;
                              final products = entry.value;
                              final selectedCount = products.where((product) => _selectedIds.contains(product.id)).length;
                              final allSelected = selectedCount == products.length && products.isNotEmpty;
                              final isExpanded = _searchController.text.trim().isNotEmpty || _expandedCategories.contains(category);

                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                clipBehavior: Clip.antiAlias,
                                child: ExpansionTile(
                                  initiallyExpanded: isExpanded,
                                  onExpansionChanged: (expanded) => _toggleCategory(category, expanded),
                                  title: Row(
                                    children: [
                                      Expanded(
                                        child: Text(category, style: const TextStyle(fontWeight: FontWeight.w900)),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: selectedCount > 0 ? scheme.primaryContainer : scheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: Text(
                                          '$selectedCount/${products.length}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w900,
                                            color: selectedCount > 0 ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      IconButton(
                                        tooltip: allSelected ? 'Clear category' : 'Select category',
                                        onPressed: () => _selectCategory(products),
                                        icon: Icon(allSelected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, size: 21),
                                      ),
                                    ],
                                  ),
                                  children: [
                                    for (final product in products)
                                      _PickerProductTile(
                                        product: product,
                                        selected: _selectedIds.contains(product.id),
                                        onTap: () => _toggleProduct(product),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      border: Border(top: BorderSide(color: scheme.outlineVariant)),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _selectedIds.isEmpty ? null : () => setState(_selectedIds.clear),
                            child: const Text('Clear selection'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            onPressed: _selectedIds.isEmpty
                                ? null
                                : () {
                                    final products = widget.products.where((p) => _selectedIds.contains(p.id)).toList(growable: false);
                                    Navigator.of(context).pop(products);
                                  },
                            icon: const Icon(Icons.playlist_add_rounded),
                            label: Text('Add ${_selectedIds.length} product${_selectedIds.length == 1 ? '' : 's'}'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PickerProductTile extends StatelessWidget {
  final Product product;
  final bool selected;
  final VoidCallback onTap;

  const _PickerProductTile({required this.product, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 2, 10, 2),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    'Buy ${product.purchasePrice.toStringAsFixed(2)} · Sell ${product.sellingPrice.toStringAsFixed(2)} EGP/carton',
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (selected) Icon(Icons.done_rounded, color: scheme.primary, size: 19),
          ],
        ),
      ),
    );
  }
}

class _ExpandableProductCard extends StatefulWidget {
  final String productName;
  final String category;
  final String buy;
  final String sell;
  final int loaded;
  final int returned;
  final double discount;
  final String cost;
  final String profit;
  final String discountAmount;
  final ColorScheme scheme;
  final bool saving;
  final VoidCallback onRemove;
  final ValueChanged<int> onLoadedChanged;
  final ValueChanged<int> onReturnedChanged;
  final ValueChanged<double> onDiscountChanged;

  const _ExpandableProductCard({
    super.key,
    required this.productName,
    required this.category,
    required this.buy,
    required this.sell,
    required this.loaded,
    required this.returned,
    required this.discount,
    required this.cost,
    required this.profit,
    required this.discountAmount,
    required this.scheme,
    required this.saving,
    required this.onRemove,
    required this.onLoadedChanged,
    required this.onReturnedChanged,
    required this.onDiscountChanged,
  });

  @override
  State<_ExpandableProductCard> createState() => _ExpandableProductCardState();
}

class _ExpandableProductCardState extends State<_ExpandableProductCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.productName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                            ),
                          ),
                          if (widget.category.trim().isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              constraints: const BoxConstraints(maxWidth: 110),
                              decoration: BoxDecoration(
                                color: widget.scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(widget.category, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10, color: widget.scheme.onSurfaceVariant, fontWeight: FontWeight.w700)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${widget.buy} buy · ${widget.sell} sell / carton',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: widget.scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remove product',
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.saving ? null : widget.onRemove,
                  icon: Icon(Icons.close_rounded, color: widget.scheme.error, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: _QuantityField(
                    label: 'Loaded',
                    value: widget.loaded,
                    onChanged: widget.onLoadedChanged,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${widget.loaded - widget.returned} sold', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                      const SizedBox(height: 3),
                      Text(widget.profit, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: widget.scheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: widget.scheme.tertiary,
                ),
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(_expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded, size: 18),
                label: Text(_expanded ? 'See less' : 'See more', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
              ),
            ),
            if (_expanded) ...[
              Divider(height: 12, color: widget.scheme.outlineVariant),
              Row(
                children: [
                  Expanded(
                    child: _QuantityField(
                      label: 'Returned',
                      value: widget.returned,
                      max: widget.loaded,
                      onChanged: widget.onReturnedChanged,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _NumberInputField(
                      label: 'Discount',
                      suffix: '%',
                      value: widget.discount,
                      min: 0,
                      max: 100,
                      onChanged: widget.onDiscountChanged,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: widget.scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Wrap(
                  spacing: 14,
                  runSpacing: 5,
                  children: [
                    _MiniMetric(label: 'Discount', value: widget.discountAmount),
                    _MiniMetric(label: 'Cost', value: widget.cost),
                    _MiniMetric(label: 'Profit', value: widget.profit),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;

  const _MiniMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label $value',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Theme.of(context).colorScheme.onSurfaceVariant),
    );
  }
}

class _ControllerNumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? suffix;
  final ValueChanged<double> onChanged;

  const _ControllerNumberField({required this.controller, required this.label, required this.onChanged, this.suffix});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label, suffixText: suffix, border: const OutlineInputBorder()),
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
  final ValueChanged<double> onChanged;

  const _NumberInputField({required this.label, required this.value, required this.onChanged, this.suffix, this.min, this.max});

  @override
  State<_NumberInputField> createState() => _NumberInputFieldState();
}

class _NumberInputFieldState extends State<_NumberInputField> {
  late final TextEditingController _controller = TextEditingController(text: _format(widget.value));

  @override
  void didUpdateWidget(covariant _NumberInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final current = double.tryParse(_controller.text.trim());
      if (current == null || current != widget.value) _setText(widget.value);
    }
  }

  String _format(double value) => value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

  void _setText(double value) {
    final next = _format(value);
    _controller.value = TextEditingValue(text: next, selection: TextSelection.collapsed(offset: next.length));
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
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: widget.label, suffixText: widget.suffix, border: const OutlineInputBorder()),
      onChanged: (raw) {
        final parsed = double.tryParse(raw.trim());
        if (parsed == null) return;
        var next = parsed;
        if (widget.min != null && next < widget.min!) next = widget.min!;
        if (widget.max != null && next > widget.max!) next = widget.max!;
        widget.onChanged(next);
      },
    );
  }
}

class _QuantityField extends StatefulWidget {
  final String label;
  final int value;
  final int? max;
  final ValueChanged<int> onChanged;

  const _QuantityField({required this.label, required this.value, required this.onChanged, this.max});

  @override
  State<_QuantityField> createState() => _QuantityFieldState();
}

class _QuantityFieldState extends State<_QuantityField> {
  late final TextEditingController _controller = TextEditingController(text: '${widget.value}');

  @override
  void didUpdateWidget(covariant _QuantityField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final current = int.tryParse(_controller.text.trim());
      if (current == null || current != widget.value) _setText(widget.value);
    }
  }

  void _setText(int value) {
    final next = '$value';
    _controller.value = TextEditingValue(text: next, selection: TextSelection.collapsed(offset: next.length));
  }

  int _clamp(int value) {
    var next = value < 0 ? 0 : value;
    if (widget.max != null && next > widget.max!) next = widget.max!;
    return next;
  }

  void _emit(String raw) {
    final parsed = int.tryParse(raw.trim());
    if (parsed == null) return;
    widget.onChanged(_clamp(parsed));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      ),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 33, height: 33),
            padding: EdgeInsets.zero,
            onPressed: widget.value > 0 ? () => widget.onChanged(widget.value - 1) : null,
            icon: const Icon(Icons.remove_rounded, size: 18),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
              onChanged: _emit,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 33, height: 33),
            padding: EdgeInsets.zero,
            onPressed: widget.max == null || widget.value < widget.max! ? () => widget.onChanged(widget.value + 1) : null,
            icon: const Icon(Icons.add_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
