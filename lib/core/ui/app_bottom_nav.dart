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

/// Premium floating custom bottom navigation bar.
///
/// - Floating rounded surface with subtle border + elevation.
/// - Animated pill behind the active destination.
/// - Clear selected/unselected icon & label states.
/// - Safe-area and keyboard awareness is handled by the parent shell.
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
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: colors.surfaceElevated,
        borderRadius: AppRadius.xxlAll,
        border: Border.all(color: colors.divider, width: 1),
        boxShadow: [
          BoxShadow(
            color: colors.scrim.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            Expanded(child: _buildItem(context, i)),
          ],
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(i),
        child: AnimatedContainer(
          duration: AppDurations.normal,
          curve: Curves.easeOut,
          height: 52,
          decoration: BoxDecoration(
            color: selected ? colors.primary : Colors.transparent,
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
                    size: 22,
                    color: selected ? colors.onPrimary : colors.textSecondary,
                  ),
                  AnimatedSize(
                    duration: AppDurations.normal,
                    curve: Curves.easeOut,
                    child: selected
                        ? Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Text(
                              item.label,
                              style: TextStyle(
                                color: colors.onPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          )
                        : const SizedBox.shrink(),
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