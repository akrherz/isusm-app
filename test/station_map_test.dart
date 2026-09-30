import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isusm_app/models/station.dart';
import 'package:isusm_app/widgets/station_map.dart';

void main() {
  testWidgets('tapping a station marker reports the station to add', (
    tester,
  ) async {
    const station = Station(
      id: 'NORTH',
      name: 'North Field',
      latitude: 42,
      longitude: -93.5,
    );
    Station? tappedStation;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 500,
            child: StationMap(
              stations: const [station],
              observations: const {},
              selectedStationIds: const {},
              onStationSelected: (selected) => tappedStation = selected,
            ),
          ),
        ),
      ),
    );

    const tooltip =
        'North Field\nTap to add to My stations\nAir temperature: No reading';
    expect(find.byTooltip(tooltip), findsOneWidget);

    await tester.tap(find.byTooltip(tooltip));
    await tester.pump();

    expect(tappedStation?.id, 'NORTH');
  });
}
