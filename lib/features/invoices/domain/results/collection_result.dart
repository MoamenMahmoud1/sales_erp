import '../entities/invoice.dart';
import '../entities/money.dart';
import 'collection_allocation.dart';

class CollectionResult {
  final bool isSuccess;
  final String? errorMessage;

  final Money totalOutstanding;
  final Money totalReceived;

  final List<Invoice> updatedInvoices;
  final List<CollectionAllocation> allocations;

  const CollectionResult({
    required this.isSuccess,
    required this.errorMessage,
    required this.totalOutstanding,
    required this.totalReceived,
    required this.updatedInvoices,
    required this.allocations,
  });

  factory CollectionResult.success({
    required Money totalOutstanding,
    required Money totalReceived,
    required List<Invoice> updatedInvoices,
    required List<CollectionAllocation> allocations,
  }) {
    return CollectionResult(
      isSuccess: true,
      errorMessage: null,
      totalOutstanding: totalOutstanding,
      totalReceived: totalReceived,
      updatedInvoices: List.unmodifiable(updatedInvoices),
      allocations: List.unmodifiable(allocations),
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
      allocations: const [],
    );
  }
}