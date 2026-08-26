// KrishiBondhu — central app state, persistence, live sync, weather, seeding.
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'data.dart';
import 'strings.dart';
import 'firebase_boot.dart';

class MarketRow {
  final Market market;
  final double dist;
  final PriceEntry? latest;
  final bool fresh;
  final int entryCount;
  MarketRow(this.market, this.dist, this.latest, this.fresh, this.entryCount);
}

class AppState extends ChangeNotifier {
  String lang = 'en';
  String? session;
  bool useFirebase = false;

  List<AppUser> users = [];
  List<Market> markets = List.of(seedMarkets);
  List<PriceEntry> prices = [];

  // settings
  bool weatherAlerts = true;
  bool priceAlerts = true;
  String weatherMode = 'demo'; // 'demo' | 'live'

  // weather cache
  List<WxDay>? _wx;
  int _wxTs = 0;
  String _wxLoc = '';
  String _wxMode = '';
  int wxVersion = 0; // bumped when the forecast should be refetched by the UI

  final Set<String> _alertedSevere = {};
  final Set<String> _alertedPrice = {};

  SharedPreferences? _prefs;
  FirebaseFirestore? _db;

  // ------------------------------------------------------------------ //
  String t(String k) {
    final m = i18n[lang];
    if (m != null && m[k] != null) return m[k].toString();
    return (i18n['en']![k] ?? k).toString();
  }

  List<String> get days => List<String>.from(i18n[lang]!['days'] as List);
  String n(Object v) => bnNum(v, lang);
  String cropName(Crop c) => lang == 'bn' ? c.bn : c.en;
  String marketName(Market m) => lang == 'bn' ? m.bn : m.en;
  AppUser? get currentUser {
    for (final u in users) {
      if (u.id == session) return u;
    }
    return null;
  }

  // ------------------------------------------------------------------ //
  // Boot
  // ------------------------------------------------------------------ //
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    lang = _prefs!.getString('lang') ?? 'en';
    session = _prefs!.getString('session');
    weatherMode = _prefs!.getString('weatherMode') ?? 'demo';
    weatherAlerts = _prefs!.getBool('weatherAlerts') ?? true;
    priceAlerts = _prefs!.getBool('priceAlerts') ?? true;

