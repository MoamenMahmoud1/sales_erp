import '../entities/invoice.dart';
import '../entities/money.dart';

class CollectionResult {
  final bool isSuccess;
  final String? errorMessage;

  final Money totalOutstanding;
  final Money totalReceived;

  final List<Invoice> updatedInvoices;

  const CollectionResult({
    required this.isSuccess,
    required this.errorMessage,
    required this.totalOutstanding,
    required this.totalReceived,
    required this.updatedInvoices,
  });

  factory CollectionResult.success({
    required Money totalOutstanding,
    required Money totalReceived,
    required List<Invoice> updatedInvoices,
  }) {
    return CollectionResult(
      isSuccess: true,
      errorMessage: null,
      totalOutstanding: totalOutstanding,
      totalReceived: totalReceived,
      updatedInvoices: updatedInvoices,
    );
  }

  factory CollectionResult.failure({
    required String errorMessage,
    required Money totalOutstanding,
    required Money totalReceived,
  }) {
    return CollectionResult(
      isSuccess: false,
      errorMessage: errorMessage,
      totalOutstanding: totalOutstanding,
      totalReceived: totalReceived,
      updatedInvoices: const [],
    );
  }
}

