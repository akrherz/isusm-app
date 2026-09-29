// Basic smoke test verifying the app shell renders without crashing.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:isusm_app/main.dart';

void main() {
  testWidgets('App renders home screen with title', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const IsusmApp());

    expect(find.text('ISU Soil Moisture App'), findsOneWidget);
    expect(find.text('Add stations'), findsOneWidget);
    expect(find.byTooltip('Open navigation menu'), findsOneWidget);

    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Dashboard'), findsOneWidget);
    expect(find.text('Stations'), findsOneWidget);
  });
}
