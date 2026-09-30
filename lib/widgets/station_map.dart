import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/observation.dart';
import '../models/station.dart';

enum StationMapVariable {
  airTemperature('Air temperature', '°F'),
  dewPoint('Dew point', '°F'),
  relativeHumidity('Relative humidity', '%'),
  dailyHigh('Today\'s high', '°F'),
  dailyLow('Today\'s low', '°F'),
  hourlyPrecipitation('Hourly precipitation', 'in'),
  dailyPrecipitation('Today\'s precipitation', 'in'),
  trailingPrecipitation('Trailing 24-hour precipitation', 'in'),
  monthlyPrecipitation('Month precipitation', 'in'),
  dailyEt('Daily ET', 'in'),
  solarRadiation('Solar radiation', 'W/m²'),
  windGust('Wind gust', 'mph'),
  soilTemperature4('Soil temperature (4 in)', '°F'),
  soilTemperature12('Soil temperature (12 in)', '°F'),
  soilTemperature24('Soil temperature (24 in)', '°F'),
  soilTemperature50('Soil temperature (50 in)', '°F'),
  soilMoisture12('Soil moisture (12 in)', '%'),
  soilMoisture24('Soil moisture (24 in)', '%'),
  soilMoisture50('Soil moisture (50 in)', '%'),
  batteryVoltage('Battery voltage', 'V');

  const StationMapVariable(this.label, this.unit);

  final String label;
  final String unit;

  double? valueFor(Observation observation) => switch (this) {
    StationMapVariable.airTemperature => observation.tmpf,
    StationMapVariable.dewPoint => observation.dwpf,
    StationMapVariable.relativeHumidity => observation.rh,
    StationMapVariable.dailyHigh => observation.high,
    StationMapVariable.dailyLow => observation.low,
    StationMapVariable.hourlyPrecipitation => observation.hrprecip,
    StationMapVariable.dailyPrecipitation => observation.pday,
    StationMapVariable.trailingPrecipitation => observation.p24i,
    StationMapVariable.monthlyPrecipitation => observation.pmonth,
    StationMapVariable.dailyEt => observation.dailyet,
    StationMapVariable.solarRadiation => observation.sradWm2,
    StationMapVariable.windGust => observation.gust,
    StationMapVariable.soilTemperature4 => observation.soil04t,
    StationMapVariable.soilTemperature12 => observation.soil12t,
    StationMapVariable.soilTemperature24 => observation.soil24t,
    StationMapVariable.soilTemperature50 => observation.soil50t,
    StationMapVariable.soilMoisture12 => observation.soil12m,
    StationMapVariable.soilMoisture24 => observation.soil24m,
    StationMapVariable.soilMoisture50 => observation.soil50m,
    StationMapVariable.batteryVoltage => observation.bat,
  };
}

class StationMap extends StatefulWidget {
  const StationMap({
    required this.stations,
    required this.observations,
    required this.selectedStationIds,
    required this.onStationSelected,
    super.key,
  });

  final List<Station> stations;
  final Map<String, Observation> observations;
  final Set<String> selectedStationIds;
  final ValueChanged<Station> onStationSelected;

  @override
  State<StationMap> createState() => _StationMapState();
}

class _StationMapState extends State<StationMap> {
  StationMapVariable _variable = StationMapVariable.airTemperature;

  @override
  Widget build(BuildContext context) {
    if (widget.stations.isEmpty) {
      return const SizedBox(
        height: 320,
        child: Center(child: Text('No station locations available.')),
      );
    }

    final stationValues = <String, double?>{
      for (final station in widget.stations)
        station.id: widget.observations[station.id] == null
            ? null
            : _variable.valueFor(widget.observations[station.id]!),
    };
    final values = stationValues.values.whereType<double>().toList();
    final minimum = values.isEmpty ? 0.0 : values.reduce(_min);
    final maximum = values.isEmpty ? 0.0 : values.reduce(_max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: DropdownButtonFormField<StationMapVariable>(
            initialValue: _variable,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Map variable',
              prefixIcon: Icon(Icons.tune),
              border: OutlineInputBorder(),
            ),
            items: StationMapVariable.values
                .map(
                  (variable) => DropdownMenuItem(
                    value: variable,
                    child: Text(variable.label),
                  ),
                )
                .toList(),
            onChanged: (variable) {
              if (variable != null) setState(() => _variable = variable);
            },
          ),
        ),
        _buildLegend(context, minimum, maximum, values.isNotEmpty),
        SizedBox(
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
                  for (final station in widget.stations)
                    _buildMarker(
                      station,
                      stationValues[station.id],
                      minimum,
                      maximum,
                    ),
                ],
              ),
            ],
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Center(
            child: Text(
              '© OpenStreetMap contributors',
              style: TextStyle(fontSize: 11),
            ),
          ),
        ),
      ],
    );
  }

  Marker _buildMarker(
    Station station,
    double? value,
    double minimum,
    double maximum,
  ) {
    final color = _colorForValue(value, minimum, maximum);
    final selected = widget.selectedStationIds.contains(station.id);
    final reading = value == null ? 'No reading' : _formatValue(value);

    return Marker(
      point: LatLng(station.latitude, station.longitude),
      width: 52,
      height: 52,
      child: Tooltip(
        message:
            '${station.name}\n'
            '${selected ? 'In My stations' : 'Tap to add to My stations'}\n'
            '${_variable.label}: $reading',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => widget.onStationSelected(station),
            child: Container(
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? Colors.black87 : Colors.white,
                  width: selected ? 3 : 2,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Padding(
                  padding: const EdgeInsets.all(5),
                  child: Text(
                    value == null ? '--' : _markerValue(value),
                    style: TextStyle(
                      color:
                          ThemeData.estimateBrightnessForColor(color) ==
                              Brightness.dark
                          ? Colors.white
                          : Colors.black87,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLegend(
    BuildContext context,
    double minimum,
    double maximum,
    bool hasValues,
  ) {
    if (!hasValues) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Text('No ${_variable.label.toLowerCase()} readings available.'),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _variable.unit.isEmpty
                ? _variable.label
                : '${_variable.label} (${_variable.unit})',
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          Container(
            height: 10,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(5),
              gradient: LinearGradient(
                colors: [
                  Colors.blue.shade700,
                  Colors.amber,
                  Colors.red.shade700,
                ],
              ),
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_formatValue(minimum)),
              Text(_formatValue(maximum)),
            ],
          ),
        ],
      ),
    );
  }

  Color _colorForValue(double? value, double minimum, double maximum) {
    if (value == null) return Colors.blueGrey.shade500;
    final ratio = maximum == minimum
        ? 0.5
        : ((value - minimum) / (maximum - minimum)).clamp(0.0, 1.0).toDouble();
    if (ratio <= 0.5) {
      return Color.lerp(Colors.blue.shade700, Colors.amber, ratio * 2)!;
    }
    return Color.lerp(Colors.amber, Colors.red.shade700, (ratio - 0.5) * 2)!;
  }

  String _formatValue(double value) {
    final decimals = value.abs() >= 100 ? 0 : 1;
    return '${value.toStringAsFixed(decimals)} ${_variable.unit}'.trim();
  }

  String _markerValue(double value) {
    return value.abs() >= 100
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1);
  }

  double _min(double first, double second) => first < second ? first : second;

  double _max(double first, double second) => first > second ? first : second;
}
