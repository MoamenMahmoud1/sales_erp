import '../entities/invoice.dart';
import '../entities/money.dart';
import '../entities/payment.dart';
import '../results/collection_result.dart';
import 'invoice_calculator.dart';

class PaymentAllocationService {
  final InvoiceCalculator calculator;

  const PaymentAllocationService({
    required this.calculator,
  });

  CollectionResult allocate({
    required List<Invoice> invoices,
    required Payment payment,
    required DateTime now,
  }) {
    final totalOutstanding = _calculateOutstanding(
      invoices,
    );

    final totalReceived = payment.totalPaid;

    // --------------------------------------------------
    // 1. Validate payment
    // --------------------------------------------------

    if (payment.cashAmount < Money.zero) {
      return CollectionResult.failure(
        errorMessage:
            'Cash amount cannot be negative.',
        totalOutstanding: totalOutstanding,
        totalReceived: totalReceived,
      );
    }

    if (payment.transferAmount < Money.zero) {
      return CollectionResult.failure(
        errorMessage:
            'Transfer amount cannot be negative.',
        totalOutstanding: totalOutstanding,
        totalReceived: totalReceived,
      );
    }

    // --------------------------------------------------
    // 2. Reject overpayment
    // --------------------------------------------------

    if (totalReceived > totalOutstanding) {
      return CollectionResult.failure(
        errorMessage:
            'Payment exceeds outstanding balance.',
        totalOutstanding: totalOutstanding,
        totalReceived: totalReceived,
      );
    }

    // --------------------------------------------------
    // 3. Nothing to collect
    // --------------------------------------------------

    if (totalReceived == Money.zero) {
      return CollectionResult.success(
        totalOutstanding: totalOutstanding,
        totalReceived: totalReceived,
        updatedInvoices: invoices,
      );
    }

    // --------------------------------------------------
    // 4. Allocate payment
    // --------------------------------------------------

    var remainingCash = payment.cashAmount;
    var remainingTransfer = payment.transferAmount;

    final updatedInvoices = <Invoice>[];

    for (final invoice in invoices) {
      final invoiceRemaining =
          calculator.calculateRemaining(invoice);

      // Already paid.
      if (invoiceRemaining <= Money.zero) {
        updatedInvoices.add(invoice);
        continue;
      }

      // Nothing left to allocate.
      if (remainingCash == Money.zero &&
          remainingTransfer == Money.zero) {
        updatedInvoices.add(invoice);
        continue;
      }

      // ------------------------------------------------
      // Cash allocation
      // ------------------------------------------------

      final cashForInvoice = _minMoney(
        remainingCash,
        invoiceRemaining,
      );

      remainingCash =
          remainingCash - cashForInvoice;

      // ------------------------------------------------
      // Transfer allocation
      // ------------------------------------------------

      final remainingAfterCash =
          invoiceRemaining - cashForInvoice;

      final transferForInvoice = _minMoney(
        remainingTransfer,
        remainingAfterCash,
      );

      remainingTransfer =
          remainingTransfer - transferForInvoice;

      // ------------------------------------------------
      // Payment allocated to this invoice
      // ------------------------------------------------

      final allocatedPayment = Payment(
        cashAmount: cashForInvoice,
        transferAmount: transferForInvoice,
      );

      // ------------------------------------------------
      // Create NEW Payment
      // ------------------------------------------------

      final newPayment =
          invoice.payment.copyWith(
        cashAmount:
            invoice.payment.cashAmount +
                allocatedPayment.cashAmount,
        transferAmount:
            invoice.payment.transferAmount +
                allocatedPayment.transferAmount,
      );

      // ------------------------------------------------
      // Check whether this invoice is now fully paid
      // ------------------------------------------------

      final isNowPaid =
          allocatedPayment.totalPaid >=
              invoiceRemaining;

      // ------------------------------------------------
      // Create NEW Invoice
      // ------------------------------------------------

      final updatedInvoice =
          invoice.copyWith(
        payment: newPayment,
        paidAt: isNowPaid
            ? now
            : invoice.paidAt,
        updatedAt: now,
      );

      updatedInvoices.add(updatedInvoice);
    }

    // --------------------------------------------------
    // 5. Return result
    // --------------------------------------------------

    return CollectionResult.success(
      totalOutstanding: totalOutstanding,
      totalReceived: totalReceived,
      updatedInvoices: updatedInvoices,
    );
  }

  Money _calculateOutstanding(
    List<Invoice> invoices,
  ) {
    var total = Money.zero;

    for (final invoice in invoices) {
      final remaining =
          calculator.calculateRemaining(invoice);

      if (remaining > Money.zero) {
        total += remaining;
      }
    }

    return total;
  }

  Money _minMoney(
    Money first,
    Money second,
  ) {
    return first <= second
        ? first
        : second;
  }
}

