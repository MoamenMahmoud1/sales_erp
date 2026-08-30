import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';

import '../storage/app_database.dart';
import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_theme.dart';
import '../ui/app_card.dart';
import '../ui/empty_state.dart';
import '../ui/kpi_card.dart';
import '../ui/section_header.dart';
import '../ui/status_badge.dart';

/// Premium dashboard built entirely from local SQLite data.
///
/// Hierarchy: header -> revenue hero -> secondary KPIs -> analytics ->
/// quick actions -> recent activity -> overdue alerts.
class DashboardPage extends StatefulWidget {
  final ValueChanged<int> onNavigateTo;
  final AppThemeController themeController;

  const DashboardPage({
    super.key,
    required this.onNavigateTo,
    required this.themeController,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _loading = true;
  String? _error;

  double _totalRevenue = 0;
  double _todayRevenue = 0;
  double _prevWeekRevenue = 0;
  int _products = 0;
  int _customers = 0;
  int _invoices = 0;
  double _outstanding = 0;
  int _overdue = 0;
  List<Map<String, Object?>> _recentInvoices = const [];
  final List<double> _week = List.filled(7, 0);
  double _weekMax = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final db = await AppDatabase.database;
      final now = DateTime.now();
      final todayStart =
          DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
      final weekStart =
          now.subtract(const Duration(days: 7)).toUtc().toIso8601String();
      final prevWeekStart =
          now.subtract(const Duration(days: 14)).toUtc().toIso8601String();

      final results = await Future.wait([
        db.rawQuery('SELECT COALESCE(SUM(total),0) AS v FROM invoices WHERE created_at >= ?', [todayStart]),
        db.rawQuery('SELECT COALESCE(SUM(total),0) AS v FROM invoices'),
        db.rawQuery('SELECT COALESCE(SUM(total),0) AS v FROM invoices WHERE created_at >= ? AND created_at < ?', [prevWeekStart, weekStart]),
        db.rawQuery('SELECT COUNT(*) AS c FROM products'),
        db.rawQuery('SELECT COUNT(*) AS c FROM customers'),
        db.rawQuery('SELECT COUNT(*) AS c FROM invoices'),
        db.rawQuery('SELECT COALESCE(SUM(total),0) AS v FROM invoices WHERE id NOT IN (SELECT invoice_id FROM payments WHERE status = \'paid\')'),
        db.rawQuery('SELECT COUNT(*) AS c FROM invoices WHERE id NOT IN (SELECT invoice_id FROM payments WHERE status = \'paid\') AND created_at < ?', [now.subtract(const Duration(days: 5)).toUtc().toIso8601String()]),
        db.rawQuery('SELECT i.id, i.total, i.created_at, c.name AS customer, i.subtotal, i.coupon_discount, (SELECT p.status FROM payments p WHERE p.invoice_id = i.id ORDER BY p.id LIMIT 1) AS status FROM invoices i INNER JOIN customers c ON c.id = i.customer_id ORDER BY i.created_at DESC LIMIT 6'),
      ]);

      if (!mounted) return;
      setState(() {
        _todayRevenue = _num(results[0].first['v']);
        _totalRevenue = _num(results[1].first['v']);
        _prevWeekRevenue = _num(results[2].first['v']);
        _products = _num(results[3].first['c']).toInt();
        _customers = _num(results[4].first['c']).toInt();
        _invoices = _num(results[5].first['c']).toInt();
        _outstanding = _num(results[6].first['v']);
        _overdue = _num(results[7].first['c']).toInt();
        _recentInvoices = results[8];
        _loading = false;
      });
      _buildWeekSeries(db, now);
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Unable to load dashboard data.';
        });
      }
    }
  }

  Future<void> _buildWeekSeries(Database db, DateTime now) async {
    final days = <double>[];
    for (var i = 6; i >= 0; i--) {
      final dayStart = DateTime(now.year, now.month, now.day - i);
      final startStr = dayStart.toUtc().toIso8601String();
      final endStr = dayStart.add(const Duration(days: 1)).toUtc().toIso8601String();
      final rows = await db.rawQuery('SELECT COALESCE(SUM(total),0) AS v FROM invoices WHERE created_at >= ? AND created_at < ?', [startStr, endStr]);
      days.add(_num(rows.first['v']));
    }
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < 7; i++) {
        _week[i] = days[i];
      }
      _weekMax = days.reduce((a, b) => a > b ? a : b);
      if (_weekMax <= 0) _weekMax = 1;
    });
  }

  double _num(Object? value) => (value as num?)?.toDouble() ?? 0;

  String _money(double v, [int decimals = 0]) =>
      'EGP ${v.toStringAsFixed(decimals)}';

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 18) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader()),
          SliverToBoxAdapter(child: _buildBody()),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final colors = AppColors.of(context);
    final date = DateTime.now();
    final dateLabel = '${_monthName(date.month)} ${date.day}, ${date.year}';

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.lg, AppSpacing.lg, AppSpacing.lg, AppSpacing.sm),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$_greeting, Moamen', style: AppTextStyles.title(context).copyWith(fontSize: 17, color: colors.textMuted)),
                  const SizedBox(height: 4),
                  Text('Sales Overview', style: AppTextStyles.headline(context)),
                  const SizedBox(height: 4),
                  Text(dateLabel, style: TextStyle(color: colors.textMuted, fontSize: 13)),
                ],
              ),
            ),
            const _SecurityChip(),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    final colors = AppColors.of(context);
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: EmptyState(
          icon: Icons.error_outline_rounded,
          title: 'Something went wrong',
          message: _error!,
          actionLabel: 'Retry',
          onAction: _load,
        ),
      );
    }

    final last7 = _week.reduce((a, b) => a + b);
    final trend = _prevWeekRevenue > 0 ? ((last7 - _prevWeekRevenue) / _prevWeekRevenue * 100) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHero(trend),
          const SizedBox(height: AppSpacing.md),
          _buildKpis(),
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(title: 'Revenue - Last 7 days', subtitle: _money(last7)),
          const SizedBox(height: AppSpacing.md),
          _buildAnalytics(),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Quick actions'),
          const SizedBox(height: AppSpacing.md),
          _buildQuickActions(),
          if (_overdue > 0) ...[
            const SizedBox(height: AppSpacing.xl),
            _buildOverdueAlert(),
          ],
          const SizedBox(height: AppSpacing.xl),
          SectionHeader(title: 'Recent activity', actionLabel: 'View sales', onAction: () => widget.onNavigateTo(1)),
          const SizedBox(height: AppSpacing.md),
          _buildRecent(),
          const SizedBox(height: AppSpacing.xl),
          Text('Inventory alerts', style: AppTextStyles.title(context).copyWith(fontSize: 17)),
          const SizedBox(height: AppSpacing.md),
          _buildInventoryAlerts(colors),
        ],
      ),
    );
  }

  Widget _buildHero(double trend) {
    final colors = AppColors.of(context);
    final up = trend >= 0;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [colors.primary, Color.lerp(colors.primary, colors.accent, 0.35)!],
        ),
        borderRadius: AppRadius.xxlAll,
        boxShadow: [
          BoxShadow(color: colors.primary.withValues(alpha: 0.35), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Total Revenue', style: TextStyle(color: colors.onPrimary.withValues(alpha: 0.85), fontSize: 14, fontWeight: FontWeight.w600)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: colors.onPrimary.withValues(alpha: 0.16), borderRadius: AppRadius.xlAll),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 14, color: colors.onPrimary),
                    const SizedBox(width: 3),
                    Text('${up ? '+' : ''}${trend.toStringAsFixed(1)}%', style: TextStyle(color: colors.onPrimary, fontWeight: FontWeight.w700, fontSize: 12)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(_money(_totalRevenue, 2), style: TextStyle(color: colors.onPrimary, fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
          const SizedBox(height: AppSpacing.sm),
          Text('$_invoices invoices - $_todayRevenue today', style: TextStyle(color: colors.onPrimary.withValues(alpha: 0.85), fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildKpis() {
    return Row(
      children: [
        Expanded(child: KpiCard(title: 'Products', value: '$_products', icon: Icons.inventory_2_outlined)),
        const SizedBox(width: AppSpacing.sm),
        Expanded(child: KpiCard(title: 'Customers', value: '$_customers', icon: Icons.people_outline_rounded)),
      ],
    );
  }

  Widget _buildAnalytics() {
    final colors = AppColors.of(context);
    const weekdays = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 7; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    SizedBox(
                      height: 64,
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          width: 10,
                          height: ((_week[i] / _weekMax).clamp(0.02, 1)) * 64,
                          decoration: BoxDecoration(
                            color: i == 6 ? colors.accent : colors.primary.withValues(alpha: 0.45),
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(weekdays[i], style: TextStyle(color: colors.textMuted, fontSize: 11, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        _QuickAction(label: 'New Sale', icon: Icons.add_shopping_cart_rounded, onTap: () => widget.onNavigateTo(1)),
        const SizedBox(width: AppSpacing.sm),
        _QuickAction(label: 'Products', icon: Icons.inventory_2_outlined, onTap: () => widget.onNavigateTo(2)),
        const SizedBox(width: AppSpacing.sm),
        _QuickAction(label: 'Customers', icon: Icons.person_add_alt_1_rounded, onTap: () => widget.onNavigateTo(3)),
      ],
    );
  }

  Widget _buildOverdueAlert() {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.warningContainer,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: colors.warning.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule_rounded, color: colors.warning),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$_overdue overdue invoice${_overdue == 1 ? '' : 's'}', style: TextStyle(color: colors.onWarningContainer, fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text('Still unpaid. Total outstanding: ${_money(_outstanding, 2)}', style: TextStyle(color: colors.onWarningContainer, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecent() {
    if (_recentInvoices.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No sales yet',
        message: 'Create your first sale to see activity here.',
      );
    }
    return Column(
      children: [
        for (final invoice in _recentInvoices) _RecentTile(invoice: invoice),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  Widget _buildInventoryAlerts(AppColors colors) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: colors.infoContainer, borderRadius: AppRadius.mdAll),
            child: Icon(Icons.inventory_rounded, color: colors.info),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$_products products tracked', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                const SizedBox(height: 2),
                Text('Run a sale to keep stock moving.', style: TextStyle(color: colors.textMuted, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _monthName(int month) {
  const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return names[month - 1];
}

class _SecurityChip extends StatelessWidget {
  const _SecurityChip();

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: AppRadius.xlAll,
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fingerprint_rounded, size: 18, color: colors.success),
          const SizedBox(width: 6),
          Text('Protected', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w600, fontSize: 12)),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickAction({required this.label, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.lgAll,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
          decoration: BoxDecoration(
            color: colors.surface,
            borderRadius: AppRadius.lgAll,
            border: Border.all(color: colors.divider),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: colors.primaryContainer, borderRadius: AppRadius.mdAll),
                child: Icon(icon, size: 22, color: colors.primary),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(label, style: TextStyle(color: colors.textPrimary, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  final Map<String, Object?> invoice;

  const _RecentTile({required this.invoice});

  StatusType _statusType(String? status) => switch (status) {
        'paid' => StatusType.success,
        'pending' => StatusType.warning,
        'overdue' => StatusType.error,
        _ => StatusType.neutral,
      };

  String _statusLabel(String? status) => switch (status) {
        'paid' => 'Paid',
        'pending' => 'Pending',
        'overdue' => 'Overdue',
        _ => 'Unknown',
      };

  String _shortDate(String iso) {
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final status = invoice['status'] as String?;
    final total = (invoice['total'] as num?)?.toDouble() ?? 0;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.lgAll,
        border: Border.all(color: colors.divider, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: colors.surfaceMuted, borderRadius: AppRadius.mdAll),
            child: Text('#${invoice['id']}', style: TextStyle(color: colors.textSecondary, fontWeight: FontWeight.w700, fontSize: 13)),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${invoice['customer'] ?? 'Customer'}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text(_shortDate('${invoice['created_at']}'), style: TextStyle(color: colors.textMuted, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('EGP ${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 4),
              StatusBadge(type: _statusType(status), label: _statusLabel(status)),
            ],
          ),
        ],
      ),
    );
  }
}
