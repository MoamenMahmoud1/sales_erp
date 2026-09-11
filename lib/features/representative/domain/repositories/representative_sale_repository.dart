import '../../../customers/domain/payment_method.dart';
import '../entities/representative_customer.dart';

class RepresentativeSaleSubmission {
  final int? invoiceId;
  final bool queued;
  final String operationKey;

  const RepresentativeSaleSubmission({
    required this.invoiceId,
    required this.queued,
    required this.operationKey,
  });

  const RepresentativeSaleSubmission.completed(int invoiceId, String operationKey)
      : this(invoiceId: invoiceId, queued: false, operationKey: operationKey);

  const RepresentativeSaleSubmission.queued(String operationKey)
      : this(invoiceId: null, queued: true, operationKey: operationKey);
}

abstract interface class RepresentativeSaleRepository {
  Future<List<RepresentativeCustomer>> fetchCustomers({String search = ''});

  Future<RepresentativeSaleSubmission> createAndConfirmSale({
    required int customerId,
    required Map<int, int> quantities,
    required PaymentMethod paymentMethod,
    required double paymentAmount,
  });
}
