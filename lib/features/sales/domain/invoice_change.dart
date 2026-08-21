class InvoiceChange {
  final int productId;
  final int oldQuantity;
  final int newQuantity;

  const InvoiceChange({
    required this.productId,
    required this.oldQuantity,
    required this.newQuantity,
  });
}