import 'package:flutter/material.dart';

import '../../features/coupons/presentation/coupons_page.dart';
import '../../features/customers/presentation/customers_page.dart';
import '../../features/payment/presentation/payments_page.dart';
import '../../features/products/presentation/products_page.dart';
import '../../features/products/domain/product_repository.dart';
import '../../features/sales/presentation/invoices_page.dart';
import '../storage/app_database.dart';
import '../theme/app_theme.dart';

class DashboardPage extends StatefulWidget {
  final Future<void> Function() onLogout;
  final AppThemeController themeController;
  final ProductRepository? productRepository;

  const DashboardPage({
    super.key,
    required this.onLogout,
    required this.themeController,
    this.productRepository,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _loading = true;
  String? _error;
  int _customers = 0;
  int _products = 0;
  int _invoices = 0;
  double _invoiceValue = 0;
  double _outstanding = 0;
  double _cash = 0;
  double _transfers = 0;
  String _topCustomer = 'No data';
  String _lowestCustomer = 'No data';

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final database = await AppDatabase.database;
      final results = await Future.wait([
        database.rawQuery('SELECT COUNT(*) AS count FROM customers'),
        database.rawQuery('SELECT COUNT(*) AS count FROM products'),
        database.rawQuery('SELECT COUNT(*) AS count FROM invoices'),
        database.rawQuery('''
          SELECT COALESCE(SUM(total), 0) AS invoice_value,
            COALESCE(SUM(CASE WHEN id NOT IN (
              SELECT invoice_id FROM payments WHERE status = 'paid'
            ) THEN total ELSE 0 END), 0) AS outstanding
          FROM invoices
        '''),
        database.rawQuery('''
          SELECT COALESCE(SUM(CASE WHEN method = 'cash' AND status = 'paid'
            THEN amount ELSE 0 END), 0) AS cash,
            COALESCE(SUM(CASE WHEN method = 'transfer' AND status = 'paid'
            THEN amount ELSE 0 END), 0) AS transfers
          FROM payments
        '''),
        database.rawQuery('''
          SELECT c.name FROM invoices i
          INNER JOIN customers c ON c.id = i.customer_id
          GROUP BY i.customer_id ORDER BY SUM(i.total) DESC LIMIT 1
        '''),
        database.rawQuery('''
          SELECT c.name FROM invoices i
          INNER JOIN customers c ON c.id = i.customer_id
          GROUP BY i.customer_id ORDER BY SUM(i.total) ASC LIMIT 1
        '''),
      ]);
      if (!mounted) return;
      final totals = results[3].first;
      final payments = results[4].first;
      setState(() {
        _customers = (results[0].first['count'] as num).toInt();
        _products = (results[1].first['count'] as num).toInt();
        _invoices = (results[2].first['count'] as num).toInt();
        _invoiceValue = (totals['invoice_value'] as num).toDouble();
        _outstanding = (totals['outstanding'] as num).toDouble();
        _cash = (payments['cash'] as num).toDouble();
        _transfers = (payments['transfers'] as num).toDouble();
        _topCustomer = results[5].isEmpty ? 'No data' : '${results[5].first['name']}';
        _lowestCustomer = results[6].isEmpty ? 'No data' : '${results[6].first['name']}';
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Failed to load dashboard data.';
        });
      }
    }
  }

  String _money(double value) => '${value.toStringAsFixed(2)} EGP';

  Future<void> _openSection(String value) async {
    final Widget page;
    switch (value) {
      case 'customers':
        page = const CustomersPage();
      case 'products':
        page = ProductsPage(repository: widget.productRepository);
      case 'coupons':
        page = const CouponsPage();
      case 'invoices':
        page = const InvoicesPage();
      case 'payments':
        page = const PaymentsPage();
      default:
        return;
    }
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    if (mounted) await _loadDashboard();
  }

  Future<void> _showMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Workspace', style: Theme.of(sheetContext).textTheme.titleLarge),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _MenuItem('Customers', Icons.people_alt_outlined, () => _openSection('customers')),
                  _MenuItem('Products', Icons.inventory_2_outlined, () => _openSection('products')),
                  _MenuItem('Coupons', Icons.local_offer_outlined, () => _openSection('coupons')),
                  _MenuItem('Invoices', Icons.receipt_long_outlined, () => _openSection('invoices')),
                  _MenuItem('Payments', Icons.payments_outlined, () => _openSection('payments')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales ERP', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(tooltip: 'Menu', icon: const Icon(Icons.menu_rounded), onPressed: _showMenu),
          PopupMenuButton<AppThemeMode>(
            tooltip: 'Theme',
            icon: const Icon(Icons.palette_outlined),
            onSelected: widget.themeController.setMode,
            itemBuilder: (_) => const [
              PopupMenuItem(value: AppThemeMode.light, child: Text('Light')),
              PopupMenuItem(value: AppThemeMode.mid, child: Text('Mid')),
              PopupMenuItem(value: AppThemeMode.dark, child: Text('Dark')),
            ],
          ),
          IconButton(tooltip: 'Sign out', icon: const Icon(Icons.logout), onPressed: widget.onLogout),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: _error!, onRetry: _loadDashboard)
              : RefreshIndicator(onRefresh: _loadDashboard, child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      children: [
        Text('Good to see you', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('Here is today\'s business at a glance.', style: theme.textTheme.bodyLarge),
        const SizedBox(height: 24),
        _SectionTitle('Financial overview'),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth < 600 ? (constraints.maxWidth - 12) / 2 : (constraints.maxWidth - 36) / 4;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            _MetricCard(width, 'Invoice value', _money(_invoiceValue), Icons.receipt_long_outlined),
            _MetricCard(width, 'Outstanding', _money(_outstanding), Icons.hourglass_bottom_outlined),
            _MetricCard(width, 'Cash received', _money(_cash), Icons.payments_outlined),
            _MetricCard(width, 'Transfers', _money(_transfers), Icons.account_balance_outlined),
          ]);
        }),
        const SizedBox(height: 12),
        LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth < 600 ? constraints.maxWidth : (constraints.maxWidth - 12) / 2;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            _InsightCard(width, 'Top customer', _topCustomer, Icons.trending_up),
            _InsightCard(width, 'Lowest sales customer', _lowestCustomer, Icons.trending_down),
          ]);
        }),
        const SizedBox(height: 28),
        _SectionTitle('Activity'),
        const SizedBox(height: 12),
        Wrap(spacing: 12, runSpacing: 12, children: [
          _CountCard('Customers', '$_customers', Icons.people_alt_outlined),
          _CountCard('Products', '$_products', Icons.inventory_2_outlined),
          _CountCard('Invoices', '$_invoices', Icons.receipt_long_outlined),
        ]),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  const _MenuItem(this.label, this.icon, this.onTap);
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          Navigator.pop(context);
          onTap();
        },
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: [Icon(icon), const SizedBox(height: 8), Text(label, overflow: TextOverflow.ellipsis)]),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold));
}

class _MetricCard extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final IconData icon;
  const _MetricCard(this.width, this.label, this.value, this.icon);
  @override
  Widget build(BuildContext context) => SizedBox(width: width, child: Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 14), Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 4), Text(label)]))));
}

class _CountCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _CountCard(this.label, this.value, this.icon);
  @override
  Widget build(BuildContext context) => SizedBox(width: 150, child: Card(child: ListTile(leading: Icon(icon), title: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(label))));
}

class _InsightCard extends StatelessWidget {
  final double width;
  final String label;
  final String value;
  final IconData icon;
  const _InsightCard(this.width, this.label, this.value, this.icon);
  @override
  Widget build(BuildContext context) => SizedBox(width: width, child: Card(child: ListTile(leading: CircleAvatar(child: Icon(icon)), title: Text(label), subtitle: Text(value, overflow: TextOverflow.ellipsis))));
}

class _ErrorState extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _ErrorState({required this.message, required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [Text(message), const SizedBox(height: 12), FilledButton(onPressed: onRetry, child: const Text('Retry'))]));
}
