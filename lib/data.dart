// KrishiBondhu — static data, models, i18n, weather engine.
import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

// ------------------------------------------------------------------ //
// Models
// ------------------------------------------------------------------ //
class Crop {
  final String id, en, bn, em, unit;
  final int base;
  const Crop(this.id, this.en, this.bn, this.em, this.base, {this.unit = 'kg'});
}

class Market {
  final String id, en, bn;
  final double lat, lon;
  const Market(this.id, this.en, this.bn, this.lat, this.lon);
  factory Market.fromMap(Map<String, dynamic> m) =>
      Market(m['id'], m['en'], m['bn'], (m['lat'] as num).toDouble(), (m['lon'] as num).toDouble());
  Map<String, dynamic> toMap() => {'id': id, 'en': en, 'bn': bn, 'lat': lat, 'lon': lon};
}

class Loc {
  double lat, lon;
  String label;
  Loc(this.lat, this.lon, this.label);
  factory Loc.fromMap(Map m) => Loc((m['lat'] as num).toDouble(), (m['lon'] as num).toDouble(), m['label'] ?? '');
  Map<String, dynamic> toMap() => {'lat': lat, 'lon': lon, 'label': label};
}

class PriceEntry {
  String id, cropId, marketId, by, role;
  int price;
  int ts; // epoch ms
  PriceEntry({required this.id, required this.cropId, required this.marketId, required this.price, required this.by, required this.role, required this.ts});
  factory PriceEntry.fromMap(Map m) => PriceEntry(
        id: m['id'], cropId: m['cropId'], marketId: m['marketId'],
        price: (m['price'] as num).toInt(), by: m['by'] ?? '', role: m['role'] ?? 'user',
        ts: (m['ts'] as num).toInt());
  Map<String, dynamic> toMap() => {'id': id, 'cropId': cropId, 'marketId': marketId, 'price': price, 'by': by, 'role': role, 'ts': ts};
}

class Reminder {
  String id, type, cropId, repeat, time;
  bool enabled;
  String? movedFromDate, movedToDate, movedReason;
  Reminder({required this.id, required this.type, required this.cropId, required this.repeat, required this.time, this.enabled = true, this.movedFromDate, this.movedToDate, this.movedReason});
  factory Reminder.fromMap(Map m) => Reminder(
        id: m['id'], type: m['type'], cropId: m['cropId'], repeat: m['repeat'], time: m['time'] ?? '06:00',
        enabled: m['enabled'] ?? true, movedFromDate: m['movedFromDate'], movedToDate: m['movedToDate'], movedReason: m['movedReason']);
  Map<String, dynamic> toMap() => {'id': id, 'type': type, 'cropId': cropId, 'repeat': repeat, 'time': time, 'enabled': enabled, 'movedFromDate': movedFromDate, 'movedToDate': movedToDate, 'movedReason': movedReason};
}

class AppUser {
  String id, name, cred, pass, role;
  Loc location;
  List<String> crops;
  Map<String, int> targets;
  List<Reminder> reminders;
  int createdAt;
  AppUser({required this.id, required this.name, required this.cred, required this.pass, required this.role, required this.location, required this.crops, Map<String, int>? targets, List<Reminder>? reminders, required this.createdAt})
      : targets = targets ?? {},
        reminders = reminders ?? [];
  factory AppUser.fromMap(Map m) => AppUser(
        id: m['id'], name: m['name'], cred: m['cred'], pass: m['pass'], role: m['role'] ?? 'farmer',
        location: Loc.fromMap(Map<String, dynamic>.from(m['location'] ?? {'lat': 22.3569, 'lon': 91.7832, 'label': 'Chattogram'})),
        crops: List<String>.from(m['crops'] ?? []),
        targets: Map<String, int>.from((m['targets'] ?? {}).map((k, v) => MapEntry(k, (v as num).toInt()))),
        reminders: List<Reminder>.from((m['reminders'] ?? []).map((r) => Reminder.fromMap(Map.from(r)))),
        createdAt: (m['createdAt'] as num?)?.toInt() ?? DateTime.now().millisecondsSinceEpoch);
  Map<String, dynamic> toMap() => {
        'id': id, 'name': name, 'cred': cred, 'pass': pass, 'role': role,
        'location': location.toMap(), 'crops': crops, 'targets': targets,
        'reminders': reminders.map((r) => r.toMap()).toList(), 'createdAt': createdAt,
      };
}

