import 'package:flutter/material.dart';

import '../domain/entities/invoice.dart';
import '../domain/entities/invoice_item.dart';
import '../domain/entities/money.dart';
import '../domain/entities/payment.dart';
import '../domain/services/invoice_calculator.dart';

class InvoiceDemoPage extends StatefulWidget {
  const InvoiceDemoPage({
    super.key,
  });

  @override
  State<InvoiceDemoPage> createState() =>
      _InvoiceDemoPageState();
}

class _InvoiceDemoPageState
    extends State<InvoiceDemoPage> {
  final InvoiceCalculator _calculator =
      const InvoiceCalculator();

  late Invoice _invoice;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    _invoice = Invoice(
      id: 1,
      customerId: 1,
      createdAt: now,
      updatedAt: now,
      items: List<InvoiceItem>.unmodifiable(
        [
          const InvoiceItem(
            productId: 1,
            productName: 'Laptop',
            unitPrice: Money(3000000),
            quantity: 1,
          ),
          const InvoiceItem(
            productId: 2,
            productName: 'Mouse',
            unitPrice: Money(150000),
            quantity: 1,
          ),
          const InvoiceItem(
            productId: 3,
            productName: 'Keyboard',
            unitPrice: Money(250000),
            quantity: 1,
          ),
        ],
      ),
      payment: const Payment(
        cashAmount: Money.zero,
        transferAmount: Money.zero,
      ),
    );
  }

  void _changeQuantity(
    int index,
    int change,
  ) {
    print('================================');
    print('_changeQuantity() CALLED');
    print('index: $index');
    print('change: $change');

    final InvoiceItem oldItem =
        _invoice.items[index];

    print('OLD ITEM');

    print(
      'object id: ${identityHashCode(oldItem)}',
    );

    print(
      'product: ${oldItem.productName}',
    );

    print(
      'quantity: ${oldItem.quantity}',
    );

    final int newQuantity =
        oldItem.quantity + change;

    print(
      'new quantity: $newQuantity',
    );

    if (newQuantity < 0) {
      print(
        'Quantity cannot be less than 0',
      );

      print('================================');

      return;
    }

    /*
     * إنشاء InvoiceItem جديد.
     *
     * الـ oldItem لن يتغير.
     */
    final InvoiceItem newItem =
        oldItem.copyWith(
      quantity: newQuantity,
    );

    print('NEW ITEM');

    print(
      'object id: ${identityHashCode(newItem)}',
    );

    print(
      'product: ${newItem.productName}',
    );

    print(
      'quantity: ${newItem.quantity}',
    );

    print(
      'Same object? '
      '${identical(oldItem, newItem)}',
    );

    /*
     * إنشاء List جديدة.
     */
    final List<InvoiceItem> newItems =
        List<InvoiceItem>.from(
      _invoice.items,
    );

    /*
     * استبدال العنصر القديم بالعنصر الجديد.
     */
    newItems[index] = newItem;

    /*
     * قفل الـ List حتى لا يتم تعديلها
     * من الخارج.
     */
    final List<InvoiceItem> immutableItems =
        List<InvoiceItem>.unmodifiable(
      newItems,
    );

    final Invoice oldInvoice = _invoice;

    print('OLD INVOICE');

    print(
      'object id: ${identityHashCode(oldInvoice)}',
    );

    /*
     * إنشاء Invoice جديد.
     */
    final Invoice newInvoice =
        oldInvoice.copyWith(
      items: immutableItems,
      updatedAt: DateTime.now(),
    );

    print('NEW INVOICE');

    print(
      'object id: ${identityHashCode(newInvoice)}',
    );

    print(
      'Same invoice? '
      '${identical(oldInvoice, newInvoice)}',
    );

    /*
     * تحديث State بالـ Invoice الجديد.
     */
    setState(() {
      _invoice = newInvoice;
    });

    print('================================');
  }

  String _formatMoney(
    Money money,
  ) {
    final double amount =
        money.minorUnits / 100;

    return '${amount.toStringAsFixed(2)} EGP';
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    print('INVOICE DEMO BUILD');

    final Money subtotal =
        _calculator.calculateSubtotal(
      _invoice,
    );

    final int totalQuantity =
        _calculator.calculateTotalQuantity(
      _invoice,
    );

    final Money total =
        _calculator.calculateTotal(
      _invoice,
    );

    final Money totalPaid =
        _calculator.calculateTotalPaid(
      _invoice,
    );

    final Money remaining =
        _calculator.calculateRemaining(
      _invoice,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Invoice Demo',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Customer',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Ahmed Mohamed',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Products',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          ..._invoice.items
              .asMap()
              .entries
              .map(
            (
              MapEntry<int, InvoiceItem> entry,
            ) {
              final int index = entry.key;
              final InvoiceItem item = entry.value;

              return _ProductCard(
                item: item,

                onDecrease: () {
                  print(
                    'MINUS BUTTON PRESSED',
                  );

                  _changeQuantity(
                    index,
                    -1,
                  );
                },

                onIncrease: () {
                  print(
                    'PLUS BUTTON PRESSED',
                  );

                  _changeQuantity(
                    index,
                    1,
                  );
                },

                formatMoney: _formatMoney,
              );
            },
          ),

          const SizedBox(height: 24),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment:
                    MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Total Quantity',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  Text(
                    '$totalQuantity',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Total',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(
                    _formatMoney(total),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _SummaryRow(
                    title: 'Subtotal',
                    value:
                        _formatMoney(subtotal),
                  ),

                  const SizedBox(height: 10),

                  _SummaryRow(
                    title: 'Paid',
                    value:
                        _formatMoney(totalPaid),
                  ),

                  const SizedBox(height: 10),

                  _SummaryRow(
                    title: 'Remaining',
                    value:
                        _formatMoney(remaining),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          const Text(
            'Payment',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _PaymentBox(
                  title: 'Cash',
                  value: _formatMoney(
                    _invoice.payment.cashAmount,
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _PaymentBox(
                  title: 'Transfer',
                  value: _formatMoney(
                    _invoice.payment.transferAmount,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          FilledButton(
            onPressed: () {
              print(
                'SAVE INVOICE PRESSED',
              );

              ScaffoldMessenger.of(context)
                  .showSnackBar(
                const SnackBar(
                  content: Text(
                    'Demo only — nothing saved yet.',
                  ),
                ),
              );
            },
            child: const Text(
              'Save Invoice',
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard
    extends StatelessWidget {
  final InvoiceItem item;

  final VoidCallback onDecrease;
  final VoidCallback onIncrease;

  final String Function(Money) formatMoney;

  const _ProductCard({
    required this.item,
    required this.onDecrease,
    required this.onIncrease,
    required this.formatMoney,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    item.productName,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    formatMoney(
                      item.unitPrice,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    'Total: '
                    '${formatMoney(item.total)}',
                  ),
                ],
              ),
            ),

            Row(
              children: [
                IconButton(
                  onPressed:
                      item.quantity == 0
                          ? null
                          : onDecrease,
                  icon: const Icon(
                    Icons.remove,
                  ),
                ),

                Text(
                  '${item.quantity}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                IconButton(
                  onPressed: onIncrease,
                  icon: const Icon(
                    Icons.add,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow
    extends StatelessWidget {
  final String title;
  final String value;

  const _SummaryRow({
    required this.title,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.spaceBetween,
      children: [
        Text(title),

        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _PaymentBox
    extends StatelessWidget {
  final String title;
  final String value;

  const _PaymentBox({
    required this.title,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(title),

            const SizedBox(height: 6),

            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

