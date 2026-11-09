import 'package:flutter/material.dart';

import '../models/spending_category.dart';

class CategoryDropdown extends StatelessWidget {
  final SpendingCategory value;
  final ValueChanged<SpendingCategory> onChanged;

  const CategoryDropdown({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<SpendingCategory>(
      key: ValueKey(value),
      initialValue: value,
      decoration: const InputDecoration(
        labelText: 'Категория',
        border: OutlineInputBorder(),
      ),
      items: SpendingCategory.values
          .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}
