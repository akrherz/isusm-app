// Basic smoke test verifying the app shell renders without crashing.

import 'package:flutter_test/flutter_test.dart';

import 'package:isusm_app/main.dart';

void main() {
  testWidgets('App renders home screen with title', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const IsusmApp());

    expect(find.text('ISU Soil Moisture App'), findsOneWidget);
    expect(find.text('Add stations'), findsOneWidget);
  });
}
