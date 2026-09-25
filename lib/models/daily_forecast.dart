class DailyForecast {
  final String name;
  final int? high;
  final int? low;
  final String temperatureUnit;
  final int? precipitationChance;

  const DailyForecast({
    required this.name,
    required this.high,
    required this.low,
    required this.temperatureUnit,
    required this.precipitationChance,
  });
}
