import 'package:flutter/material.dart';

import '../data/database/coupon_database.dart';
import '../domain/coupon.dart';

class CouponFormPage extends StatefulWidget {
  final Coupon? coupon;

  const CouponFormPage({
    super.key,
    this.coupon,
  });

  bool get isEditing => coupon != null;

  @override
  State<CouponFormPage> createState() =>
      _CouponFormPageState();
}

class _CouponFormPageState
    extends State<CouponFormPage> {
  final _formKey =
      GlobalKey<FormState>();

  final _repository =
      LocalCouponRepository();

  late final TextEditingController
      _nameController;

  late final TextEditingController
      _unitsController;

  late final TextEditingController
      _cartonPriceController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _nameController =
        TextEditingController(
      text: widget.coupon?.name ?? '',
    );

    _unitsController =
        TextEditingController(
      text: widget.coupon == null
          ? ''
          : widget.coupon!
              .unitsPerCarton
              .toString(),
    );

    _cartonPriceController =
        TextEditingController(
      text: widget.coupon == null
          ? ''
          : widget.coupon!
              .cartonPrice
              .toStringAsFixed(2),
    );

    _unitsController.addListener(
      _refreshCalculatedPrice,
    );

    _cartonPriceController.addListener(
      _refreshCalculatedPrice,
    );
  }

  @override
  void dispose() {
    _unitsController
        .removeListener(
      _refreshCalculatedPrice,
    );

    _cartonPriceController
        .removeListener(
      _refreshCalculatedPrice,
    );

    _nameController.dispose();
    _unitsController.dispose();
    _cartonPriceController.dispose();

    super.dispose();
  }

  void _refreshCalculatedPrice() {
    if (!mounted) {
      return;
    }

    setState(() {});
  }

  int get _unitsPerCarton {
    return int.tryParse(
          _unitsController.text.trim(),
        ) ??
        0;
  }

  double get _cartonPrice {
    return double.tryParse(
          _cartonPriceController.text
              .trim(),
        ) ??
        0;
  }

  double get _unitPrice {
    if (_unitsPerCarton <= 0 ||
        _cartonPrice <= 0) {
      return 0;
    }

    return _cartonPrice /
        _unitsPerCarton;
  }

  String _formatMoney(
    double value,
  ) {
    return '${value.toStringAsFixed(2)} EGP';
  }

  String? _validateName(
    String? value,
  ) {
    if (value == null ||
        value.trim().isEmpty) {
      return 'Coupon name is required.';
    }

    return null;
  }

  String? _validateUnits(
    String? value,
  ) {
    if (value == null ||
        value.trim().isEmpty) {
      return 'Units per carton is required.';
    }

    final units =
        int.tryParse(value.trim());

    if (units == null) {
      return 'Enter a valid whole number.';
    }

    if (units <= 0) {
      return 'Units must be greater than zero.';
    }

    return null;
  }

  String? _validateCartonPrice(
    String? value,
  ) {
    if (value == null ||
        value.trim().isEmpty) {
      return 'Carton price is required.';
    }

    final price =
        double.tryParse(value.trim());

    if (price == null) {
      return 'Enter a valid price.';
    }

    if (price <= 0) {
      return 'Carton price must be greater than zero.';
    }

    return null;
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    final units =
        int.parse(
      _unitsController.text.trim(),
    );

    final cartonPrice =
        double.parse(
      _cartonPriceController.text.trim(),
    );

    setState(() {
      _isSaving = true;
    });

    try {
      if (widget.isEditing) {
        await _repository.updateCoupon(
          id: widget.coupon!.id,
          name:
              _nameController.text.trim(),
          unitsPerCarton: units,
          cartonPrice: cartonPrice,
        );
      } else {
        await _repository.addCoupon(
          name:
              _nameController.text.trim(),
          unitsPerCarton: units,
          cartonPrice: cartonPrice,
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Failed to save coupon: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing
              ? 'Edit Coupon'
              : 'New Coupon',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding:
              const EdgeInsets.all(16),
          children: [
            Text(
              widget.isEditing
                  ? 'Coupon information'
                  : 'Add a new coupon',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                    fontWeight:
                        FontWeight.bold,
                  ),
            ),

            const SizedBox(
              height: 24,
            ),

            TextFormField(
              controller:
                  _nameController,
              textCapitalization:
                  TextCapitalization.words,
              decoration:
                  const InputDecoration(
                labelText:
                    'Coupon name',
                hintText:
                    'Example: Pepsi',
                prefixIcon:
                    Icon(
                  Icons.local_offer_outlined,
                ),
                border:
                    OutlineInputBorder(),
              ),
              validator:
                  _validateName,
            ),

            const SizedBox(
              height: 16,
            ),

            TextFormField(
              controller:
                  _unitsController,
              keyboardType:
                  TextInputType.number,
              decoration:
                  const InputDecoration(
                labelText:
                    'Units per carton',
                hintText:
                    'Example: 24',
                prefixIcon:
                    Icon(
                  Icons.inventory_2_outlined,
                ),
                border:
                    OutlineInputBorder(),
              ),
              validator:
                  _validateUnits,
            ),

            const SizedBox(
              height: 16,
            ),

            TextFormField(
              controller:
                  _cartonPriceController,
              keyboardType:
                  const TextInputType
                      .numberWithOptions(
                decimal: true,
              ),
              decoration:
                  const InputDecoration(
                labelText:
                    'Carton price',
                hintText:
                    'Example: 120',
                suffixText:
                    'EGP',
                prefixIcon:
                    Icon(
                  Icons
                      .account_balance_wallet_outlined,
                ),
                border:
                    OutlineInputBorder(),
              ),
              validator:
                  _validateCartonPrice,
            ),

            const SizedBox(
              height: 24,
            ),

            Card(
              elevation: 0,
              child: Padding(
                padding:
                    const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      'Calculated pricing',
                      style: Theme.of(
                        context,
                      )
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight:
                                FontWeight.bold,
                          ),
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    Row(
                      children: [
                        const Icon(
                          Icons
                              .inventory_2_outlined,
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        Expanded(
                          child: Text(
                            'Units per carton',
                            style: Theme.of(
                              context,
                            )
                                .textTheme
                                .bodyLarge,
                          ),
                        ),
                        Text(
                          _unitsPerCarton
                              .toString(),
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 12,
                    ),

                    Row(
                      children: [
                        const Icon(
                          Icons
                              .account_balance_wallet_outlined,
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        Expanded(
                          child: Text(
                            'Carton price',
                            style: Theme.of(
                              context,
                            )
                                .textTheme
                                .bodyLarge,
                          ),
                        ),
                        Text(
                          _formatMoney(
                            _cartonPrice,
                          ),
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const Divider(
                      height: 24,
                    ),

                    Row(
                      children: [
                        const Icon(
                          Icons
                              .price_change_outlined,
                        ),
                        const SizedBox(
                          width: 10,
                        ),
                        Expanded(
                          child: Text(
                            'Unit price',
                            style: Theme.of(
                              context,
                            )
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight:
                                      FontWeight.bold,
                                ),
                          ),
                        ),
                        Text(
                          _formatMoney(
                            _unitPrice,
                          ),
                          style: Theme.of(
                            context,
                          )
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight:
                                    FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(
              height: 32,
            ),

            SizedBox(
              width: double.infinity,
              height: 52,
              child:
                  FilledButton.icon(
                onPressed:
                    _isSaving
                        ? null
                        : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.save,
                      ),
                label: Text(
                  _isSaving
                      ? 'Saving...'
                      : widget.isEditing
                          ? 'Save Changes'
                          : 'Create Coupon',
                ),
              ),
            ),

            const SizedBox(
              height: 24,
            ),
          ],
        ),
      ),
    );
  }
}