class WxDay {
  final String date;
  final int dow;
  final String cond;
  final int tempMax, tempMin, rainProb, rainMm, wind, hum;
  final bool severe;
  WxDay({required this.date, required this.dow, required this.cond, required this.tempMax, required this.tempMin, required this.rainProb, required this.rainMm, required this.wind, required this.hum, required this.severe});
  Map<String, dynamic> toMap() => {'date': date, 'dow': dow, 'cond': cond, 'tempMax': tempMax, 'tempMin': tempMin, 'rainProb': rainProb, 'rainMm': rainMm, 'wind': wind, 'hum': hum, 'severe': severe};
  factory WxDay.fromMap(Map m) => WxDay(date: m['date'], dow: m['dow'], cond: m['cond'], tempMax: m['tempMax'], tempMin: m['tempMin'], rainProb: m['rainProb'], rainMm: m['rainMm'], wind: m['wind'], hum: m['hum'], severe: m['severe']);
}

class TaskType {
  final String id, en, bn, em;
  final bool weatherSensitive;
  const TaskType(this.id, this.en, this.bn, this.em, this.weatherSensitive);
}

class AdvisoryRule {
  final String id, level;
  final bool Function(WxDay) when;
  final Map<String, String> title, text;
  const AdvisoryRule(this.id, this.level, this.when, this.title, this.text);
}

// ------------------------------------------------------------------ //
// Static data
// ------------------------------------------------------------------ //
const crops = <Crop>[
  Crop('rice', 'Rice', 'ধান', '🌾', 58),
  Crop('wheat', 'Wheat', 'গম', '🌿', 42),
  Crop('potato', 'Potato', 'আলু', '🥔', 34),
  Crop('tomato', 'Tomato', 'টমেটো', '🍅', 60),
  Crop('onion', 'Onion', 'পেঁয়াজ', '🧅', 95),
  Crop('jute', 'Jute', 'পাট', '🪢', 78),
  Crop('maize', 'Maize', 'ভুট্টা', '🌽', 30),
  Crop('chili', 'Chili', 'মরিচ', '🌶️', 210),
  Crop('lentil', 'Lentil', 'ডাল', '🫘', 120),
  Crop('mango', 'Mango', 'আম', '🥭', 90),
  Crop('eggplant', 'Eggplant', 'বেগুন', '🍆', 55),
  Crop('sugarcane', 'Sugarcane', 'আখ', '🎋', 25),
];
Crop? cropById(String? id) {
  for (final c in crops) {
    if (c.id == id) return c;
  }
  return null;
}

const seedMarkets = <Market>[
  Market('c1', 'Reazuddin Bazar', 'রেয়াজউদ্দিন বাজার', 22.3350, 91.8322),
  Market('c2', 'Chawkbazar', 'চকবাজার', 22.3607, 91.8290),
  Market('c3', 'Kazir Dewri Bazar', 'কাজীর দেউড়ি বাজার', 22.3585, 91.8210),
  Market('c4', 'Bahaddarhat Bazar', 'বহদ্দারহাট বাজার', 22.3700, 91.8470),
  Market('c5', 'Pahartali Bazar', 'পাহাড়তলী বাজার', 22.3760, 91.7870),
  Market('c6', 'Oxygen More Bazar', 'অক্সিজেন মোড় বাজার', 22.3900, 91.8180),
  Market('c7', 'Firingi Bazar', 'ফিরিঙ্গি বাজার', 22.3300, 91.8380),
  Market('c8', 'Steel Mill Bazar', 'স্টিল মিল বাজার', 22.2790, 91.7600),
  Market('d1', 'Karwan Bazar', 'কারওয়ান বাজার', 23.7509, 90.3934),
  Market('d2', 'Shyambazar', 'শ্যামবাজার', 23.7104, 90.4074),
  Market('d3', 'Mohakhali Kacha Bazar', 'মহাখালী কাঁচাবাজার', 23.7783, 90.4053),
  Market('d4', 'Mirpur-1 Bazar', 'মিরপুর-১ বাজার', 23.7957, 90.3537),
];

