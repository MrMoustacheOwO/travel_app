/// Общая категория для активностей и расходов.
/// Хранится в БД как строка (name), поэтому легко переносится в JSON
/// для будущего REST API без изменений формата.
enum SpendingCategory {
  food('Питание'),
  tickets('Транспорт'),
  accommodation('Проживание'),
  entertainment('Развлечения'),
  excursions('Экскурсии'),
  shopping('Покупки'),
  other('Другое');

  final String label;
  const SpendingCategory(this.label);

  String get storageKey => name;

  static SpendingCategory fromStorageKey(String key) {
    return SpendingCategory.values.firstWhere(
      (e) => e.name == key,
      orElse: () => SpendingCategory.other,
    );
  }
}
