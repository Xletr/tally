import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/expense_category.dart';
import 'category_icon.dart';

class CategoryPieChart extends StatelessWidget {
  const CategoryPieChart({super.key, required this.data});

  final Map<ExpenseCategory, double> data;

  @override
  Widget build(BuildContext context) {
    final total = data.values.fold<double>(0, (sum, value) => sum + value);
    if (total == 0) {
      return const SizedBox.shrink();
    }
    final colorScheme = Theme.of(context).colorScheme;
    final colors = <ExpenseCategory, Color>{
      ExpenseCategory.food: colorScheme.primaryContainer,
      ExpenseCategory.transport: colorScheme.secondaryContainer,
      ExpenseCategory.subscriptions: colorScheme.tertiaryContainer,
      ExpenseCategory.purchases: colorScheme.errorContainer,
      ExpenseCategory.misc: colorScheme.surfaceContainerHighest,
      ExpenseCategory.savings: colorScheme.primary,
    };

    final sections = data.entries.map((entry) {
      final percentage = (entry.value / total) * 100;
      final sliceColor = colors[entry.key] ?? colorScheme.primaryContainer;
      final luminance = sliceColor.computeLuminance();
      final textColor = luminance > 0.55 ? colorScheme.onSurface : Colors.white;
      final badgeBackground = luminance > 0.55
          ? colorScheme.onSurface.withValues(alpha: 0.08)
          : colorScheme.surface.withValues(alpha: 0.9);
      final iconColor = luminance > 0.55
          ? Color.alphaBlend(
              colorScheme.onSurface.withValues(alpha: 0.6),
              sliceColor,
            )
          : Colors.white;
      return PieChartSectionData(
        color: sliceColor,
        value: entry.value,
        radius: 48,
        titleStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
        title: '${percentage.toStringAsFixed(0)}%',
        badgeWidget: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: badgeBackground,
            shape: BoxShape.circle,
            border: Border.all(
              color: colorScheme.outline.withValues(alpha: 0.15),
            ),
          ),
          alignment: Alignment.center,
          child: Icon(categoryIcon(entry.key), size: 15, color: iconColor),
        ),
        badgePositionPercentageOffset: 0.9,
      );
    }).toList();

    return PieChart(
      PieChartData(sectionsSpace: 2, centerSpaceRadius: 48, sections: sections),
    );
  }
}
