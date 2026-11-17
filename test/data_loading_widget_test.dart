import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:travel_expenses_app/widgets/data_loading_widget.dart';

void main() {
  testWidgets('shows connection error after ten seconds', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: DataLoadingWidget()),
      ),
    );

    expect(find.text('Загружаем данные...'), findsOneWidget);

    await tester.pump(const Duration(seconds: 10));

    expect(
      find.text('Не удалось подключиться к базе данных. Проверьте интернет.'),
      findsOneWidget,
    );
  });
}
