part of '../car_trip_editor_page.dart';

class _ExpandableProductCard extends StatefulWidget {
  final String productName;
  final String category;
  final String buy;
  final String sell;
  final int loaded;
  final int returned;
  final double discount;
  final String cost;
  final String profit;
  final String discountAmount;
  final ColorScheme scheme;
  final bool saving;
  final VoidCallback onRemove;
  final ValueChanged<int> onLoadedChanged;
  final ValueChanged<int> onReturnedChanged;
  final ValueChanged<double> onDiscountChanged;

  const _ExpandableProductCard({
    super.key,
    required this.productName,
    required this.category,
    required this.buy,
    required this.sell,
    required this.loaded,
    required this.returned,
    required this.discount,
    required this.cost,
    required this.profit,
    required this.discountAmount,
    required this.scheme,
    required this.saving,
    required this.onRemove,
    required this.onLoadedChanged,
    required this.onReturnedChanged,
    required this.onDiscountChanged,
  });

  @override
  State<_ExpandableProductCard> createState() => _ExpandableProductCardState();
}

class _ExpandableProductCardState extends State<_ExpandableProductCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.productName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                            ),
                          ),
                          if (widget.category.trim().isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(left: 6),
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              constraints: const BoxConstraints(maxWidth: 110),
                              decoration: BoxDecoration(
                                color: widget.scheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                widget.category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: widget.scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${widget.buy} buy · ${widget.sell} sell / carton',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: widget.scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remove product',
                  visualDensity: VisualDensity.compact,
                  onPressed: widget.saving ? null : widget.onRemove,
                  icon: Icon(Icons.close_rounded, color: widget.scheme.error, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Expanded(
                  child: _QuantityField(
                    label: 'Loaded',
                    value: widget.loaded,
                    onChanged: widget.onLoadedChanged,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${widget.loaded - widget.returned} sold',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.profit,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.scheme.onSurfaceVariant,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: widget.scheme.tertiary,
                ),
                onPressed: () => setState(() => _expanded = !_expanded),
                icon: Icon(
                  _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 18,
                ),
                label: Text(
                  _expanded ? 'See less' : 'See more',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                ),
              ),
            ),
            if (_expanded) ...[
              Divider(height: 12, color: widget.scheme.outlineVariant),
              Row(
                children: [
                  Expanded(
                    child: _QuantityField(
                      label: 'Returned',
                      value: widget.returned,
                      max: widget.loaded,
                      onChanged: widget.onReturnedChanged,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _NumberInputField(
                      label: 'Discount',
                      suffix: '%',
                      value: widget.discount,
                      min: 0,
                      max: 100,
                      onChanged: widget.onDiscountChanged,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: widget.scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Wrap(
                  spacing: 14,
                  runSpacing: 5,
                  children: [
                    _MiniMetric(label: 'Discount', value: widget.discountAmount),
                    _MiniMetric(label: 'Cost', value: widget.cost),
                    _MiniMetric(label: 'Profit', value: widget.profit),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;

  const _MiniMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label $value',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _ControllerNumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? suffix;
  final ValueChanged<double> onChanged;

  const _ControllerNumberField({
    required this.controller,
    required this.label,
    required this.onChanged,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
        border: const OutlineInputBorder(),
      ),
      onChanged: (raw) {
        final parsed = double.tryParse(raw.trim());
        if (parsed != null) onChanged(parsed);
      },
    );
  }
}

class _NumberInputField extends StatefulWidget {
  final String label;
  final String? suffix;
  final double value;
  final double? min;
  final double? max;
  final ValueChanged<double> onChanged;

  const _NumberInputField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.suffix,
    this.min,
    this.max,
  });

  @override
  State<_NumberInputField> createState() => _NumberInputFieldState();
}

class _NumberInputFieldState extends State<_NumberInputField> {
  late final TextEditingController _controller =
      TextEditingController(text: _format(widget.value));

  @override
  void didUpdateWidget(covariant _NumberInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final current = double.tryParse(_controller.text.trim());
      if (current == null || current != widget.value) _setText(widget.value);
    }
  }

  String _format(double value) => value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(2);

  void _setText(double value) {
    final next = _format(value);
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: widget.label,
        suffixText: widget.suffix,
        border: const OutlineInputBorder(),
      ),
      onChanged: (raw) {
        final parsed = double.tryParse(raw.trim());
        if (parsed == null) return;
        var next = parsed;
        if (widget.min != null && next < widget.min!) next = widget.min!;
        if (widget.max != null && next > widget.max!) next = widget.max!;
        widget.onChanged(next);
      },
    );
  }
}

class _QuantityField extends StatefulWidget {
  final String label;
  final int value;
  final int? max;
  final ValueChanged<int> onChanged;

  const _QuantityField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.max,
  });

  @override
  State<_QuantityField> createState() => _QuantityFieldState();
}

class _QuantityFieldState extends State<_QuantityField> {
  late final TextEditingController _controller =
      TextEditingController(text: '${widget.value}');

  @override
  void didUpdateWidget(covariant _QuantityField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      final current = int.tryParse(_controller.text.trim());
      if (current == null || current != widget.value) _setText(widget.value);
    }
  }

  void _setText(int value) {
    final next = '$value';
    _controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
  }

  int _clamp(int value) {
    var next = value < 0 ? 0 : value;
    if (widget.max != null && next > widget.max!) next = widget.max!;
    return next;
  }

  void _emit(String raw) {
    final parsed = int.tryParse(raw.trim());
    if (parsed == null) return;
    widget.onChanged(_clamp(parsed));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: widget.label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      ),
      child: Row(
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 33, height: 33),
            padding: EdgeInsets.zero,
            onPressed: widget.value > 0
                ? () => widget.onChanged(widget.value - 1)
                : null,
            icon: const Icon(Icons.remove_rounded, size: 18),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              onChanged: _emit,
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 33, height: 33),
            padding: EdgeInsets.zero,
            onPressed: widget.max == null || widget.value < widget.max!
                ? () => widget.onChanged(widget.value + 1)
                : null,
            icon: const Icon(Icons.add_rounded, size: 18),
          ),
        ],
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
