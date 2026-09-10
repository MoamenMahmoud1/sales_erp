import 'package:flutter/foundation.dart';

import '../../../customers/domain/payment_method.dart';
import '../domain/entities/representative_customer.dart';
import '../domain/entities/vehicle_stock_item.dart';
import '../domain/repositories/representative_sale_repository.dart';

class RepresentativeSaleController extends ChangeNotifier {
  final RepresentativeSaleRepository repository;

  RepresentativeSaleController({required this.repository});

  List<RepresentativeCustomer> _customers = const [];
  List<VehicleStockItem> _vehicleStock = const [];
  final Map<int, int> _quantities = {};
  RepresentativeCustomer? _selectedCustomer;
  PaymentMethod _paymentMethod = PaymentMethod.cash;
  double _paymentAmount = 0;
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  List<RepresentativeCustomer> get customers => _customers;
  List<VehicleStockItem> get vehicleStock => _vehicleStock;
  RepresentativeCustomer? get selectedCustomer => _selectedCustomer;
  PaymentMethod get paymentMethod => _paymentMethod;
  double get paymentAmount => _paymentAmount;
  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;

  Map<int, int> get quantities => Map.unmodifiable(_quantities);

  double get totalAmount {
    return _vehicleStock.fold<double>(
      0,
      (total, item) => total + (double.tryParse(item.sellingPrice) ?? 0) * (_quantities[item.productId] ?? 0),
    );
  }

  double get remainingAfterPayment {
    final remaining = totalAmount - _paymentAmount;
    return remaining > 0 ? remaining : 0;
  }

  bool get canSubmit {
    if (_selectedCustomer == null || _quantities.isEmpty || _isSubmitting) return false;
    if (!_paymentAmount.isFinite || _paymentAmount < 0) return false;
    return _paymentAmount <= totalAmount;
  }

  Future<void> load({required List<VehicleStockItem> vehicleStock}) async {
    _isLoading = true;
    _errorMessage = null;
    _vehicleStock = List.unmodifiable(vehicleStock);
    _quantities.clear();
    notifyListeners();

    try {
      _customers = List.unmodifiable(await repository.fetchCustomers());
    } catch (error) {
      _errorMessage = error.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void selectCustomer(RepresentativeCustomer? customer) {
    _selectedCustomer = customer;
    notifyListeners();
  }

  void setPaymentMethod(PaymentMethod method) {
    _paymentMethod = method;
    notifyListeners();
  }

  void setPaymentAmount(double amount) {
    _paymentAmount = amount.isFinite && amount >= 0 ? amount : 0;
    notifyListeners();
  }

  void setQuantity(int productId, int quantity) {
    final stockItem = _vehicleStock.firstWhere(
      (item) => item.productId == productId,
      orElse: () => throw StateError('Product is not available in the vehicle.'),
    );
    if (quantity <= 0) {
      _quantities.remove(productId);
    } else {
      _quantities[productId] = quantity.clamp(1, stockItem.quantity).toInt();
    }
    if (_paymentAmount > totalAmount) {
      _paymentAmount = totalAmount;
    }
    notifyListeners();
  }

  void fillFullPayment() {
    _paymentAmount = totalAmount;
    notifyListeners();
  }

  Future<int?> submit() async {
    if (!canSubmit) return null;

    _isSubmitting = true;
    _errorMessage = null;
    notifyListeners();

    try {
      return await repository.createAndConfirmSale(
        customerId: _selectedCustomer!.id,
        quantities: Map.of(_quantities),
        paymentMethod: _paymentMethod,
        paymentAmount: _paymentAmount,
      );
    } catch (error) {
      _errorMessage = error.toString();
      return null;
    } finally {
      _isSubmitting = false;
      notifyListeners();
    }
  }
}
