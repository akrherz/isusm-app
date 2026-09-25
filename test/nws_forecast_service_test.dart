import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:isusm_app/models/station.dart';
import 'package:isusm_app/services/nws_forecast_service.dart';

void main() {
  test(
    'looks up station coordinates and pairs daytime and nighttime data',
    () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/points/42.0,-93.0') {
          return http.Response(
            jsonEncode({
              'properties': {
                'forecast':
                    'https://api.weather.gov/gridpoints/DMX/1,2/forecast',
              },
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'properties': {
              'periods': [
                {
                  'name': 'Monday',
                  'isDaytime': true,
                  'temperature': 81,
                  'temperatureUnit': 'F',
                  'probabilityOfPrecipitation': {'value': 30},
                },
                {
                  'name': 'Monday Night',
                  'isDaytime': false,
                  'temperature': 59,
                  'temperatureUnit': 'F',
                  'probabilityOfPrecipitation': {'value': 60},
                },
                {
                  'name': 'Tuesday',
                  'isDaytime': true,
                  'temperature': 78,
                  'temperatureUnit': 'F',
                  'probabilityOfPrecipitation': {'value': null},
                },
              ],
            },
          }),
          200,
        );
      });
      final service = NwsForecastService(client: client);

      final forecast = await service.fetchDailyForecast(
        const Station(
          id: 'TEST',
          name: 'Test Station',
          latitude: 42,
          longitude: -93,
        ),
      );

      expect(requests, hasLength(2));
      expect(requests.first.url.host, 'api.weather.gov');
      expect(requests.first.url.path, '/points/42.0,-93.0');
      expect(forecast, hasLength(2));
      expect(forecast.first.name, 'Monday');
      expect(forecast.first.high, 81);
      expect(forecast.first.low, 59);
      expect(forecast.first.precipitationChance, 60);
      expect(forecast.last.high, 78);
      expect(forecast.last.low, isNull);
      expect(forecast.last.precipitationChance, isNull);

      service.dispose();
    },
  );
}
