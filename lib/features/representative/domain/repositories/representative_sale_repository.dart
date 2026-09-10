import '../../../customers/domain/payment_method.dart';
import '../entities/representative_customer.dart';

abstract interface class RepresentativeSaleRepository {
  Future<List<RepresentativeCustomer>> fetchCustomers({String search = ''});

  Future<int> createAndConfirmSale({
    required int customerId,
    required Map<int, int> quantities,
    required PaymentMethod paymentMethod,
    required double paymentAmount,
  });
}
