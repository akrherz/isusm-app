import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/station.dart';

class StationMap extends StatelessWidget {
  const StationMap({
    required this.stations,
    required this.selectedStation,
    required this.onStationSelected,
    super.key,
  });

  final List<Station> stations;
  final Station? selectedStation;
  final ValueChanged<Station> onStationSelected;

  @override
  Widget build(BuildContext context) {
    if (stations.isEmpty) {
      return const SizedBox(
        height: 320,
        child: Center(child: Text('No station locations available.')),
      );
    }

    return SizedBox(
      height: 320,
      child: FlutterMap(
        options: const MapOptions(
          initialCenter: LatLng(42.0, -93.5),
          initialZoom: 6.2,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'edu.iastate.mesonet.isusm_app',
          ),
          MarkerLayer(
            markers: [
              for (final station in stations)
                Marker(
                  point: LatLng(station.latitude, station.longitude),
                  width: 44,
                  height: 44,
                  child: IconButton(
                    tooltip: station.name,
                    padding: EdgeInsets.zero,
                    onPressed: () => onStationSelected(station),
                    icon: Icon(
                      Icons.location_on,
                      size: 36,
                      color: station.id == selectedStation?.id
                          ? Theme.of(context).colorScheme.primary
                          : Colors.red.shade700,
                    ),
                  ),
                ),
            ],
          ),
          const RichAttributionWidget(
            attributions: [
              TextSourceAttribution('© OpenStreetMap contributors'),
            ],
          ),
        ],
      ),
    );
  }
}
