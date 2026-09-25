import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/daily_forecast.dart';
import '../models/observation.dart';
import '../models/station.dart';
import '../services/mesonet_service.dart';
import '../services/nws_forecast_service.dart';
import '../widgets/station_map.dart';

const Duration _refreshInterval = Duration(minutes: 5);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final MesonetService _service = MesonetService();
  final NwsForecastService _forecastService = NwsForecastService();
  Timer? _refreshTimer;

  List<Station> _stations = [];
  Map<String, Observation> _observations = {};
  List<DailyForecast> _forecast = [];
  Station? _selectedStation;

  bool _loadingStations = true;
  bool _loadingObservation = false;
  bool _loadingForecast = false;
  String? _error;
  String? _forecastError;
  DateTime? _lastRefreshed;
  int _forecastRequestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _loadStations();
    _refreshTimer = Timer.periodic(
      _refreshInterval,
      (_) => _loadObservations(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _service.dispose();
    _forecastService.dispose();
    super.dispose();
  }

  Future<void> _loadStations() async {
    setState(() {
      _loadingStations = true;
      _error = null;
    });
    try {
      final stations = await _service.fetchStations();
      setState(() {
        _stations = stations;
        _selectedStation = stations.isNotEmpty ? stations.first : null;
        _loadingStations = false;
      });
      final station = _selectedStation;
      await Future.wait([
        _loadObservations(),
        if (station != null) _loadForecast(station),
      ]);
    } catch (e) {
      setState(() {
        _error = 'Unable to load stations: $e';
        _loadingStations = false;
      });
    }
  }

  Future<void> _loadObservations() async {
    setState(() => _loadingObservation = true);
    try {
      final observations = await _service.fetchObservations();
      setState(() {
        _observations = observations;
        _loadingObservation = false;
        _lastRefreshed = DateTime.now();
        _error = null;
      });
    } catch (e) {
      setState(() {
        _error = 'Unable to load observations: $e';
        _loadingObservation = false;
      });
    }
  }

  Future<void> _loadForecast(Station station) async {
    final requestGeneration = ++_forecastRequestGeneration;
    setState(() {
      _loadingForecast = true;
      _forecastError = null;
    });
    try {
      final forecast = await _forecastService.fetchDailyForecast(station);
      if (!mounted ||
          _forecastRequestGeneration != requestGeneration ||
          _selectedStation?.id != station.id) {
        return;
      }
      setState(() {
        _forecast = forecast;
        _loadingForecast = false;
      });
    } catch (e) {
      if (!mounted ||
          _forecastRequestGeneration != requestGeneration ||
          _selectedStation?.id != station.id) {
        return;
      }
      setState(() {
        _forecastError = 'Unable to load the NWS forecast: $e';
        _loadingForecast = false;
      });
    }
  }

  void _selectStation(Station? station) {
    setState(() {
      _selectedStation = station;
      _forecast = [];
      _forecastError = null;
      _loadingForecast = station != null;
    });
    if (station != null) _loadForecast(station);
  }

  Future<void> _refresh() async {
    final station = _selectedStation;
    await Future.wait([
      _loadObservations(),
      if (station != null) _loadForecast(station),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final observation = _selectedStation == null
        ? null
        : _observations[_selectedStation!.id];

    return Scaffold(
      appBar: AppBar(title: const Text('ISU Soil Moisture App')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildStationSelector(),
            const SizedBox(height: 16),
            _buildStationMap(),
            if (_error != null) _buildError(_error!),
            if (_loadingStations)
              const Center(child: CircularProgressIndicator())
            else if (_selectedStation != null)
              _buildObservationCard(observation),
            if (!_loadingStations && _selectedStation != null)
              _buildForecastSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildStationSelector() {
    return DropdownButtonFormField<Station>(
      key: ValueKey(_selectedStation?.id),
      initialValue: _selectedStation,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Station',
        border: OutlineInputBorder(),
      ),
      items: _stations
          .map(
            (station) => DropdownMenuItem(
              value: station,
              child: Text(station.name, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: _selectStation,
    );
  }

  Widget _buildStationMap() {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              children: [
                const Icon(Icons.map_outlined),
                const SizedBox(width: 8),
                Text(
                  'Station Map',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
          ),
          if (_loadingStations)
            const SizedBox(
              height: 320,
              child: Center(child: CircularProgressIndicator()),
            )
          else
            StationMap(
              stations: _stations,
              selectedStation: _selectedStation,
              onStationSelected: _selectStation,
            ),
        ],
      ),
    );
  }

  Widget _buildForecastSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.cloud_outlined),
                const SizedBox(width: 8),
                Text(
                  'NWS Forecast',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const Divider(),
            if (_loadingForecast && _forecast.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_forecastError != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_forecastError!),
                  TextButton.icon(
                    onPressed: _selectedStation == null
                        ? null
                        : () => _loadForecast(_selectedStation!),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              )
            else if (_forecast.isEmpty)
              const Text('No daily forecast available.')
            else
              for (final day in _forecast) _buildForecastDay(day),
          ],
        ),
      ),
    );
  }

  Widget _buildForecastDay(DailyForecast day) {
    final precipitation = day.precipitationChance == null
        ? 'Precip --'
        : 'Precip ${day.precipitationChance}%';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  day.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(precipitation),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'High ${_formatTemperature(day.high, day.temperatureUnit)}  '
            'Low ${_formatTemperature(day.low, day.temperatureUnit)}',
          ),
          if (day != _forecast.last) const Divider(height: 16),
        ],
      ),
    );
  }

  String _formatTemperature(int? value, String unit) {
    if (value == null) return '--';
    return '$value°$unit';
  }

  Widget _buildError(String message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(message, style: const TextStyle(color: Colors.red)),
    );
  }

  Widget _buildObservationCard(Observation? observation) {
    if (_loadingObservation && observation == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (observation == null) {
      return const Text('No observation data available for this station.');
    }

    final validLocal = observation.validUtc.toLocal();
    final rows = <(String, String)>[
      ('Observation Time', DateFormat.yMd().add_jm().format(validLocal)),
      ('Air Temperature', _fmt(observation.tmpf, '°F')),
      ('Dew Point', _fmt(observation.dwpf, '°F')),
      ('Relative Humidity', _fmt(observation.rh, '%')),
      ('Today\'s High', _fmt(observation.high, '°F')),
      ('Today\'s Low', _fmt(observation.low, '°F')),
      ('Wind', observation.wind ?? 'M'),
      ('Wind Gust', _fmt(observation.gust, 'mph')),
      ('Solar Radiation', _fmt(observation.sradWm2, 'W/m²')),
      ('Hourly Precip', _fmt(observation.hrprecip, 'in')),
      ('Today\'s Precip', _fmt(observation.pday, 'in')),
      ('Trailing 24hr Precip', _fmt(observation.p24i, 'in')),
      ('Month Precip', _fmt(observation.pmonth, 'in')),
      ('Daily ET', _fmt(observation.dailyet, 'in')),
      ('Soil Temp (4in)', _fmt(observation.soil04t, '°F')),
      ('Soil Temp (12in)', _fmt(observation.soil12t, '°F')),
      ('Soil Temp (24in)', _fmt(observation.soil24t, '°F')),
      ('Soil Temp (50in)', _fmt(observation.soil50t, '°F')),
      ('Soil Moisture (12in)', _fmt(observation.soil12m, '%')),
      ('Soil Moisture (24in)', _fmt(observation.soil24m, '%')),
      ('Soil Moisture (50in)', _fmt(observation.soil50m, '%')),
      ('Battery Voltage', _fmt(observation.bat, 'V')),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              observation.name,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Divider(),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text(row.$1), Text(row.$2)],
                ),
              ),
            const SizedBox(height: 8),
            if (_lastRefreshed != null)
              Text(
                'Last refreshed: ${DateFormat.jm().format(_lastRefreshed!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
      ),
    );
  }

  String _fmt(double? value, String unit) {
    if (value == null) return 'M';
    return '${value.toStringAsFixed(1)} $unit';
  }
}
