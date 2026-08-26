// Core logic tests for KrishiBondhu.
import 'package:flutter_test/flutter_test.dart';
import 'package:krishibondhu/state.dart';
import 'package:krishibondhu/data.dart';

void main() {
  test('phone validation accepts common Bangladeshi formats', () {
    expect(AppState.isValidPhone('01712345678'), true);
    expect(AppState.isValidPhone('+8801712345678'), true);
    expect(AppState.isValidPhone('12345'), false);
    expect(AppState.isValidPhone('01234567890'), false); // 012 not a valid operator prefix
  });

  test('email validation works', () {
    expect(AppState.isValidEmail('rosni@ciu.edu.bd'), true);
    expect(AppState.isValidEmail('not-an-email'), false);
  });

  test('demo forecast always has a rain day and a storm day', () {
    final fc = mockForecast(Loc(22.3569, 91.7832, 'Chattogram'));
    expect(fc.length, 5);
    expect(fc.any((d) => d.cond == 'rain'), true);
    expect(fc.any((d) => d.severe), true);
  });

  test('advisory maps heavy rain to a critical warning', () {
    final rainy = WxDay(date: '2026-01-01', dow: 3, cond: 'rain', tempMax: 29, tempMin: 25, rainProb: 85, rainMm: 24, wind: 20, hum: 88, severe: false);
    final adv = advisoryForDay(rainy, 'en', cropId: 'rice');
    expect(adv['level'], 'crit');
    expect(adv['text'].toString().contains('paddy'), true); // crop note appended
  });

  test('advisory gives a calm message on a clear day', () {
    final clear = WxDay(date: '2026-01-02', dow: 4, cond: 'clear', tempMax: 31, tempMin: 24, rainProb: 8, rainMm: 0, wind: 10, hum: 55, severe: false);
    expect(advisoryForDay(clear, 'en')['level'], 'calm');
  });

  test('haversine distance Chattogram -> Reazuddin Bazar is a few km', () {
    final m = seedMarkets.firstWhere((x) => x.id == 'c1');
    final d = haversine(22.3569, 91.7832, m.lat, m.lon);
    expect(d > 2 && d < 12, true);
  });

  test('district lookup resolves major districts', () {
    expect(lookupDistrict('Sylhet town'), isNotNull);
    expect(lookupDistrict('somewhere unknown'), isNull);
  });
}
