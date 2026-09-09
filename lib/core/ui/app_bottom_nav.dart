import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_tokens.dart';

/// A single navigation destination shown in [AppBottomNav].
class AppNavItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const AppNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// Compact mobile navigation with a restrained selected state.
///
/// The parent shell remains responsible for safe-area and keyboard handling.
class AppBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final List<AppNavItem> items;

  const AppBottomNav({
    super.key,
    required this.index,
    required this.onChanged,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: AppRadius.xlAll,
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) Expanded(child: _buildItem(context, i)),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, int i) {
    final colors = AppColors.of(context);
    final item = items[i];
    final selected = i == index;

    return Semantics(
      selected: selected,
      label: item.label,
      button: true,
      child: InkWell(
        borderRadius: AppRadius.lgAll,
        onTap: () => onChanged(i),
        child: AnimatedContainer(
          duration: AppDurations.normal,
          curve: Curves.easeOutCubic,
          height: 50,
          decoration: BoxDecoration(
            color: selected ? colors.primaryContainer : Colors.transparent,
            borderRadius: AppRadius.lgAll,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    selected ? item.selectedIcon : item.icon,
                    size: 21,
                    color: selected ? colors.onPrimaryContainer : colors.textSecondary,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    item.label,
                    style: TextStyle(
                      color: selected ? colors.onPrimaryContainer : colors.textMuted,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
