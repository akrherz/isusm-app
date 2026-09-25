import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/daily_forecast.dart';
import '../models/station.dart';

/// Fetches daily forecasts from the National Weather Service API.
class NwsForecastService {
  final http.Client _client;

  NwsForecastService({http.Client? client}) : _client = client ?? http.Client();

  Future<List<DailyForecast>> fetchDailyForecast(Station station) async {
    final pointUri = Uri.https(
      'api.weather.gov',
      '/points/${station.latitude},${station.longitude}',
    );
    final pointResponse = await _client.get(pointUri, headers: _headers);
    if (pointResponse.statusCode != 200) {
      throw Exception(
        'Failed to locate NWS forecast (HTTP ${pointResponse.statusCode})',
      );
    }

    final pointData = jsonDecode(pointResponse.body) as Map<String, dynamic>;
    final pointProperties = pointData['properties'] as Map<String, dynamic>;
    final forecastUrl = pointProperties['forecast'];
    if (forecastUrl is! String) {
      throw const FormatException('NWS point response has no forecast URL');
    }

    final forecastResponse = await _client.get(
      Uri.parse(forecastUrl),
      headers: _headers,
    );
    if (forecastResponse.statusCode != 200) {
      throw Exception(
        'Failed to load NWS forecast (HTTP ${forecastResponse.statusCode})',
      );
    }

    final forecastData =
        jsonDecode(forecastResponse.body) as Map<String, dynamic>;
    final forecastProperties =
        forecastData['properties'] as Map<String, dynamic>;
    final periods = forecastProperties['periods'];
    if (periods is! List) {
      throw const FormatException('NWS forecast response has no periods');
    }

    return _pairDailyPeriods(periods);
  }

  Map<String, String> get _headers => {
    'Accept': 'application/geo+json',
    if (!kIsWeb)
      'User-Agent': 'ISUSM App/1.0 (https://mesonet.agron.iastate.edu/)',
  };

  List<DailyForecast> _pairDailyPeriods(List<dynamic> periods) {
    final days = <DailyForecast>[];
    for (var index = 0; index < periods.length; index++) {
      final period = periods[index];
      if (period is! Map<String, dynamic> || period['isDaytime'] != true) {
        continue;
      }

      final next = index + 1 < periods.length ? periods[index + 1] : null;
      final night = next is Map<String, dynamic> && next['isDaytime'] == false
          ? next
          : null;
      final dayChance = _precipitationChance(period);
      final nightChance = night == null ? null : _precipitationChance(night);

      days.add(
        DailyForecast(
          name: period['name'] is String
              ? period['name'] as String
              : 'Day ${days.length + 1}',
          high: _temperature(period),
          low: night == null ? null : _temperature(night),
          temperatureUnit: period['temperatureUnit'] is String
              ? period['temperatureUnit'] as String
              : 'F',
          precipitationChance: _maxNullable(dayChance, nightChance),
        ),
      );
    }
    return days;
  }

  int? _temperature(Map<String, dynamic> period) {
    final value = period['temperature'];
    return value is num ? value.round() : null;
  }

  int? _precipitationChance(Map<String, dynamic> period) {
    final probability = period['probabilityOfPrecipitation'];
    if (probability is! Map<String, dynamic>) return null;
    final value = probability['value'];
    return value is num ? value.round() : null;
  }

  int? _maxNullable(int? first, int? second) {
    if (first == null) return second;
    if (second == null) return first;
    return first > second ? first : second;
  }

  void dispose() => _client.close();
}