    final cfg = readWebFirebaseConfig();
    if (cfg != null) {
      try {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: cfg['apiKey']!,
            appId: cfg['appId']!,
            messagingSenderId: cfg['messagingSenderId']!,
            projectId: cfg['projectId']!,
            authDomain: cfg['authDomain'],
            storageBucket: cfg['storageBucket'],
          ),
        );
        _db = FirebaseFirestore.instance;
        useFirebase = true;
      } catch (e) {
        useFirebase = false;
      }
    }

    if (useFirebase) {
      await _bootFirebase();
    } else {
      _bootLocal();
    }
    notifyListeners();
  }

  // ---- Local mode ----
  void _bootLocal() {
    final raw = _prefs!.getString('data');
    if (raw != null) {
      try {
        final m = jsonDecode(raw);
        users = (m['users'] as List).map((u) => AppUser.fromMap(Map.from(u))).toList();
        markets = (m['markets'] as List).map((x) => Market.fromMap(Map<String, dynamic>.from(x))).toList();
        prices = (m['prices'] as List).map((p) => PriceEntry.fromMap(Map.from(p))).toList();
      } catch (_) {}
    }
    if (users.isEmpty) {
      _seedInto(users, prices);
      _persistLocal();
    }
  }

  void _persistLocal() {
    if (useFirebase) return;
    _prefs?.setString('data', jsonEncode({
      'users': users.map((u) => u.toMap()).toList(),
      'markets': markets.map((m) => m.toMap()).toList(),
      'prices': prices.map((p) => p.toMap()).toList(),
    }));
  }

  // ---- Firebase mode ----
  Future<void> _bootFirebase() async {
    // seed once if empty
    final mSnap = await _db!.collection('markets').limit(1).get();
    if (mSnap.docs.isEmpty) {
      final seedUsers = <AppUser>[];
      final seedPrices = <PriceEntry>[];
      _seedInto(seedUsers, seedPrices);
      final batch = _db!.batch();
      for (final m in seedMarkets) {
        batch.set(_db!.collection('markets').doc(m.id), m.toMap());
      }
      for (final u in seedUsers) {
        batch.set(_db!.collection('users').doc(u.id), u.toMap());
      }
      for (final p in seedPrices) {
        batch.set(_db!.collection('prices').doc(p.id), p.toMap());
      }
      await batch.commit();
    }
    // live listeners
    _db!.collection('markets').snapshots().listen((s) {
      markets = s.docs.map((d) => Market.fromMap(Map<String, dynamic>.from(d.data()))).toList();
      if (markets.isEmpty) markets = List.of(seedMarkets);
      notifyListeners();
    });
    _db!.collection('users').snapshots().listen((s) {
      users = s.docs.map((d) => AppUser.fromMap(Map.from(d.data()))).toList();
      notifyListeners();
    });
    _db!.collection('prices').snapshots().listen((s) {
      prices = s.docs.map((d) => PriceEntry.fromMap(Map.from(d.data()))).toList();
      notifyListeners();
    });
    // wait for first users load
    await _db!.collection('users').get().then((s) {
      users = s.docs.map((d) => AppUser.fromMap(Map.from(d.data()))).toList();
    });
    await _db!.collection('prices').get().then((s) {
      prices = s.docs.map((d) => PriceEntry.fromMap(Map.from(d.data()))).toList();
    });
  }

  // ------------------------------------------------------------------ //
  // Persistence helpers (write-through)
  // ------------------------------------------------------------------ //
  Future<void> _saveUser(AppUser u) async {
    if (useFirebase) {
      await _db!.collection('users').doc(u.id).set(u.toMap());
    } else {
      _persistLocal();
      notifyListeners();
    }
  }

  Future<void> _addPrice(PriceEntry p) async {
    if (useFirebase) {
      await _db!.collection('prices').doc(p.id).set(p.toMap());
    } else {
      prices.add(p);
      _persistLocal();
      notifyListeners();
    }
  }

  Future<void> _addMarket(Market m) async {
    markets.add(m);
    if (useFirebase) {
      await _db!.collection('markets').doc(m.id).set(m.toMap());
    } else {
      _persistLocal();
      notifyListeners();
    }
  }

  // ------------------------------------------------------------------ //
  // Seeding (3 demo accounts: Rosni Akter / Mehedi / Nafisa)
  // ------------------------------------------------------------------ //
  void _seedInto(List<AppUser> outUsers, List<PriceEntry> outPrices) {
    final ctg = () => Loc(22.3569, 91.7832, 'Chattogram');
    final now = DateTime.now().millisecondsSinceEpoch;
    const day = 24 * 3600 * 1000;

    outUsers.add(AppUser(
      id: 'u_rosni', name: 'Rosni Akter', cred: 'rosni', pass: '1234', role: 'farmer',
      location: ctg(), crops: ['rice', 'potato', 'tomato', 'onion', 'chili'],
      targets: {'rice': 55, 'chili': 215},
      reminders: [
        Reminder(id: 'r_d1', type: 'irrigation', cropId: 'rice', repeat: 'daily', time: '06:00'),
        Reminder(id: 'r_d2', type: 'spraying', cropId: 'potato', repeat: 'weekly', time: '16:00'),
        Reminder(id: 'r_d3', type: 'harvest', cropId: 'rice', repeat: 'none', time: '07:00'),
      ],
      createdAt: now - 26 * day,
    ));
    outUsers.add(AppUser(
      id: 'u_mehedi', name: 'Mehedi', cred: 'mehedi', pass: '1234', role: 'trader',
      location: ctg(), crops: ['rice', 'onion', 'chili', 'potato'], createdAt: now - 40 * day,
    ));
    outUsers.add(AppUser(
      id: 'u_nafisa', name: 'Nafisa', cred: 'nafisa', pass: '1234', role: 'user',
      location: ctg(), crops: ['tomato', 'onion'], createdAt: now - 15 * day,
    ));

    const h = 3600 * 1000;
    final seeds = <List<Object>>[
      ['rice', 'c2', 58, 'Mehedi', 'trader', 0.5],
      ['rice', 'c1', 54, 'Rosni Akter', 'farmer', 3],
      ['rice', 'c4', 51, 'Nafisa', 'user', 8],
      ['chili', 'c3', 225, 'Mehedi', 'trader', 1],
      ['chili', 'c5', 205, 'Nafisa', 'user', 20],
      ['potato', 'c1', 36, 'Rosni Akter', 'farmer', 2],
      ['potato', 'c2', 33, 'Mehedi', 'trader', 6],
      ['tomato', 'c3', 62, 'Rosni Akter', 'farmer', 5],
      ['tomato', 'c6', 58, 'Nafisa', 'user', 12],
      ['onion', 'c1', 92, 'Rosni Akter', 'farmer', 4],
      ['onion', 'c4', 97, 'Mehedi', 'trader', 9],
      ['wheat', 'c2', 44, 'Nafisa', 'user', 14],
      ['maize', 'c5', 31, 'Mehedi', 'trader', 16],
      ['lentil', 'c3', 118, 'Rosni Akter', 'farmer', 7],
      ['mango', 'c6', 95, 'Nafisa', 'user', 10],
      ['rice', 'd1', 56, 'Mehedi', 'trader', 5],
      ['potato', 'd2', 35, 'Nafisa', 'user', 9],
    ];
    var idc = 1;
    for (final s in seeds) {
      outPrices.add(PriceEntry(
        id: 'pd${idc++}', cropId: s[0] as String, marketId: s[1] as String,
        price: s[2] as int, by: s[3] as String, role: s[4] as String,
        ts: now - ((s[5] as num) * h).round(),
      ));
    }
  }

  // ------------------------------------------------------------------ //
  // Settings & language
  // ------------------------------------------------------------------ //
  void setLang(String l) {
    lang = l;
    _prefs?.setString('lang', l);
    notifyListeners();
  }

  void setWeatherMode(String m) {
    weatherMode = m;
    _wxTs = 0;
    wxVersion++;
    _prefs?.setString('weatherMode', m);
    notifyListeners();
  }

  Future<List<WxDay>> refreshWeather() {
    _wxTs = 0;
    wxVersion++;
    return weather(force: true);
  }

  void setWeatherAlerts(bool v) {
    weatherAlerts = v;
    _prefs?.setBool('weatherAlerts', v);
    notifyListeners();
  }

  void setPriceAlerts(bool v) {
    priceAlerts = v;
    _prefs?.setBool('priceAlerts', v);
    notifyListeners();
  }

  void _setSession(String? id) {
    session = id;
    wxVersion++;
    if (id == null) {
      _prefs?.remove('session');
    } else {
      _prefs?.setString('session', id);
    }
    notifyListeners();
  }

  // ------------------------------------------------------------------ //
  // Auth
  // ------------------------------------------------------------------ //
  static bool isValidPhone(String v) =>
      RegExp(r'^(?:\+?880|0)?1[3-9]\d{8}$').hasMatch(v.replaceAll(RegExp(r'[\s-]'), ''));
  static bool isValidEmail(String v) => RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v.trim());

  String? login(String cred, String pass) {
    if (cred.trim().isEmpty) return t('errCred');
    if (pass.isEmpty) return t('errPass');
    AppUser? u;
    for (final x in users) {
      if (x.cred.toLowerCase() == cred.trim().toLowerCase()) u = x;
    }
    if (u == null) return t('errLogin');
    if (u.pass != pass) return t('errWrongPass');
    _setSession(u.id);
    return null;
  }

  void demoLogin(String cred) {
    for (final u in users) {
      if (u.cred.toLowerCase() == cred) {
        _setSession(u.id);
        return;
      }
    }
  }

  String? register({required String name, required String cred, required String pass, required String role, required Loc location, required List<String> crops}) {
    if (name.trim().isEmpty) return t('errName');
    if (cred.trim().isEmpty) return t('errCred');
    if (!isValidPhone(cred) && !isValidEmail(cred)) return t('errCredFormat');
    if (pass.length < 4) return t('errPass');
    for (final x in users) {
      if (x.cred.toLowerCase() == cred.trim().toLowerCase()) return t('errDup');
    }
    final u = AppUser(
      id: 'u${DateTime.now().millisecondsSinceEpoch}', name: name.trim(), cred: cred.trim(), pass: pass,
      role: role, location: location, crops: crops, createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    users.add(u);
    _saveUser(u);
    _persistLocal();
    _setSession(u.id);
    return null;
  }

  void logout() => _setSession(null);

  // ------------------------------------------------------------------ //
  // Weather
  // ------------------------------------------------------------------ //
  int get weatherTs => _wxTs;

  Future<List<WxDay>> weather({bool force = false}) async {
    final u = currentUser;
    final loc = u?.location ?? Loc(22.3569, 91.7832, 'Chattogram');
    final mode = weatherMode;
    if (!force && _wx != null && DateTime.now().millisecondsSinceEpoch - _wxTs < 3600000 && _wxMode == mode && _wxLoc == loc.label) {
      return _wx!;
    }
    List<WxDay> days;
    if (mode == 'demo') {
      days = mockForecast(loc);
    } else {
      try {
        days = await fetchOpenMeteo(loc);
      } catch (_) {
        days = _wx ?? mockForecast(loc);
      }
    }
    _wx = days;
    _wxTs = DateTime.now().millisecondsSinceEpoch;
    _wxLoc = loc.label;
    _wxMode = mode;
    return days;
  }

  // ------------------------------------------------------------------ //
  // Market queries
  // ------------------------------------------------------------------ //
  bool _isFresh(int ts) => DateTime.now().millisecondsSinceEpoch - ts < 3 * 24 * 3600 * 1000;

  List<MarketRow> marketsWithPrice(String cropId, double radius) {
    final u = currentUser;
    final lat = u?.location.lat ?? 22.3569, lon = u?.location.lon ?? 91.7832;
    final rows = <MarketRow>[];
    for (final m in markets) {
      final dist = haversine(lat, lon, m.lat, m.lon);
      if (dist > radius) continue;
      final entries = prices.where((p) => p.marketId == m.id && p.cropId == cropId).toList()..sort((a, b) => b.ts - a.ts);
      final latest = entries.isNotEmpty ? entries.first : null;
      rows.add(MarketRow(m, dist, latest, latest != null && _isFresh(latest.ts), entries.length));
    }
    return rows;
  }

  List<PriceEntry> marketEntries(String marketId, String cropId) {
    final e = prices.where((p) => p.marketId == marketId && p.cropId == cropId).toList()..sort((a, b) => b.ts - a.ts);
    return e.take(8).toList();
  }

  // ------------------------------------------------------------------ //
  // Price submit / targets
  // ------------------------------------------------------------------ //
  Future<void> submitPrice({required String cropId, required String marketId, required int price, String? newMarketName}) async {
    final u = currentUser!;
    if (marketId == '__new' && newMarketName != null && newMarketName.trim().isNotEmpty) {
      marketId = 'm${DateTime.now().millisecondsSinceEpoch}';
      await _addMarket(Market(marketId, newMarketName.trim(), newMarketName.trim(), u.location.lat, u.location.lon));
    }
    final p = PriceEntry(
      id: 'p${DateTime.now().millisecondsSinceEpoch}', cropId: cropId, marketId: marketId,
      price: price, by: u.name, role: u.role, ts: DateTime.now().millisecondsSinceEpoch,
    );
    _alertedPrice.remove('$cropId:${_todayKey()}');
    await _addPrice(p);
  }

  Future<void> setTarget(String cropId, int value) async {
    final u = currentUser!;
    u.targets[cropId] = value;
    _alertedPrice.remove('$cropId:${_todayKey()}');
    await _saveUser(u);
  }

  Future<void> removeTarget(String cropId) async {
    final u = currentUser!;
    u.targets.remove(cropId);
    await _saveUser(u);
  }

  Future<void> setCrops(List<String> crops) async {
    final u = currentUser!;
    u.crops = crops;
    await _saveUser(u);
  }

  // ------------------------------------------------------------------ //
  // Reminders
  // ------------------------------------------------------------------ //
  Future<void> saveReminder({String? id, required String type, required String cropId, required String repeat, required String time}) async {
    final u = currentUser!;
    if (id != null) {
      final r = u.reminders.firstWhere((x) => x.id == id, orElse: () => Reminder(id: '', type: type, cropId: cropId, repeat: repeat, time: time));
      if (r.id.isNotEmpty) {
        r.type = type;
        r.cropId = cropId;
        r.repeat = repeat;
        r.time = time;
      }
    } else {
      u.reminders.add(Reminder(id: 'r${DateTime.now().millisecondsSinceEpoch}', type: type, cropId: cropId, repeat: repeat, time: time));
    }
    if (_wx != null) applyWeatherReschedule(_wx!, save: false);
    await _saveUser(u);
  }

  Future<void> toggleReminder(String id) async {
    final u = currentUser!;
    for (final r in u.reminders) {
      if (r.id == id) r.enabled = !r.enabled;
    }
    await _saveUser(u);
  }

  Future<void> deleteReminder(String id) async {
    final u = currentUser!;
    u.reminders.removeWhere((r) => r.id == id);
    await _saveUser(u);
  }

  void applyWeatherReschedule(List<WxDay> fc, {bool save = true}) {
    final u = currentUser;
    if (u == null || fc.isEmpty) return;
    var changed = false;
    for (final rem in u.reminders) {
      final tt = taskTypeById(rem.type);
      if (tt == null || !tt.weatherSensitive || !rem.enabled) continue;
      if (badWeatherDay(fc[0])) {
        final nextIdx = fc.indexWhere((d) => !badWeatherDay(d), 1);
        if (nextIdx > 0 && rem.movedToDate != fc[nextIdx].date) {
          rem.movedFromDate = fc[0].date;
          rem.movedToDate = fc[nextIdx].date;
          rem.movedReason = fc[0].severe ? 'storm' : 'rain';
          changed = true;
        }
      } else if (rem.movedToDate != null) {
        rem.movedFromDate = null;
        rem.movedToDate = null;
        rem.movedReason = null;
        changed = true;
      }
    }
    if (changed && save) _saveUser(u);
    if (changed && !save) {} // caller persists
  }

  // ------------------------------------------------------------------ //
  // Alerts (return message or null; caller shows a banner)
  // ------------------------------------------------------------------ //
  @visibleForTesting
  void resetAlerts() {
    _alertedSevere.clear();
    _alertedPrice.clear();
  }

  String _todayKey([int offset = 0]) {
    final d = DateTime.now().add(Duration(days: offset));
    return d.toIso8601String().substring(0, 10);
  }

  String? checkSevere(List<WxDay> fc) {
    if (!weatherAlerts) return null;
    WxDay? sev;
    for (final d in fc) {
      if (d.severe) {
        sev = d;
        break;
      }
    }
    if (sev == null) return null;
    if (_alertedSevere.contains(sev.date)) return null;
    _alertedSevere.add(sev.date);
    final dayName = days[sev.dow];
    return lang == 'bn'
        ? '$dayNameবার ঝড়/ভারী বৃষ্টির সতর্কতা। ফসল রক্ষা করুন।'
        : 'Storm/heavy rain warning for $dayName. Protect your crops.';
  }

  String? checkPriceAlerts() {
    if (!priceAlerts) return null;
    final u = currentUser;
    if (u == null) return null;
    for (final entry in u.targets.entries) {
      final matches = marketsWithPrice(entry.key, 100).where((m) => m.latest != null && m.fresh && m.latest!.price >= entry.value).toList();
      if (matches.isEmpty) continue;
      final key = '${entry.key}:${_todayKey()}';
      if (_alertedPrice.contains(key)) continue;
      _alertedPrice.add(key);
      matches.sort((a, b) => b.latest!.price - a.latest!.price);
      final best = matches.first;
      final crop = cropById(entry.key)!;
      return '${cropName(crop)} ৳${n(best.latest!.price)} ${t('priceAlertBody')} ৳${n(entry.value)} · ${marketName(best.market)}';
    }
    return null;
  }
}

// ---- small format helpers (used by UI) ----
final _honorific = RegExp(r'^(mr|mrs|ms|md|dr|mst)\.?$', caseSensitive: false);
List<String> nameParts(String s) => s.trim().split(RegExp(r'\s+')).where((x) => x.isNotEmpty && !_honorific.hasMatch(x)).toList();
String firstName(String s) {
  final p = nameParts(s);
  return p.isNotEmpty ? p.first : 'Farmer';
}

String initials(String s) {
  final p = nameParts(s);
  final a = p.isNotEmpty ? p[0][0] : '';
  final b = p.length > 1 ? p[1][0] : '';
  final r = (a + b).toUpperCase();
  return r.isEmpty ? '🌾' : r;
}

String timeAgo(int ts, AppState s) {
  final mins = ((DateTime.now().millisecondsSinceEpoch - ts) / 60000).round();
  if (mins < 2) return s.t('justNow');
  if (mins < 60) return '${s.n(mins)} min ${s.t('reportedAgo')}';
  final hrs = (mins / 60).round();
  if (hrs < 24) return '${s.n(hrs)} h ${s.t('reportedAgo')}';
  final d = (hrs / 24).round();
  return '${s.n(d)} d ${s.t('reportedAgo')}';
}
