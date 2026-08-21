import 'invoice.dart';
import 'invoice_change.dart';
import 'payment_record.dart';
import 'customer_financial_summary.dart';
import '../../customers/domain/payment_method.dart';

abstract interface class SaleRepository {
  Future<int> createInvoice({
    required int customerId,
    required Map<int, int> products,
    required PaymentMethod paymentMethod,
    double couponDiscount,
  });

  Future<List<Map<String, Object?>>>
      getCustomerInvoices(
    int customerId,
  );

  Future<Invoice?> getInvoice(
    int invoiceId,
  );

  Future<void> updateInvoice({
    required int invoiceId,
    required Map<int, int> products,
  });

  Future<void> deleteInvoice(
    int invoiceId,
  );

  Future<List<InvoiceChange>>
      getRecentInvoiceChanges(
    int invoiceId,
  );

  Future<List<PaymentRecord>>
      getPendingTransfers();

  Future<void> confirmTransfer(
    int invoiceId,
  );

  Future<CustomerFinancialSummary>
      getCustomerFinancialSummary(
    int customerId,
  );
}