const districts = <String, List<double>>{
  'chattogram': [22.3569, 91.7832], 'chittagong': [22.3569, 91.7832],
  'dhaka': [23.8103, 90.4125], 'gazipur': [23.9999, 90.4203],
  'narayanganj': [23.6238, 90.4990], 'sylhet': [24.8949, 91.8687],
  'rajshahi': [24.3745, 88.6042], 'khulna': [22.8456, 89.5403],
  'barishal': [22.7010, 90.3535], 'rangpur': [25.7439, 89.2752],
  'mymensingh': [24.7471, 90.4203], 'cumilla': [23.4607, 91.1809],
  'comilla': [23.4607, 91.1809], 'cox': [21.4272, 92.0058],
  'jashore': [23.1664, 89.2081], 'bogura': [24.8465, 89.3773],
  'dinajpur': [25.6217, 88.6354], 'feni': [23.0159, 91.3976],
  'noakhali': [22.8696, 91.0995], 'tangail': [24.2513, 89.9167],
};
List<double>? lookupDistrict(String text) {
  final s = text.toLowerCase();
  for (final e in districts.entries) {
    if (s.contains(e.key)) return e.value;
  }
  return null;
}

const taskTypes = <TaskType>[
  TaskType('irrigation', 'Irrigation', 'সেচ', '💧', true),
  TaskType('spraying', 'Pesticide spraying', 'কীটনাশক স্প্রে', '🧴', true),
  TaskType('fertilizer', 'Fertilizing', 'সার প্রয়োগ', '🌱', true),
  TaskType('weeding', 'Weeding', 'আগাছা পরিষ্কার', '🌿', false),
  TaskType('harvest', 'Harvesting', 'ফসল কাটা', '🧺', false),
  TaskType('sowing', 'Sowing / planting', 'বীজ বপন', '🌰', true),
];
TaskType? taskTypeById(String? id) {
  for (final t in taskTypes) {
    if (t.id == id) return t;
  }
  return null;
}

final advisoryRules = <AdvisoryRule>[
  AdvisoryRule('heavy_rain', 'crit', (d) => d.rainProb >= 70 || d.rainMm >= 20,
      {'en': 'Heavy rain expected', 'bn': 'ভারী বৃষ্টির সম্ভাবনা'},
      {'en': 'Postpone spraying and irrigation. Cover harvested crops and clear drainage channels.', 'bn': 'কীটনাশক স্প্রে ও সেচ পিছিয়ে দিন। কাটা ফসল ঢেকে রাখুন এবং পানি নিষ্কাশনের নালা পরিষ্কার করুন।'}),
  AdvisoryRule('storm', 'crit', (d) => d.wind >= 45 || d.severe,
      {'en': 'Storm / high wind warning', 'bn': 'ঝড় / প্রবল বাতাসের সতর্কতা'},
      {'en': 'Secure young plants and equipment. Avoid field work and harvest ripe crops early if possible.', 'bn': 'কচি গাছ ও যন্ত্রপাতি নিরাপদে রাখুন। মাঠের কাজ এড়িয়ে চলুন এবং সম্ভব হলে পাকা ফসল আগেই কেটে নিন।'}),
  AdvisoryRule('light_rain', 'warn', (d) => d.rainProb >= 40 && d.rainProb < 70,
      {'en': 'Light rain likely', 'bn': 'হালকা বৃষ্টির সম্ভাবনা'},
      {'en': 'Skip irrigation today — rain will water your field. Delay pesticide application.', 'bn': 'আজ সেচ দেওয়ার দরকার নেই — বৃষ্টি মাঠে পানি দেবে। কীটনাশক প্রয়োগ পিছিয়ে দিন।'}),
  AdvisoryRule('heat', 'warn', (d) => d.tempMax >= 36,
      {'en': 'High temperature', 'bn': 'উচ্চ তাপমাত্রা'},
      {'en': 'Irrigate early morning or evening to reduce water loss. Provide shade for seedlings.', 'bn': 'পানির অপচয় কমাতে ভোরে বা সন্ধ্যায় সেচ দিন। চারা গাছের জন্য ছায়ার ব্যবস্থা করুন।'}),
  AdvisoryRule('dry_good', 'calm', (d) => d.rainProb < 25 && d.tempMax < 36 && d.wind < 35,
      {'en': 'Good day for field work', 'bn': 'মাঠের কাজের জন্য ভালো দিন'},
      {'en': 'Clear and dry — ideal for spraying, weeding and harvesting. A good day to work your land.', 'bn': 'পরিষ্কার ও শুকনো — স্প্রে, আগাছা পরিষ্কার ও ফসল কাটার জন্য উপযুক্ত। জমিতে কাজ করার ভালো দিন।'}),
];

