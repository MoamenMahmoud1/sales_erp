/// Human-readable invoice number used by the UI and shared documents.
///
/// The database id remains internal. The display value is deterministic from
/// the invoice creation year and internal id, so it requires no extra counter
/// state and remains stable for the lifetime of the invoice.
class InvoiceDisplayNumber {
  const InvoiceDisplayNumber();

  String forInvoice({required int id, required DateTime createdAt}) =>
      '${createdAt.year}-${id.toString().padLeft(6, '0')}';
}
