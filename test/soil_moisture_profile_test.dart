import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isusm_app/models/observation.dart';
import 'package:isusm_app/widgets/soil_moisture_profile.dart';

void main() {
  testWidgets('shows moisture at each depth on a 0-55 percent scale', (
    tester,
  ) async {
    final observation = Observation(
      stationId: 'TEST',
      name: 'Test Station',
      validUtc: DateTime.utc(2026, 9, 30),
      soil12m: 48.4,
      soil24m: 110,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: SoilMoistureProfile(observation: observation)),
      ),
    );

    expect(find.text('Soil moisture profile'), findsOneWidget);
    expect(find.text('12 in'), findsOneWidget);
    expect(find.text('24 in'), findsOneWidget);
    expect(find.text('50 in'), findsOneWidget);
    expect(find.text('48.4%'), findsOneWidget);
    expect(find.text('110.0%'), findsOneWidget);
    expect(find.text('M'), findsOneWidget);

    final indicators = tester.widgetList<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(find.text('0%'), findsOneWidget);
    expect(find.text('55%'), findsOneWidget);
    expect(indicators.map((indicator) => indicator.value), [48.4 / 55, 1.0, 0]);
  });
}