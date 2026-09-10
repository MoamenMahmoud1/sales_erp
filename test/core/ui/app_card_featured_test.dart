import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sales_erp/core/theme/app_colors.dart';
import 'package:sales_erp/core/theme/app_theme.dart';
import 'package:sales_erp/core/theme/app_tokens.dart';
import 'package:sales_erp/core/ui/app_card.dart';

void main() {
  final themes = <String, ThemeData>{
    'light': AppTheme.light(),
    'mid': AppTheme.mid(),
    'dark': AppTheme.dark(),
  };

  for (final entry in themes.entries) {
    testWidgets('featured AppCard renders its child in ${entry.key} theme', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: entry.value,
          home: AppCard(
            padding: const EdgeInsets.all(17),
            borderRadius: AppRadius.xlAll,
            color: entry.value.colorScheme.secondaryContainer,
            child: const Text('Buying today'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Buying today'), findsOneWidget);

      final card = tester.widget<AnimatedContainer>(
        find.byType(AnimatedContainer).first,
      );
      final decoration = card.decoration! as BoxDecoration;
      final gradient = decoration.gradient! as LinearGradient;
      final colors = entry.key == 'light'
          ? AppColors.light
          : entry.key == 'mid'
              ? AppColors.mid
              : AppColors.dark;

      expect(gradient.colors[1], colors.featuredMiddle);
      expect(gradient.begin, Alignment.bottomLeft);
      expect(gradient.end, Alignment.topRight);
    });
  }
}
