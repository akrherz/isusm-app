import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_forecast.dart';
import '../models/observation.dart';
import '../models/station.dart';
import '../services/mesonet_service.dart';
import '../services/nws_forecast_service.dart';
import '../widgets/station_map.dart';

const Duration _refreshInterval = Duration(minutes: 5);
const String _stationIdsPreferenceKey = 'dashboard_station_ids';

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
  final List<String> _stationIds = [];
  final Map<String, List<DailyForecast>> _forecasts = {};
  final Set<String> _loadingForecasts = {};
  final Map<String, String> _forecastErrors = {};

  bool _loadingStations = true;
  bool _loadingObservation = false;
  String? _error;
  final Map<String, int> _forecastRequestGenerations = {};

  @override
  void initState() {
    super.initState();
    _loadDashboard();
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

  Future<void> _loadDashboard() async {
    setState(() {
      _loadingStations = true;
      _error = null;
    });
    try {
      final preferences = await SharedPreferences.getInstance();
      final savedStationIds =
          preferences.getStringList(_stationIdsPreferenceKey) ?? [];
      final stations = await _service.fetchStations();
      if (!mounted) return;
      final availableStationIds = stations.map((station) => station.id).toSet();
      setState(() {
        _stations = stations;
        _stationIds
          ..clear()
          ..addAll(savedStationIds.where(availableStationIds.contains));
        _loadingStations = false;
      });
      await Future.wait([
        _loadObservations(),
        for (final station in _selectedStations) _loadForecast(station),
      ]);
    } catch (e) {
      if (!mounted) return;
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
      if (!mounted) return;
      setState(() {
        _observations = observations;
        _loadingObservation = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load observations: $e';
        _loadingObservation = false;
      });
    }
  }

  Future<void> _loadForecast(Station station) async {
    final requestGeneration =
        (_forecastRequestGenerations[station.id] ?? 0) + 1;
    _forecastRequestGenerations[station.id] = requestGeneration;
    setState(() {
      _loadingForecasts.add(station.id);
      _forecastErrors.remove(station.id);
    });
    try {
      final forecast = await _forecastService.fetchDailyForecast(station);
      if (!mounted ||
          _forecastRequestGenerations[station.id] != requestGeneration ||
          !_stationIds.contains(station.id)) {
        return;
      }
      setState(() {
        _forecasts[station.id] = forecast;
        _loadingForecasts.remove(station.id);
      });
    } catch (e) {
      if (!mounted ||
          _forecastRequestGenerations[station.id] != requestGeneration ||
          !_stationIds.contains(station.id)) {
        return;
      }
      setState(() {
        _forecastErrors[station.id] = 'Unable to load the NWS forecast: $e';
        _loadingForecasts.remove(station.id);
      });
    }
  }

  List<Station> get _selectedStations =>
      _stations.where((station) => _stationIds.contains(station.id)).toList();

  Future<void> _manageStations() async {
    final selectedIds = Set<String>.of(_stationIds);
    final updatedIds = await showDialog<Set<String>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Choose stations'),
          content: SizedBox(
            width: 420,
            height: 420,
            child: ListView.builder(
              itemCount: _stations.length,
              itemBuilder: (context, index) {
                final station = _stations[index];
                return CheckboxListTile(
                  value: selectedIds.contains(station.id),
                  title: Text(station.name),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (selected) => setDialogState(() {
                    if (selected ?? false) {
                      selectedIds.add(station.id);
                    } else {
                      selectedIds.remove(station.id);
                    }
                  }),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, selectedIds),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
    if (updatedIds == null || !mounted) return;
    await _updateStationSelection(updatedIds);
  }

  Future<void> _updateStationSelection(Set<String> stationIds) async {
    final previousIds = Set<String>.of(_stationIds);
    setState(() {
      _stationIds
        ..clear()
        ..addAll(
          _stations
              .where((station) => stationIds.contains(station.id))
              .map((station) => station.id),
        );
    });
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _stationIdsPreferenceKey,
      List<String>.of(_stationIds),
    );
    for (final station in _selectedStations) {
      if (!previousIds.contains(station.id)) _loadForecast(station);
    }
    for (final removedId in previousIds.difference(_stationIds.toSet())) {
      _forecastRequestGenerations[removedId] =
          (_forecastRequestGenerations[removedId] ?? 0) + 1;
    }
  }

  Future<void> _refresh() async {
    await Future.wait([
      _loadObservations(),
      for (final station in _selectedStations) _loadForecast(station),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ISU Soil Moisture App')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'My stations',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                FilledButton.icon(
                  onPressed: _loadingStations ? null : _manageStations,
                  icon: const Icon(Icons.add),
                  label: const Text('Add stations'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('${_stationIds.length} selected'),
            if (_error != null) _buildError(_error!),
            if (_loadingStations)
              const Center(child: CircularProgressIndicator())
            else if (_selectedStations.isEmpty)
              _buildEmptyDashboard()
            else
              for (final station in _selectedStations)
                _buildStationCard(station, _observations[station.id]),
            const SizedBox(height: 8),
            _buildStationMap(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyDashboard() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      child: Column(
        children: [
          Icon(
            Icons.dashboard_customize_outlined,
            size: 42,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'No stations added',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text('Choose stations to build your dashboard.'),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _manageStations,
            icon: const Icon(Icons.add),
            label: const Text('Add stations'),
          ),
        ],
      ),
    );
  }

  Widget _buildStationMap() {
    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.map_outlined),
        title: const Text('Explore station data map'),
        children: [
          if (_loadingStations)
            const SizedBox(
              height: 320,
              child: Center(child: CircularProgressIndicator()),
            )
          else
            StationMap(
              stations: _stations,
              observations: _observations,
              selectedStationIds: _stationIds.toSet(),
              onStationSelected: (station) =>
                  _updateStationSelection({..._stationIds, station.id}),
            ),
        ],
      ),
    );
  }

  Widget _buildForecastSection(Station station) {
    final forecast = _forecasts[station.id] ?? [];
    final forecastError = _forecastErrors[station.id];
    return ExpansionTile(
      leading: const Icon(Icons.cloud_outlined),
      title: const Text('NWS forecast'),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        if (_loadingForecasts.contains(station.id) && forecast.isEmpty)
          const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (forecastError != null)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(forecastError),
              TextButton.icon(
                onPressed: () => _loadForecast(station),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          )
        else if (forecast.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No daily forecast available.'),
          )
        else
          for (var index = 0; index < forecast.length; index++)
            _buildForecastDay(
              forecast[index],
              isLast: index == forecast.length - 1,
            ),
      ],
    );
  }

  Widget _buildForecastDay(DailyForecast day, {required bool isLast}) {
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
          if (!isLast) const Divider(height: 16),
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

  Widget _buildStationCard(Station station, Observation? observation) {
    final validLocal = observation?.validUtc.toLocal();
    final rows = observation == null
        ? <(String, String)>[]
        : <(String, String)>[
            ('Observation Time', DateFormat.yMd().add_jm().format(validLocal!)),
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        station.name,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      if (observation != null)
                        Text(
                          'Updated ${DateFormat.jm().format(observation.validUtc.toLocal())}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Remove ${station.name}',
                  onPressed: () => _updateStationSelection(
                    _stationIds.where((id) => id != station.id).toSet(),
                  ),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          if (observation == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Text(
                _loadingObservation
                    ? 'Loading station data...'
                    : 'No observation data available.',
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: Wrap(
                spacing: 24,
                runSpacing: 12,
                children: [
                  _buildMetric('Air temp', _fmt(observation.tmpf, '°F')),
                  _buildMetric(
                    'Soil moisture 12 in',
                    _fmt(observation.soil12m, '%'),
                  ),
                  _buildMetric('Today precip', _fmt(observation.pday, 'in')),
                  _buildMetric('Humidity', _fmt(observation.rh, '%')),
                ],
              ),
            ),
            ExpansionTile(
              title: const Text('All observations'),
              children: [
                for (final row in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 5,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [Text(row.$1), Text(row.$2)],
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ],
          _buildForecastSection(station),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return SizedBox(
      width: 132,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value, style: Theme.of(context).textTheme.titleMedium),
        ],
      ),
    );
  }

  String _fmt(double? value, String unit) {
    if (value == null) return 'M';
    return '${value.toStringAsFixed(1)} $unit';
  }
}
