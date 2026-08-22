import 'package:flutter/material.dart';

import '../../features/coupons/presentation/coupon_form_page.dart';
import '../../features/coupons/presentation/coupons_page.dart';
import '../../features/customers/presentation/customers_page.dart';
import '../../features/payment/presentation/payments_page.dart';
import '../../features/products/presentation/product_form_page.dart';
import '../../features/products/presentation/products_page.dart';
import '../../features/sales/presentation/invoices_page.dart';
import '../storage/app_database.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({
    super.key,
  });

  @override
  State<DashboardPage> createState() =>
      _DashboardPageState();
}

class _DashboardPageState
    extends State<DashboardPage> {
  bool _isLoading = true;
  String? _errorMessage;

  int _customersCount = 0;
  int _productsCount = 0;
  int _invoicesCount = 0;

  double _paymentsTotal = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final database =
          await AppDatabase.database;

      final results = await Future.wait([
        database.rawQuery(
          '''
          SELECT COUNT(*) AS count
          FROM customers
          ''',
        ),
        database.rawQuery(
          '''
          SELECT COUNT(*) AS count
          FROM products
          ''',
        ),
        database.rawQuery(
          '''
          SELECT COUNT(*) AS count
          FROM invoices
          ''',
        ),
        database.rawQuery(
          '''
          SELECT COALESCE(
            SUM(amount),
            0
          ) AS total

          FROM payments

          WHERE status = ?
          ''',
          ['paid'],
        ),
      ]);

      final customersResult =
          results[0];

      final productsResult =
          results[1];

      final invoicesResult =
          results[2];

      final paymentsResult =
          results[3];

      final customersCount =
          (customersResult.first['count']
                  as num)
              .toInt();

      final productsCount =
          (productsResult.first['count']
                  as num)
              .toInt();

      final invoicesCount =
          (invoicesResult.first['count']
                  as num)
              .toInt();

      final paymentsTotal =
          (paymentsResult.first['total']
                  as num)
              .toDouble();

      if (!mounted) {
        return;
      }

      setState(() {
        _customersCount =
            customersCount;

        _productsCount =
            productsCount;

        _invoicesCount =
            invoicesCount;

        _paymentsTotal =
            paymentsTotal;

        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Failed to load dashboard data.';
      });
    }
  }

  String _formatMoney(
    double value,
  ) {
    return '${value.toStringAsFixed(2)} EGP';
  }

  Future<void> _openPage(
    Widget page,
  ) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => page,
      ),
    );

    if (!mounted) {
      return;
    }

    await _loadDashboard();
  }

  Widget _buildDashboard() {
    final theme =
        Theme.of(context);

    return RefreshIndicator(
      onRefresh: _loadDashboard,
      child: SingleChildScrollView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            // ==================================================
            // HEADER
            // ==================================================

            Text(
              'Dashboard',
              style:
                  theme.textTheme.headlineMedium
                      ?.copyWith(
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 6,
            ),

            Text(
              'Manage your sales business',
              style:
                  theme.textTheme.bodyLarge
                      ?.copyWith(
                color: theme
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),

            const SizedBox(
              height: 24,
            ),

            // ==================================================
            // SUMMARY CARDS
            // ==================================================

            Row(
              children: [
                Expanded(
                  child:
                      _SummaryCard(
                    icon: Icons
                        .people_alt_outlined,
                    title: 'Customers',
                    value:
                        _customersCount
                            .toString(),
                  ),
                ),

                const SizedBox(
                  width: 12,
                ),

                Expanded(
                  child:
                      _SummaryCard(
                    icon: Icons
                        .receipt_long_outlined,
                    title: 'Invoices',
                    value:
                        _invoicesCount
                            .toString(),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 12,
            ),

            Row(
              children: [
                Expanded(
                  child:
                      _SummaryCard(
                    icon: Icons
                        .payments_outlined,
                    title: 'Payments',
                    value:
                        _formatMoney(
                      _paymentsTotal,
                    ),
                  ),
                ),

                const SizedBox(
                  width: 12,
                ),

                Expanded(
                  child:
                      _SummaryCard(
                    icon: Icons
                        .inventory_2_outlined,
                    title: 'Products',
                    value:
                        _productsCount
                            .toString(),
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 32,
            ),

            // ==================================================
            // MANAGEMENT
            // ==================================================

            Text(
              'Management',
              style:
                  theme.textTheme.titleLarge
                      ?.copyWith(
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            _DashboardButton(
              icon:
                  Icons.people_alt_outlined,
              title: 'Customers',
              subtitle:
                  'Manage customers and their accounts',
              onTap: () {
                _openPage(
                  const CustomersPage(),
                );
              },
            ),

            const SizedBox(
              height: 12,
            ),

            _DashboardButton(
              icon:
                  Icons.inventory_2_outlined,
              title: 'Products',
              subtitle:
                  'Manage products and prices',
              onTap: () {
                _openPage(
                  const ProductsPage(),
                );
              },
            ),

            const SizedBox(
              height: 12,
            ),

            _DashboardButton(
              icon:
                  Icons.local_offer_outlined,
              title: 'Coupons',
              subtitle:
                  'Manage coupons and customer coupons',
              onTap: () {
                _openPage(
                  const CouponsPage(),
                );
              },
            ),

            const SizedBox(
              height: 12,
            ),

            _DashboardButton(
              icon:
                  Icons.receipt_long_outlined,
              title: 'Invoices',
              subtitle:
                  'Create and manage sales invoices',
              onTap: () {
                _openPage(
                  const InvoicesPage(),
                );
              },
            ),

            const SizedBox(
              height: 12,
            ),

            _DashboardButton(
              icon:
                  Icons.payments_outlined,
              title: 'Payments',
              subtitle:
                  'Manage cash and bank transfers',
              onTap: () {
                _openPage(
                  const PaymentsPage(),
                );
              },
            ),

            const SizedBox(
              height: 32,
            ),

            // ==================================================
            // QUICK ACTIONS
            // ==================================================

            Text(
              'Quick Actions',
              style:
                  theme.textTheme.titleLarge
                      ?.copyWith(
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 14,
            ),

            Row(
              children: [
                Expanded(
                  child:
                      _QuickAction(
                    icon: Icons
                        .person_add_alt_1,
                    title:
                        'New Customer',
                    onTap: () {
                      _openPage(
                        const CustomersPage(),
                      );
                    },
                  ),
                ),

                const SizedBox(
                  width: 12,
                ),

                Expanded(
                  child:
                      _QuickAction(
                    icon: Icons
                        .add_shopping_cart,
                    title:
                        'New Invoice',
                    onTap: () {
                      _openPage(
                        const InvoicesPage(),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 12,
            ),

            Row(
              children: [
                Expanded(
                  child:
                      _QuickAction(
                    icon: Icons
                        .add_box_outlined,
                    title:
                        'New Product',
                    onTap: () {
                      _openPage(
                        const ProductFormPage(),
                      );
                    },
                  ),
                ),

                const SizedBox(
                  width: 12,
                ),

                Expanded(
                  child:
                      _QuickAction(
                    icon: Icons
                        .local_offer_outlined,
                    title:
                        'New Coupon',
                    onTap: () {
                      _openPage(
                        const CouponFormPage(),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(
              height: 40,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Sales ERP',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child:
                  CircularProgressIndicator(),
            )
          : _errorMessage != null
              ? _buildErrorState()
              : _buildDashboard(),
    );
  }

  Widget _buildErrorState() {
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
                  _loadDashboard,
              child:
                  const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// SUMMARY CARD
// ================================================================

class _SummaryCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _SummaryCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    return Card(
      elevation: 0,
      child: Padding(
        padding:
            const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 28,
              color:
                  theme.colorScheme.primary,
            ),

            const SizedBox(
              height: 12,
            ),

            Text(
              value,
              style:
                  theme.textTheme.titleLarge
                      ?.copyWith(
                fontWeight:
                    FontWeight.bold,
              ),
            ),

            const SizedBox(
              height: 4,
            ),

            Text(
              title,
              style:
                  theme.textTheme.bodyMedium
                      ?.copyWith(
                color: theme
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// DASHBOARD BUTTON
// ================================================================

class _DashboardButton
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _DashboardButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    return Card(
      elevation: 0,
      clipBehavior:
          Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration:
                    BoxDecoration(
                  color: theme
                      .colorScheme
                      .primaryContainer,
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child: Icon(
                  icon,
                  color: theme
                      .colorScheme
                      .onPrimaryContainer,
                ),
              ),

              const SizedBox(
                width: 16,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          theme.textTheme.titleMedium
                              ?.copyWith(
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                      height: 4,
                    ),

                    Text(
                      subtitle,
                      style:
                          theme.textTheme.bodyMedium
                              ?.copyWith(
                        color: theme
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.chevron_right,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ================================================================
// QUICK ACTION
// ================================================================

class _QuickAction
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    return Card(
      elevation: 0,
      clipBehavior:
          Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 18,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 30,
                color:
                    theme.colorScheme.primary,
              ),

              const SizedBox(
                height: 10,
              ),

              Text(
                title,
                textAlign:
                    TextAlign.center,
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

