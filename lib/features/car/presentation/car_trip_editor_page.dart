import 'package:flutter/material.dart';

import '../../../core/repositories/app_services.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/ui/dialogs.dart';
import '../../products/presentation/products_page.dart';
import '../../products/domain/product.dart';
import '../application/usecases/confirm_car_trip.dart';
import '../application/usecases/create_car_trip.dart';
import '../application/usecases/revise_car_trip.dart';
import '../application/usecases/update_car_trip_draft.dart';
import '../domain/entities/car_financial_summary.dart';
import '../domain/entities/car_load_item.dart';
import '../domain/entities/car_trip.dart';
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

  final Map<int, int> _loaded = {};
  final Map<int, int> _returned = {};
  final Map<int, double> _discounts = {};

  bool _loading = true;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.tripId != null;
  CarTrip? _original;

  @override
  void initState() {
    super.initState();
    _load();
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
        _selectedWarehouse = _warehouses.where((w) => w.id == trip.warehouseId).firstOrNull;
        _dueDate = trip.dueDate?.toLocal();
        _displayNumber = trip.displayNumber;
        _globalDiscountPercent = trip.globalDiscountPercent;
        _globalDiscountController.text = trip.globalDiscountPercent.toStringAsFixed(2);
        for (final item in trip.items) {
          _loaded[item.productId] = item.loadedCartons;
          _returned[item.productId] = item.returnedCartons;
          _discounts[item.productId] = item.discountPercent;
        }
      }

      if (!_editing && _selectedCar == null && _cars.length == 1) _selectedCar = _cars.first;
      if (!_editing && _selectedWarehouse == null && _warehouses.length == 1) _selectedWarehouse = _warehouses.first;

      if (!mounted) return;
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() { _loading = false; _error = '$error'; });
    }
  }

  Future<void> _reloadProducts() async {
    _productsList = await _products.getProducts();
    if (mounted) setState(() {});
  }

  List<int> get _selectedProductIds => _loaded.keys.toList(growable: false);

  List<CarLoadItem> get _items => [for (final id in _selectedProductIds) _itemFor(id)];

  CarLoadItem _itemFor(int id) {
    final product = _productsList.firstWhere((p) => p.id == id);
    return CarLoadItem(
      productId: id,
      productName: product.name,
      unitPrice: CarMoney.fromUnits(product.price),
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

  static const _openStatus = CarTripStatus.open;
  static const _closedStatus = CarTripStatus.closed;

  double _globalDiscountPercent = 0;
  final _globalDiscountController = TextEditingController(text: '0');

  @override
  void dispose() {
    _globalDiscountController.dispose();
    super.dispose();
  }

  Future<void> _saveDraft() async {
    if (_saving) return;
    if (!_validateHeader()) return;
    setState(() => _saving = true);
    try {
      final trip = _buildTrip(closed: false);
      final saved = _editing ? await _update(trip) : await _create(trip);
      _original = saved;
      _displayNumber = saved.displayNumber;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Draft ${saved.displayNumber} saved.')));
        if (!_editing) { Navigator.of(context).pop(true); return; }
      }
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _confirmAndClose() async {
    if (_saving) return;
    if (!_validateHeader()) return;
    final trip = _buildTrip(closed: true);
    final issues = _calculator.validate(trip);
    if (issues.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(issues.first.message)));
      return;
    }
    final confirmed = await showConfirmDialog(
      context: context,
      title: 'Confirm Car invoice?',
      message: 'This will finalize the daily load/return calculation and create an immutable historical revision.',
      confirmLabel: 'Confirm',
    );
    if (!confirmed || !mounted) return;

    setState(() => _saving = true);
    try {
      final persisted = !_editing
          ? await _createAndConfirmNew(trip)
          : _original!.isClosed
              ? await _revise(trip, triggeredBy: 'invoice_edit')
              : await _confirm(trip, triggeredBy: 'invoice_close');
      final summary = _calculator.summary(persisted);
      if (!mounted) return;
      await Navigator.of(context).push(PageRouteBuilder(
        opaque: true,
        pageBuilder: (_, __, ___) => CarClosingAnimation(displayNumber: persisted.displayNumber, summary: summary),
        transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 180),
      ));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<CarTrip> _createAndConfirmNew(CarTrip trip) async {
    final draft = await _create(trip.copyWith(status: CarTripStatus.open));
    return _confirm(trip.copyWith(id: draft.id, displayNumber: draft.displayNumber));
  }

  bool _validateHeader() {
    if (_selectedCar == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a Car.'))); return false; }
    if (_selectedWarehouse == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a Warehouse.'))); return false; }
    if (_items.isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one product.'))); return false; }
    return true;
  }

  Future<void> _addProduct() async {
    final available = _productsList.where((p) => !_loaded.containsKey(p.id)).toList(growable: false);
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All available products are already on this Car invoice.')));
      return;
    }
    final chosen = await showModalBottomSheet<Product>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const ListTile(title: Text('Add product'), subtitle: Text('Select a product for this Car load')),
            for (final product in available)
              ListTile(
                title: Text(product.name),
                subtitle: Text('${product.price.toStringAsFixed(2)} EGP / carton'),
                trailing: const Icon(Icons.add_rounded),
                onTap: () => Navigator.of(context).pop(product),
              ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.inventory_2_outlined),
              title: const Text('Create a new product'),
              onTap: () async {
                Navigator.of(context).pop();
                await Navigator.of(this.context).push(MaterialPageRoute(builder: (_) => const ProductsPage()));
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
    });
  }

  Future<void> _createCar() async {
    final controller = TextEditingController();
    try {
      final name = await _simpleTextDialog(title: 'New Car', label: 'Car name', controller: controller);
      if (name == null || name.trim().isEmpty) return;
      final car = await _catalog.createCar(SalesCar(name: name.trim(), createdAt: DateTime.now().toUtc()));
      _cars = [..._cars, car]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (mounted) setState(() => _selectedCar = car);
    } finally { controller.dispose(); }
  }

  Future<void> _createWarehouse() async {
    final controller = TextEditingController();
    try {
      final name = await _simpleTextDialog(title: 'New Warehouse', label: 'Warehouse name', controller: controller);
      if (name == null || name.trim().isEmpty) return;
      final warehouse = await _catalog.createWarehouse(Warehouse(name: name.trim(), createdAt: DateTime.now().toUtc()));
      _warehouses = [..._warehouses, warehouse]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (mounted) setState(() => _selectedWarehouse = warehouse);
    } finally { controller.dispose(); }
  }

  Future<String?> _simpleTextDialog({required String title, required String label, required TextEditingController controller}) {
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(controller: controller, autofocus: true, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()), textCapitalization: TextCapitalization.words),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: const Text('Create')),
        ],
      ),
    );
  }

  String _money(CarMoney value) => 'EGP ${value.units.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Car invoice')),
        body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline_rounded, size: 48),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: _load, child: const Text('Retry')),
        ]))),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit Car Invoice' : 'New Car Invoice')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 140),
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          Row(children: [Expanded(child: Text('Products', style: Theme.of(context).textTheme.titleLarge)), TextButton.icon(onPressed: _addProduct, icon: const Icon(Icons.add_rounded), label: const Text('Add product'))]),
          const SizedBox(height: 8),
          if (_selectedProductIds.isEmpty)
            Card(child: ListTile(leading: const Icon(Icons.inventory_2_outlined), title: const Text('No products yet'), subtitle: const Text('Add cartons loaded on the Car.')))
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
        child: Row(children: [
          Expanded(child: OutlinedButton(onPressed: _saving ? null : _saveDraft, style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)), child: const Text('Save draft'))),
          const SizedBox(width: 10),
          Expanded(flex: 2, child: FilledButton.icon(onPressed: _saving ? null : _confirmAndClose, style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)), icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.check_rounded), label: Text(_saving ? 'Saving...' : 'Confirm & close'))),
        ]),
      ),
    );
  }

  Widget _buildHeader() => AppCard(child: Row(children: [
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Car & warehouse', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
      const SizedBox(height: 10),
      DropdownButtonFormField<SalesCar>(
        value: _selectedCar,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Car', border: OutlineInputBorder()),
        items: [for (final car in _cars) DropdownMenuItem(value: car, child: Text(car.name))],
        onChanged: (value) => setState(() => _selectedCar = value),
      ),
      const SizedBox(height: 10),
      DropdownButtonFormField<Warehouse>(
        value: _selectedWarehouse,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Warehouse', border: OutlineInputBorder()),
        items: [for (final warehouse in _warehouses) DropdownMenuItem(value: warehouse, child: Text(warehouse.name))],
        onChanged: (value) => setState(() => _selectedWarehouse = value),
      ),
      const SizedBox(height: 10),
      OutlinedButton.icon(onPressed: _createCar, icon: const Icon(Icons.local_shipping_outlined), label: const Text('New Car')),
      OutlinedButton.icon(onPressed: _createWarehouse, icon: const Icon(Icons.warehouse_outlined), label: const Text('New Warehouse')),
    ])),
  ]));

  Widget _productCard(int id) {
    final product = _productsList.firstWhere((p) => p.id == id);
    final loaded = _loaded[id] ?? 0;
    final returned = _returned[id] ?? 0;
    final discount = _discounts[id] ?? 0;
    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Expanded(child: Text(product.name, style: const TextStyle(fontWeight: FontWeight.w800))), IconButton(onPressed: () => setState(() { _loaded.remove(id); _returned.remove(id); _discounts.remove(id); }), icon: const Icon(Icons.close_rounded))]),
        Text('${_money(CarMoney.fromUnits(product.price))} / carton'),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _counter(label: 'Loaded', value: loaded, onMinus: loaded <= 0 ? null : () => setState(() => _loaded[id] = loaded - 1), onPlus: () => setState(() => _loaded[id] = loaded + 1))),
          const SizedBox(width: 12),
          Expanded(child: _counter(label: 'Returned', value: returned, onMinus: returned <= 0 ? null : () => setState(() => _returned[id] = returned - 1), onPlus: returned >= loaded ? null : () => setState(() => _returned[id] = returned + 1))),
        ]),
        const SizedBox(height: 10),
        TextFormField(
          initialValue: discount.toStringAsFixed(2),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Product discount %', border: OutlineInputBorder()),
          onChanged: (value) => setState(() => _discounts[id] = double.tryParse(value) ?? 0),
        ),
      ]),
    );
  }

  Widget _counter({required String label, required int value, required VoidCallback? onMinus, required VoidCallback? onPlus}) =>
      Row(children: [
        IconButton(onPressed: onMinus, icon: const Icon(Icons.remove_circle_outline_rounded)),
        Expanded(child: Column(children: [Text('$value', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)), Text(label, style: const TextStyle(fontSize: 11))])),
        IconButton(onPressed: onPlus, icon: const Icon(Icons.add_circle_outline_rounded)),
      ]);

  Widget _buildDiscountSection() => AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Global discount', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
    const SizedBox(height: 10),
    TextField(controller: _globalDiscountController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Discount %', border: OutlineInputBorder()), onChanged: (value) => setState(() => _globalDiscountPercent = double.tryParse(value) ?? 0)),
  ]));

  Widget _buildSummary() {
    if (_selectedCar == null || _selectedWarehouse == null || _items.isEmpty) return const SizedBox.shrink();
    final trip = _buildTrip(closed: false);
    final summary = _calculator.summary(trip);
    return CarMetricCard(
      label: 'Final sold value',
      value: _money(summary.finalTotalSoldValue),
      icon: Icons.point_of_sale_rounded,
    );
  }
}
