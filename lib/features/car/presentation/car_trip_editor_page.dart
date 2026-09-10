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

part 'parts/car_trip_editor_product_picker.dart';
part 'parts/car_trip_editor_product_widgets.dart';

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
  List<int> get _selectedProductIds =>
      _loaded.keys.toList(growable: false);

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
        _selectedCar =
            _cars.where((car) => car.id == trip.salesCarId).firstOrNull;
        _selectedWarehouse = _warehouses
            .where((warehouse) => warehouse.id == trip.warehouseId)
            .firstOrNull;
        _dueDate = trip.dueDate?.toLocal();
        _displayNumber = trip.displayNumber;
        _globalDiscountPercent = trip.globalDiscountPercent;
        _globalDiscountEgp = trip.globalDiscountEgp.units;
        _globalPercentController.text =
            _formatInput(_globalDiscountPercent);
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

  String _money(CarMoney value) =>
      'EGP ${value.units.toStringAsFixed(2)}';

  List<CarLoadItem> get _items =>
      [for (final id in _selectedProductIds) _itemFor(id)];

  CarLoadItem _itemFor(int id) {
    final product = _productsList.firstWhere((item) => item.id == id);
    return CarLoadItem(
      productId: id,
      productName: _productNames[id] ?? product.name,
      unitPrice: _sellingPrices[id] ?? CarMoney.fromUnits(product.sellingPrice),
      purchasePrice:
          _purchasePrices[id] ?? CarMoney.fromUnits(product.purchasePrice),
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
        _sellingPrices[product.id] =
            _sellingPrices[product.id] ?? CarMoney.fromUnits(product.sellingPrice);
        _purchasePrices[product.id] =
            _purchasePrices[product.id] ?? CarMoney.fromUnits(product.purchasePrice);
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
                  _invoiceDate == null
                      ? 'Not specified'
                      : _formatDate(_invoiceDate!),
                  style: TextStyle(
                    color: _invoiceDate == null
                        ? scheme.onSurfaceVariant
                        : scheme.onSurface,
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
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
      ).copyWith(labelText: label),
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
                onChanged: (value) => setState(
                  () => _globalDiscountPercent =
                      value.clamp(0.0, 100.0).toDouble(),
                ),
              ),
              _ControllerNumberField(
                controller: _globalEgpController,
                label: 'Global discount',
                suffix: 'EGP',
                onChanged: (value) => setState(
                  () => _globalDiscountEgp = value < 0 ? 0 : value,
                ),
              ),
            ];
            return compact
                ? Column(
                    children: [
                      fields[0],
                      const SizedBox(height: 10),
                      fields[1],
                    ],
                  )
                : Row(
                    children: [
                      Expanded(child: fields[0]),
                      const SizedBox(width: 10),
                      Expanded(child: fields[1]),
                    ],
                  );
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
            _summaryRow(
              'Buying after product discounts',
              summary.subtotalAfterProducts,
            ),
            _summaryRow(
              'Global % discount',
              summary.globalDiscountPercentAmount,
            ),
            _summaryRow(
              'Global EGP discount',
              summary.globalDiscountFixedAmount,
            ),
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
            child: Text(
              label,
              style: TextStyle(
                fontWeight: strong ? FontWeight.w800 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              _money(amount),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.end,
              style: TextStyle(
                fontWeight: strong ? FontWeight.w900 : FontWeight.w700,
              ),
            ),
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
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 150),
        children: [
          _buildHeader(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Products',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: _saving ? null : _addProduct,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(
                  _selectedProductIds.isEmpty ? 'Add products' : 'Add more',
                ),
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
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              child: const Text('Save draft'),
            );
            final confirm = FilledButton.icon(
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