const cropNotes = <String, Map<String, String>>{
  'rice': {'en': 'Maintain 2–3 cm standing water in paddy after rain.', 'bn': 'বৃষ্টির পর ধান ক্ষেতে ২–৩ সেমি পানি ধরে রাখুন।'},
  'potato': {'en': 'Watch for late blight in wet, cool weather.', 'bn': 'ভেজা ও ঠান্ডা আবহাওয়ায় আলুর নাবিধসা রোগে সতর্ক থাকুন।'},
  'tomato': {'en': 'Stake plants before storms to prevent breakage.', 'bn': 'ঝড়ের আগে টমেটো গাছে খুঁটি দিন যাতে ভেঙে না যায়।'},
  'onion': {'en': 'Avoid waterlogging — onions rot in standing water.', 'bn': 'জলাবদ্ধতা এড়ান — জমে থাকা পানিতে পেঁয়াজ পচে যায়।'},
  'chili': {'en': 'Rain raises fungal risk — check leaves after showers.', 'bn': 'বৃষ্টিতে ছত্রাকের ঝুঁকি বাড়ে — বৃষ্টির পর পাতা পরীক্ষা করুন।'},
};

// ------------------------------------------------------------------ //
// Weather condition metadata
// ------------------------------------------------------------------ //
const wxEmoji = <String, String>{'clear': '☀️', 'sunny': '🌤️', 'cloud': '☁️', 'rain': '🌧️', 'storm': '⛈️'};
const wxKey = <String, String>{'clear': 'condClear', 'sunny': 'condSunny', 'cloud': 'condCloud', 'rain': 'condRain', 'storm': 'condStorm'};

String _omCond(int code, int wind) {
  if ([95, 96, 99].contains(code)) return 'storm';
  if ([51, 53, 55, 56, 57, 61, 63, 65, 66, 67, 71, 73, 75, 77, 80, 81, 82, 85, 86].contains(code)) return 'rain';
  if ([3, 45, 48].contains(code)) return 'cloud';
  if ([1, 2].contains(code)) return 'sunny';
  if (code == 0) return 'clear';
  return wind >= 45 ? 'storm' : 'sunny';
}

