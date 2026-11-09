import 'package:flutter/material.dart';

import '../models/spending_category.dart';

class CategoryFilterButton extends StatelessWidget {
  final Set<SpendingCategory> selected;
  final ValueChanged<Set<SpendingCategory>> onChanged;
  final bool mainOnly;
  final ValueChanged<bool>? onMainOnlyChanged;

  const CategoryFilterButton({
    super.key,
    required this.selected,
    required this.onChanged,
    this.mainOnly = false,
    this.onMainOnlyChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hasFilter = selected.isNotEmpty || mainOnly;
    final filterCount = selected.length + (mainOnly ? 1 : 0);

    return MenuAnchor(
      builder: (context, controller, _) {
        return IconButton(
          tooltip: 'Фильтр',
          icon: Badge(
            isLabelVisible: hasFilter,
            label: Text('$filterCount'),
            child: Icon(
              hasFilter ? Icons.filter_alt : Icons.filter_alt_outlined,
            ),
          ),
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
        );
      },
      menuChildren: [
        MenuItemButton(
          closeOnActivate: false,
          leadingIcon: const Icon(Icons.clear_all),
          onPressed: hasFilter ? () => onChanged({}) : null,
          child: const Text('Сбросить'),
        ),
        const Divider(height: 1),
        if (onMainOnlyChanged != null)
          CheckboxMenuButton(
            closeOnActivate: false,
            value: mainOnly,
            onChanged: (checked) => onMainOnlyChanged!(checked ?? false),
            child: const Text('Главная активность'),
          ),
        if (onMainOnlyChanged != null) const Divider(height: 1),
        for (final category in SpendingCategory.values)
          CheckboxMenuButton(
            closeOnActivate: false,
            value: selected.contains(category),
            onChanged: (checked) {
              final next = Set<SpendingCategory>.of(selected);
              if (checked ?? false) {
                next.add(category);
              } else {
                next.remove(category);
              }
              onChanged(next);
            },
            child: Text(category.label),
          ),
      ],
    );
  }
}