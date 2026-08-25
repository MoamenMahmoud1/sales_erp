import 'package:flutter/material.dart';

import '../data/database/coupon_database.dart';
import '../domain/coupon.dart';
import 'coupon_form_page.dart';

class CouponsPage extends StatefulWidget {
  const CouponsPage({
    super.key,
  });

  @override
  State<CouponsPage> createState() =>
      _CouponsPageState();
}

class _CouponsPageState
    extends State<CouponsPage> {
  final _repository =
      LocalCouponRepository();

  final _searchController =
      TextEditingController();

  List<Coupon> _allCoupons = [];
  List<Coupon> _coupons = [];

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(
      _filterCoupons,
    );

    _loadCoupons();
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(
        _filterCoupons,
      )
      ..dispose();

    super.dispose();
  }

  Future<void> _loadCoupons() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final coupons =
          await _repository.getCoupons();

      if (!mounted) {
        return;
      }

      setState(() {
        _allCoupons = coupons;
        _coupons = coupons;
        _isLoading = false;
      });

      _filterCoupons();
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Failed to load coupons.';
      });
    }
  }

  void _filterCoupons() {
    final query =
        _searchController.text
            .trim()
            .toLowerCase();

    final filtered = _allCoupons
        .where(
          (coupon) => coupon.name
              .toLowerCase()
              .contains(query),
        )
        .toList();

    if (!mounted) {
      return;
    }

    setState(() {
      _coupons = filtered;
    });
  }

  Future<void> _openCouponForm({
    Coupon? coupon,
  }) async {
    final saved =
        await Navigator.of(context)
            .push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            CouponFormPage(
          coupon: coupon,
        ),
      ),
    );

    if (saved == true &&
        mounted) {
      await _loadCoupons();
    }
  }

  Future<void> _deleteCoupon(
    Coupon coupon,
  ) async {
    final confirmed =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Delete coupon?',
          ),
          content: Text(
            'Delete ${coupon.name}?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context)
                    .pop(false);
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context)
                    .pop(true);
              },
              child: const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _repository.deleteCoupon(
        coupon.id,
      );

      if (!mounted) {
        return;
      }

      await _loadCoupons();

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Coupon deleted.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            '$error',
          ),
        ),
      );
    }
  }

  String _formatMoney(
    double value,
  ) {
    return '${value.toStringAsFixed(2)} EGP';
  }

  Widget _buildCouponCard(
    Coupon coupon,
  ) {
    return Card(
      margin:
          const EdgeInsets.only(
        bottom: 12,
      ),
      clipBehavior:
          Clip.antiAlias,
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        leading: const CircleAvatar(
          child: Icon(
            Icons.local_offer_outlined,
          ),
        ),
        title: Text(
          coupon.name,
          style:
              const TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding:
              const EdgeInsets.only(
            top: 8,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              Text(
                '${coupon.unitsPerCarton} Units / Carton',
              ),
              const SizedBox(
                height: 4,
              ),
              Text(
                'Carton Price: '
                '${_formatMoney(
                  coupon.cartonPrice,
                )}',
              ),
              const SizedBox(
                height: 4,
              ),
              Text(
                'Unit Price: '
                '${_formatMoney(
                  coupon.unitPrice,
                )}',
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        trailing:
            PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'edit') {
              _openCouponForm(
                coupon: coupon,
              );
            }

            if (value == 'delete') {
              _deleteCoupon(coupon);
            }
          },
          itemBuilder: (_) =>
              const [
            PopupMenuItem(
              value: 'edit',
              child: Text(
                'Edit',
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text(
                'Delete',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child:
            CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding:
              const EdgeInsets.all(24),
          child: Column(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
              ),
              const SizedBox(
                height: 12,
              ),
              Text(
                _errorMessage!,
                textAlign:
                    TextAlign.center,
              ),
              const SizedBox(
                height: 16,
              ),
              FilledButton(
                onPressed:
                    _loadCoupons,
                child:
                    const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_coupons.isEmpty) {
      return RefreshIndicator(
        onRefresh:
            _loadCoupons,
        child: ListView(
          physics:
              const AlwaysScrollableScrollPhysics(),
          padding:
              const EdgeInsets.only(
            top: 120,
          ),
          children: [
            Icon(
              Icons
                  .local_offer_outlined,
              size: 64,
              color: Theme.of(context)
                  .colorScheme
                  .outline,
            ),
            const SizedBox(
              height: 16,
            ),
            Center(
              child: Text(
                _searchController
                        .text
                        .trim()
                        .isEmpty
                    ? 'No coupons yet.'
                    : 'No coupons found.',
                style:
                    Theme.of(context)
                        .textTheme
                        .titleMedium,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh:
          _loadCoupons,
      child: ListView.builder(
        padding:
            const EdgeInsets.fromLTRB(
          16,
          12,
          16,
          100,
        ),
        itemCount:
            _coupons.length,
        itemBuilder:
            (context, index) {
          return _buildCouponCard(
            _coupons[index],
          );
        },
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('Coupons'),
      ),
      body: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.fromLTRB(
              16,
              16,
              16,
              4,
            ),
            child: TextField(
              controller:
                  _searchController,
              decoration:
                  InputDecoration(
                hintText:
                    'Search coupons...',
                prefixIcon:
                    const Icon(
                  Icons.search,
                ),
                suffixIcon:
                    _searchController
                            .text
                            .isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              _searchController
                                  .clear();
                            },
                            icon:
                                const Icon(
                              Icons.clear,
                            ),
                          ),
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                ),
              ),
            ),
          ),

          Expanded(
            child:
                _buildBody(),
          ),
        ],
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed:
            _openCouponForm,
        icon:
            const Icon(Icons.add),
        label:
            const Text('Coupon'),
      ),
    );
  }
}