/// Crafted 5-day demo forecast — always has a rain day and a storm day so
/// weather-driven features (alerts, auto-reschedule) are demonstrable.
List<WxDay> mockForecast(Loc loc) {
  final jig = ((loc.lat * 10) % 3).round();
  final base = [
    {'cond': 'rain', 'tMax': 29, 'tMin': 25, 'rp': 85, 'rm': 24, 'w': 28, 'h': 88, 's': false},
    {'cond': 'storm', 'tMax': 28, 'tMin': 24, 'rp': 92, 'rm': 42, 'w': 56, 'h': 91, 's': true},
    {'cond': 'cloud', 'tMax': 31, 'tMin': 25, 'rp': 30, 'rm': 2, 'w': 18, 'h': 72, 's': false},
    {'cond': 'clear', 'tMax': 33, 'tMin': 26, 'rp': 12, 'rm': 0, 'w': 13, 'h': 60, 's': false},
    {'cond': 'sunny', 'tMax': 34, 'tMin': 26, 'rp': 8, 'rm': 0, 'w': 11, 'h': 56, 's': false},
  ];
  final start = DateTime.now();
  return List.generate(base.length, (i) {
    final b = base[i];
    final date = start.add(Duration(days: i));
    return WxDay(
      date: date.toIso8601String().substring(0, 10),
      dow: date.weekday % 7,
      cond: b['cond'] as String,
      tempMax: (b['tMax'] as int) + jig, tempMin: (b['tMin'] as int) + jig,
      rainProb: b['rp'] as int, rainMm: b['rm'] as int, wind: b['w'] as int, hum: b['h'] as int,
      severe: b['s'] as bool,
    );
  });
}

/// Live forecast from Open-Meteo (free, no API key).
Future<List<WxDay>> fetchOpenMeteo(Loc loc) async {
  final url = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=${loc.lat}&longitude=${loc.lon}'
      '&timezone=auto&forecast_days=5'
      '&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m'
      '&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_sum,precipitation_probability_max,wind_speed_10m_max');
  final res = await http.get(url).timeout(const Duration(seconds: 12));
  if (res.statusCode != 200) throw Exception('weather api');
  final data = jsonDecode(res.body);
  final d = data['daily'], cur = data['current'] ?? {};
  final n = (d['time'] as List).length.clamp(0, 5);
  final out = <WxDay>[];
  for (var i = 0; i < n; i++) {
    final wind = (d['wind_speed_10m_max'][i] as num).round();
    final rainMm = ((d['precipitation_sum']?[i] ?? 0) as num).round();
    final rainProb = ((d['precipitation_probability_max']?[i] ?? 0) as num).round();
    final cond = _omCond((d['weather_code'][i] as num).toInt(), wind);
    final date = DateTime.parse(d['time'][i]);
    out.add(WxDay(
      date: d['time'][i], dow: date.weekday % 7, cond: cond,
      tempMax: (d['temperature_2m_max'][i] as num).round(), tempMin: (d['temperature_2m_min'][i] as num).round(),
      rainProb: rainProb, rainMm: rainMm, wind: wind,
      hum: i == 0 ? ((cur['relative_humidity_2m'] ?? 70) as num).round() : 70,
      severe: cond == 'storm' || wind >= 45 || rainMm >= 30,
    ));
  }
  return out.isEmpty ? mockForecast(loc) : out;
}

Map<String, dynamic> advisoryForDay(WxDay day, String lang, {String? cropId}) {
  final rule = advisoryRules.firstWhere((r) => r.when(day), orElse: () => advisoryRules.last);
  var text = rule.text[lang] ?? rule.text['en']!;
  if (cropId != null && cropNotes[cropId] != null && rule.level != 'calm') {
    text += ' ${cropNotes[cropId]![lang] ?? cropNotes[cropId]!['en']}';
  }
  return {'level': rule.level, 'title': rule.title[lang] ?? rule.title['en'], 'text': text, 'id': rule.id};
}

bool badWeatherDay(WxDay d) => d.severe || d.rainProb >= 60;

// ------------------------------------------------------------------ //
// Geo helper
// ------------------------------------------------------------------ //
double haversine(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  double toRad(double x) => x * math.pi / 180;
  final dLat = toRad(lat2 - lat1), dLon = toRad(lon2 - lon1);
  final a = math.pow(math.sin(dLat / 2), 2) +
      math.cos(toRad(lat1)) * math.cos(toRad(lat2)) * math.pow(math.sin(dLon / 2), 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}
