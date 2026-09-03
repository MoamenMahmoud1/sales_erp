import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';
import '../theme/app_theme.dart';
import '../ui/app_card.dart';
import '../ui/section_header.dart';
import '../ui/status_badge.dart';

/// Global app settings shared by every application flavor.
class SettingsPage extends StatelessWidget {
  final AppThemeController themeController;
  final VoidCallback? onLock;
  final VoidCallback? onReset;
  final VoidCallback? onOpenCarApp;
  final bool showOperations;
  final String resetSubtitle;

  const SettingsPage({
    super.key,
    required this.themeController,
    this.onLock,
    this.onReset,
    this.onOpenCarApp,
    this.showOperations = true,
    this.resetSubtitle = 'Clear local database and re-seed demo data',
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          if (showOperations) ...[
            const SectionHeader(title: 'Operations'),
            const SizedBox(height: AppSpacing.md),
            AppCard(
              child: _ActionRow(
                icon: Icons.local_shipping_rounded,
                title: 'Car Sales',
                subtitle: 'Daily loads, returns, sold cartons, payments and reports',
                onTap: onOpenCarApp,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
          ],
          const SectionHeader(title: 'Appearance'),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              _ThemeOption(
                label: 'Light',
                icon: Icons.light_mode_rounded,
                selected: themeController.mode == AppThemeMode.light,
                onTap: () => themeController.setMode(AppThemeMode.light),
              ),
              const SizedBox(width: AppSpacing.md),
              _ThemeOption(
                label: 'Mid',
                icon: Icons.brightness_auto_rounded,
                selected: themeController.mode == AppThemeMode.mid,
                onTap: () => themeController.setMode(AppThemeMode.mid),
              ),
              const SizedBox(width: AppSpacing.md),
              _ThemeOption(
                label: 'Dark',
                icon: Icons.dark_mode_rounded,
                selected: themeController.mode == AppThemeMode.dark,
                onTap: () => themeController.setMode(AppThemeMode.dark),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Data'),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    borderRadius: AppRadius.mdAll,
                  ),
                  child: Icon(Icons.phone_iphone_rounded, color: colors.primary),
                ),
                const SizedBox(width: AppSpacing.md),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Local mode', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                      SizedBox(height: 2),
                      Text('100% on-device. No server required.', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                const StatusBadge(
                  type: StatusType.success,
                  label: 'Local',
                  icon: Icons.offline_pin_rounded,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          const SectionHeader(title: 'Security'),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            child: Column(
              children: [
                _ActionRow(
                  icon: Icons.lock_outline_rounded,
                  title: 'Lock now',
                  subtitle: 'Require biometrics to unlock',
                  onTap: onLock,
                ),
                const Divider(height: 24),
                _ActionRow(
                  icon: Icons.restart_alt_rounded,
                  title: 'Reset device data',
                  subtitle: resetSubtitle,
                  onTap: onReset,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xxl),
          Center(
            child: Text('Sales ERP v1.0.0', style: TextStyle(color: colors.textMuted, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _ThemeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Expanded(
      child: Material(
        color: selected ? colors.primaryContainer : colors.surface,
        borderRadius: AppRadius.lgAll,
        child: InkWell(
          onTap: onTap,
          borderRadius: AppRadius.lgAll,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: AppRadius.lgAll,
              border: Border.all(
                color: selected ? colors.primary : colors.divider,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Icon(icon, size: 26, color: selected ? colors.primary : colors.textSecondary),
                const SizedBox(height: AppSpacing.sm),
                Text(label, style: TextStyle(color: selected ? colors.primary : colors.textSecondary, fontWeight: FontWeight.w700, fontSize: 13)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: colors.primary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 13)),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}
