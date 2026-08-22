import '../../customers/domain/payment_method.dart';
import 'payment.dart';

abstract interface class PaymentRepository {
  Future<int> createPayment({
    required int customerId,
    required int invoiceId,
    required double amount,
    required PaymentMethod method,
    String? reference,
  });

  Future<void> confirmTransfer(
    int paymentId,
  );

  Future<List<Payment>> getPayments();

  Future<List<Payment>> getPendingTransfers();

  Future<List<Payment>> getPaymentsForCustomer(
    int customerId,
  );

  Future<List<Payment>> getPaidPaymentsForCustomer(
    int customerId,
  );

  Future<double> getPaidPaymentsTotal(
    int customerId,
  );

  Future<double> getPendingTransfersTotal(
    int customerId,
  );

  Future<double> getPaidCashTotal(
    int customerId,
  );

  Future<double> getPaidTransferTotal(
    int customerId,
  );
}

