import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isusm_app/models/station.dart';
import 'package:isusm_app/widgets/station_picker_dialog.dart';

void main() {
  testWidgets('filters by name or ID and returns selected stations', (
    tester,
  ) async {
    final stations = [
      const Station(
        id: 'NORTH',
        name: 'North Field',
        latitude: 42,
        longitude: -93,
      ),
      const Station(
        id: 'SOUTH',
        name: 'South Field',
        latitude: 41,
        longitude: -93,
      ),
    ];
    Set<String>? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showDialog<Set<String>>(
                  context: context,
                  builder: (context) => StationPickerDialog(
                    stations: stations,
                    selectedStationIds: const {'SOUTH'},
                  ),
                );
              },
              child: const Text('Open picker'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
    expect(find.text('North Field'), findsOneWidget);
    expect(find.text('South Field'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'north');
    await tester.pumpAndSettle();
    expect(find.text('North Field'), findsOneWidget);
    expect(find.text('South Field'), findsNothing);

    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(find.text('Choose stations (2 selected)'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'south');
    await tester.pumpAndSettle();
    expect(find.text('South Field'), findsOneWidget);
    expect(find.text('North Field'), findsNothing);
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(result, {'NORTH', 'SOUTH'});
  });
}
