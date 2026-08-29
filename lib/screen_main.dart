// KrishiBondhu — main app shell and feature screens.
import 'package:flutter/material.dart';

import 'main.dart';
import 'state.dart';
import 'theme.dart';
import 'data.dart';
import 'ui.dart';

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int tab = 0;

  final tabs = const [
    ['🏠', 'tabHome'],
    ['⛅', 'tabWeather'],
    ['🛒', 'tabMarket'],
    ['⏰', 'tabTasks'],
    ['👤', 'tabProfile'],
  ];

  void go(int i) => setState(() => tab = i);

  @override
  Widget build(BuildContext context) {
    // None of these may be const: a const widget is the same instance every
    // rebuild, so Flutter skips its subtree entirely and the screen stops
    // reflecting `app` state (language, live prices, reminder toggles).
    final screens = [
      HomeScreen(onTab: go),
      WeatherScreen(),
      MarketScreen(),
      TasksScreen(),
      ProfileScreen(onTab: go),
    ];
    // In a standalone PWA there is no browser back bar, and tab switching is
    // internal state rather than Navigator routes — so without this, the system
    // back gesture exits the app from any tab instead of returning to Home.
    return PopScope(
      canPop: tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && tab != 0) go(0);
      },
      child: Scaffold(
      body: SafeArea(bottom: false, child: screens[tab]),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: C.card,
          boxShadow: [
            BoxShadow(
              color: Color(0x0F000000),
              blurRadius: 16,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (var i = 0; i < tabs.length; i++)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => go(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            tabs[i][0],
                            style: TextStyle(
                              fontSize: 22,
                              color: tab == i ? null : null,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            app.t(tabs[i][1]),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: tab == i ? C.green700 : C.ink300,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

// ------------------------------------------------------------------ //
// Weather loading mixin (memoized future keyed on mode + location + version)
// ------------------------------------------------------------------ //
mixin WeatherLoad<T extends StatefulWidget> on State<T> {
  Future<List<WxDay>>? _wxFuture;
  int _wxVer = -1;

  Future<List<WxDay>> wxFuture() {
    if (_wxFuture == null || _wxVer != app.wxVersion) {
      _wxVer = app.wxVersion;
      _wxFuture = app.weather();
    }
    return _wxFuture!;
  }

  void reloadWeather() {
    setState(() {
      _wxFuture = app.refreshWeather();
      _wxVer = app.wxVersion;
    });
  }
}

// ------------------------------------------------------------------ //
// HOME
// ------------------------------------------------------------------ //
class HomeScreen extends StatefulWidget {
  final void Function(int) onTab;
  const HomeScreen({super.key, required this.onTab});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WeatherLoad {
  @override
  Widget build(BuildContext context) {
    final u = app.currentUser!;
    return FutureBuilder<List<WxDay>>(
      future: wxFuture(),
      builder: (context, snap) {
        final fc = snap.data;
        if (fc != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            app.applyWeatherReschedule(fc);
            _fireAlerts(fc);
          });
        }
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            _header(u, fc),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (fc != null && fc.any((d) => d.severe)) ...[
                    const SizedBox(height: 14),
                    _severeBanner(fc.firstWhere((d) => d.severe)),
                  ],
                  sectionHeader(
                    app.t('todayAdvisory'),
                    action: linkText(app.t('viewAll'), () => widget.onTab(1)),
                  ),
                  if (fc != null)
                    advisoryCard(
                      advisoryForDay(
                        fc[0],
                        app.lang,
                        cropId: u.crops.isNotEmpty ? u.crops[0] : null,
                      ),
                      cropId: u.crops.isNotEmpty ? u.crops[0] : null,
                    )
                  else
                    _skel(90),
                  sectionHeader(app.t('quickActions')),
                  _quickActions(),
                  sectionHeader(
                    app.t('nearbyMarkets'),
                    action: linkText(app.t('viewAll'), () => widget.onTab(2)),
                  ),
                  _nearby(u),
                  sectionHeader(
                    app.t('upcomingTasks'),
                    action: linkText(app.t('viewAll'), () => widget.onTab(3)),
                  ),
                  _upcoming(u),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  void _fireAlerts(List<WxDay> fc) {
    final s = app.checkSevere(fc);
    if (s != null && mounted) {
      snack(context, '⚠️ ${app.t('severeTag')}: $s', type: 'warn');
    }
    final p = app.checkPriceAlerts();
    if (p != null && mounted) {
      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) snack(context, '🎯 $p', type: 'ok');
      });
    }
  }

  Widget _header(AppUser u, List<WxDay>? fc) {
    final today = fc != null ? fc[0] : null;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [C.green800, C.green600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${app.t('hello')},',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .85),
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      '${firstName(u.name)} 👋',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '📍 ${u.location.label}',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .9),
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () => widget.onTab(4),
                child: CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.white.withValues(alpha: .2),
                  child: Text(
                    initials(u.name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      today != null ? '${app.n(today.tempMax)}°' : '—',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      today != null ? app.t(wxKey[today.cond]!) : '',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: .9),
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (today != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        '💧 ${app.n(today.hum)}%    🌬️ ${app.n(today.wind)} km/h    🌧️ ${app.n(today.rainProb)}%',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .9),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Text(
                today != null ? wxEmoji[today.cond]! : '⛅',
                style: const TextStyle(fontSize: 60),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _severeBanner(WxDay d) {
    final msg = app.lang == 'bn'
        ? '${app.days[d.dow]}বার ঝড় ও ভারী বৃষ্টির প্রবল সম্ভাবনা। ফসল, গবাদি পশু ও যন্ত্রপাতি নিরাপদে রাখুন।'
        : 'Storm and heavy rain highly likely on ${app.days[d.dow]}. Protect crops, livestock and equipment in advance.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .2),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '● ${app.t('severeTag')}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '⚠️ ${app.lang == 'bn' ? 'দুর্যোগ সতর্কতা' : 'Severe weather warning'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            msg,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .95),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickActions() {
    final items = [
      ['⛅', app.t('qWeather'), () => widget.onTab(1)],
      ['🛒', app.t('qMarkets'), () => widget.onTab(2)],
      ['🏷️', app.t('qReport'), () => submitPriceSheet(context)],
      ['⏰', app.t('qReminder'), () => reminderSheet(context)],
    ];
    return Row(
      children: [
        for (final it in items)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: it[2] as VoidCallback,
                child: kCard(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Column(
                    children: [
                      Text(
                        it[0] as String,
                        style: const TextStyle(fontSize: 24),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        it[1] as String,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: C.ink700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _nearby(AppUser u) {
    final crop = u.crops.isNotEmpty ? u.crops[0] : crops[0].id;
    final list = app.marketsWithPrice(crop, 50)
      ..sort((a, b) => a.dist.compareTo(b.dist));
    final top = list.take(3).toList();
    if (top.isEmpty) {
      return emptyState('🛒', app.t('noRecent'), app.t('noRecentSub'));
    }
    return Column(
      children: [
        for (final m in top)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: marketTile(context, m, crop),
          ),
      ],
    );
  }

  Widget _upcoming(AppUser u) {
    final list = u.reminders.where((r) => r.enabled).take(2).toList();
    if (list.isEmpty) {
      return emptyState('⏰', app.t('noTasks'), app.t('noTasksSub'));
    }
    return Column(
      children: [
        for (final r in list)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: reminderTile(context, r),
          ),
      ],
    );
  }

  Widget _skel(double h) => Container(
    height: h,
    decoration: BoxDecoration(
      color: const Color(0xFFEAF0EA),
      borderRadius: BorderRadius.circular(16),
    ),
  );
}

// ------------------------------------------------------------------ //
// WEATHER
// ------------------------------------------------------------------ //
class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});
  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> with WeatherLoad {
  @override
  Widget build(BuildContext context) {
    final u = app.currentUser!;
    final src = app.weatherMode == 'live'
        ? '🛰️ ${app.t('liveMode')}'
        : '🎬 ${app.t('demoMode')}';
    return FutureBuilder<List<WxDay>>(
      future: wxFuture(),
      builder: (context, snap) {
        final fc = snap.data;
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
              decoration: const BoxDecoration(
                gradient: C.gradSky,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(26),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        app.t('weatherTitle'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      GestureDetector(
                        onTap: reloadWeather,
                        child: const CircleAvatar(
                          radius: 18,
                          backgroundColor: Color(0x33FFFFFF),
                          child: Text('🔄', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '📍 ${u.location.label} · $src',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .95),
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (fc != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${app.n(fc[0].tempMax)}°',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 42,
                                  fontWeight: FontWeight.w800,
                                  height: 1,
                                ),
                              ),
                              Text(
                                app.t(wxKey[fc[0].cond]!),
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: .9),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '💧 ${app.n(fc[0].hum)}%   🌬️ ${app.n(fc[0].wind)} km/h   🌧️ ${app.n(fc[0].rainProb)}%',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: .9),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          wxEmoji[fc[0].cond]!,
                          style: const TextStyle(fontSize: 56),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        for (var i = 0; i < fc.length; i++)
                          Column(
                            children: [
                              Text(
                                i == 0 ? app.t('today') : app.days[fc[i].dow],
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: .9),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                wxEmoji[fc[i].cond]!,
                                style: const TextStyle(fontSize: 20),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${app.n(fc[i].tempMax)}°',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              Text(
                                '💧${app.n(fc[i].rainProb)}%',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: .85),
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ] else
                    const SizedBox(
                      height: 40,
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            if (fc != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    sectionHeader(app.t('advisoryFor')),
                    if (u.crops.isEmpty)
                      advisoryCard(advisoryForDay(fc[0], app.lang))
                    else
                      for (final cid in u.crops)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: advisoryCard(
                            advisoryForDay(
                              fc.firstWhere(
                                (d) => badWeatherDay(d),
                                orElse: () => fc[0],
                              ),
                              app.lang,
                              cropId: cid,
                            ),
                            cropId: cid,
                          ),
                        ),
                    sectionHeader(app.t('dayForecast')),
                    for (var i = 0; i < fc.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _dayRow(fc[i], i),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _dayRow(WxDay d, int i) {
    final adv = advisoryForDay(d, app.lang);
    return kCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: condColor(d.cond).withValues(alpha: .14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                wxEmoji[d.cond]!,
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      i == 0 ? app.t('today') : app.days[d.dow],
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                    if (d.severe) ...[
                      const SizedBox(width: 8),
                      badge(
                        '⚠️ ${app.t('condStorm')}',
                        const Color(0xFFFEE2E2),
                        C.danger,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '🌡️ ${app.n(d.tempMax)}°/${app.n(d.tempMin)}° · 🌬️ ${app.n(d.wind)}km/h · 💧 ${app.n(d.rainProb)}%',
                  style: tsMuted(),
                ),
                const SizedBox(height: 5),
                Text(
                  adv['text'],
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: C.ink700,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ //
// MARKET
// ------------------------------------------------------------------ //
class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});
  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  String? crop;
  double radius = 30;
  String sort = 'distance';

  @override
  Widget build(BuildContext context) {
    final u = app.currentUser!;
    crop ??= u.crops.isNotEmpty ? u.crops[0] : crops[0].id;
    var list = app.marketsWithPrice(crop!, radius);
    if (sort == 'price') {
      list.sort(
        (a, b) => (b.latest?.price ?? -1).compareTo(a.latest?.price ?? -1),
      );
    } else {
      list.sort((a, b) => a.dist.compareTo(b.dist));
    }
    final priced = list
        .where((m) => m.latest != null && m.fresh)
        .map((m) => m.latest!.price)
        .toList();
    final avg = priced.isEmpty
        ? null
        : (priced.reduce((a, b) => a + b) / priced.length).round();
    final best = priced.isEmpty ? null : priced.reduce((a, b) => a > b ? a : b);
    final target = u.targets[crop];
    final cropList = u.crops.isNotEmpty
        ? u.crops
        : crops.map((c) => c.id).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: C.green600,
        onPressed: () => submitPriceSheet(context, cropId: crop),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _bar(
            app.t('marketTitle'),
            trailing: GestureDetector(
              onTap: () => setTargetSheet(context, crop!),
              child: const Text('🎯', style: TextStyle(fontSize: 20)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                sectionHeader(app.t('selectCrop')),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final cid in cropList)
                      pill(
                        '${cropById(cid)!.em} ${app.cropName(cropById(cid)!)}',
                        cid == crop,
                        () => setState(() => crop = cid),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _stat(
                      avg != null ? '৳${app.n(avg)}' : '—',
                      app.t('avgPrice'),
                    ),
                    const SizedBox(width: 10),
                    _stat(
                      best != null ? '৳${app.n(best)}' : '—',
                      app.t('bestPrice'),
                    ),
                    const SizedBox(width: 10),
                    _stat(
                      target != null ? '৳${app.n(target)}' : '—',
                      app.t('targetTitle'),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: segmented(
                        [app.t('sortDistance'), app.t('sortPrice')],
                        ['distance', 'price'],
                        sort,
                        (v) => setState(() => sort = v),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _radiusMenu(),
                  ],
                ),
                const SizedBox(height: 14),
                if (list.isEmpty)
                  emptyState('📍', app.t('noRecent'), app.t('noRecentSub'))
                else
                  for (final m in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: marketTile(context, m, crop!, best: best),
                    ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stat(String v, String l) {
    return Expanded(
      child: kCard(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Text(
              v,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: C.green700,
              ),
            ),
            const SizedBox(height: 3),
            Text(l, style: tsMuted(), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _radiusMenu() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: C.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: C.line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<double>(
          value: radius,
          items: <double>[10, 30, 50, 100]
              .map(
                (r) => DropdownMenuItem<double>(
                  value: r,
                  child: Text(
                    '${app.t('within')} ${app.n(r.toInt())} ${app.t('km')}',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => radius = v!),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ //
// TASKS
// ------------------------------------------------------------------ //
class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});
  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  @override
  Widget build(BuildContext context) {
    final u = app.currentUser!;
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: C.green600,
        onPressed: () => reminderSheet(context),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          _bar(app.t('tasksTitle')),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
            child: Column(
              children: [
                if (u.reminders.isEmpty)
                  emptyState('⏰', app.t('noTasks'), app.t('noTasksSub'))
                else
                  for (final r in u.reminders)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: reminderTile(context, r),
                    ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: C.green600,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => reminderSheet(context),
                    child: Text(
                      '➕ ${app.t('addReminder')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ //
// PROFILE
// ------------------------------------------------------------------ //
class ProfileScreen extends StatefulWidget {
  final void Function(int) onTab;
  const ProfileScreen({super.key, required this.onTab});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    final u = app.currentUser!;
    final roleLabel =
        {
          'farmer': app.t('roleFarmer'),
          'trader': app.t('roleTrader'),
          'user': app.t('roleUser'),
        }[u.role] ??
        '';
    return ListView(
      padding: EdgeInsets.zero,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [C.green800, C.green600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.vertical(bottom: Radius.circular(26)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                app.t('profileTitle'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.white.withValues(alpha: .2),
                    child: Text(
                      initials(u.name),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        u.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$roleLabel · 📍 ${u.location.label}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .9),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 14),
              kCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          app.t('myCrops'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => editCropsSheet(context),
                          child: Text(
                            app.t('changeCrops'),
                            style: const TextStyle(
                              color: C.green700,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final cid in u.crops)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 11,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: C.green50,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${cropById(cid)!.em} ${app.cropName(cropById(cid)!)}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: C.green800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              sectionHeader(app.t('settings')),
              kCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _settingRow(
                      '🌐',
                      app.t('language'),
                      SizedBox(
                        width: 130,
                        child: segmented(
                          const ['EN', 'বাংলা'],
                          const ['en', 'bn'],
                          app.lang,
                          (v) => app.setLang(v),
                        ),
                      ),
                    ),
                    const Divider(height: 1, color: C.line),
                    _settingRow(
                      '🌩️',
                      app.t('weatherAlerts'),
                      Switch(
                        value: app.weatherAlerts,
                        activeThumbColor: C.green600,
                        onChanged: app.setWeatherAlerts,
                      ),
                    ),
                    const Divider(height: 1, color: C.line),
                    _settingRow(
                      '🎯',
                      app.t('priceAlerts'),
                      Switch(
                        value: app.priceAlerts,
                        activeThumbColor: C.green600,
                        onChanged: app.setPriceAlerts,
                      ),
                    ),
                  ],
                ),
              ),
              sectionHeader(app.t('dataSource')),
              kCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    segmented(
                      ['🎬 ${app.t('demoMode')}', '🛰️ ${app.t('liveMode')}'],
                      const ['demo', 'live'],
                      app.weatherMode,
                      (v) => app.setWeatherMode(v),
                    ),
                    const SizedBox(height: 10),
                    Text(app.t('weatherModeHint'), style: tsMuted()),
                  ],
                ),
              ),
              sectionHeader(app.t('account')),
              kCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _settingRow(
                      app.useBackend ? '🟢' : '🟡',
                      app.useBackend ? app.t('syncLive') : app.t('syncLocal'),
                      const SizedBox.shrink(),
                    ),
                    const Divider(height: 1, color: C.line),
                    _settingRow(
                      '📍',
                      app.t('savedLoc'),
                      Text(u.location.label, style: tsMuted()),
                    ),
                    const Divider(height: 1, color: C.line),
                    _settingRow(
                      'ℹ️',
                      app.t('version'),
                      Text('1.0.0', style: tsMuted()),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: C.line),
                    foregroundColor: C.danger,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () => app.logout(),
                  child: Text(
                    '🚪 ${app.t('logout')}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Center(
                child: Text(
                  '${app.t('appName')} · ${app.t('tagline')}',
                  style: tsMuted(),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _settingRow(String em, String label, Widget right) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Text(em, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
          right,
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ //
// Shared tiles + top bar
// ------------------------------------------------------------------ //
Widget _bar(String title, {Widget? trailing}) {
  return Container(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: tsH1()),
        ?trailing,
      ],
    ),
  );
}

Widget marketTile(
  BuildContext context,
  MarketRow m,
  String cropId, {
  int? best,
}) {
  Widget pricePart;
  String sub;
  Widget? badgeW;
  if (m.latest != null && m.fresh) {
    pricePart = Text(
      '৳${app.n(m.latest!.price)}',
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: C.green700,
      ),
    );
    sub = '👤 ${m.latest!.by} · ${timeAgo(m.latest!.ts, app)}';
    final tgt = app.currentUser?.targets[cropId];
    if (tgt != null && m.latest!.price >= tgt) {
      badgeW = badge(
        '🎯 ${app.t('targetTitle')}',
        const Color(0xFFE0EDFF),
        const Color(0xFF1D4ED8),
      );
    } else if (best != null && m.latest!.price == best) {
      badgeW = badge(app.t('bestPrice'), C.green100, C.green800);
    }
  } else {
    pricePart = Text(
      app.t('noRecent'),
      style: const TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        color: C.ink500,
      ),
    );
    sub = app.t('noRecentSub');
  }
  return GestureDetector(
    onTap: () => marketDetailSheet(context, m.market.id, cropId),
    child: kCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: C.green50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('🏪', style: TextStyle(fontSize: 20)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        app.marketName(m.market),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (badgeW != null) ...[const SizedBox(width: 6), badgeW],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  sub,
                  style: tsMuted(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              pricePart,
              const SizedBox(height: 2),
              Text(
                '📍 ${app.n(m.dist.toStringAsFixed(1))} ${app.t('km')}',
                style: tsMuted(),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

Widget reminderTile(BuildContext context, Reminder r) {
  final tt = taskTypeById(r.type);
  final crop = cropById(r.cropId);
  final repeat =
      {
        'none': app.t('repeatNone'),
        'daily': app.t('repeatDaily'),
        'weekly': app.t('repeatWeekly'),
      }[r.repeat] ??
      '';
  final moved = r.movedToDate != null;
  return Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: C.card,
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0F14532D),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ],
      border: moved ? Border.all(color: C.amber.withValues(alpha: .5)) : null,
    ),
    child: Column(
      children: [
        Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: C.green50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  tt?.em ?? '⏰',
                  style: const TextStyle(fontSize: 20),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${tt != null ? (app.lang == 'bn' ? tt.bn : tt.en) : ''}${crop != null ? ' · ${crop.em} ${app.cropName(crop)}' : ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text('🔁 $repeat · 🕒 ${r.time}', style: tsMuted()),
                ],
              ),
            ),
            Switch(
              value: r.enabled,
              activeThumbColor: C.green600,
              onChanged: (_) => app.toggleReminder(r.id),
            ),
          ],
        ),
        if (moved) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: C.amber100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '🌦️ ${app.t('autoMoved')} → ${r.movedToDate}',
              style: const TextStyle(
                color: C.amber700,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  side: const BorderSide(color: C.line),
                  foregroundColor: C.ink700,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => reminderSheet(context, existing: r),
                child: Text(
                  '✏️ ${app.t('edit')}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  side: const BorderSide(color: C.line),
                  foregroundColor: C.danger,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  await app.deleteReminder(r.id);
                  if (context.mounted) {
                    snack(context, '🗑️ ${app.t('reminderDeleted')}');
                  }
                },
                child: Text(
                  '🗑️ ${app.t('delete')}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// ------------------------------------------------------------------ //
// Bottom sheets
// ------------------------------------------------------------------ //
Future<T?> _sheet<T>(BuildContext context, Widget child) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: C.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 10,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: C.line,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            child,
            const SizedBox(height: 24),
          ],
        ),
      ),
    ),
  );
}

void submitPriceSheet(
  BuildContext context, {
  String? cropId,
  String? marketId,
}) {
  final u = app.currentUser!;
  String cid = cropId ?? (u.crops.isNotEmpty ? u.crops[0] : crops[0].id);
  String mid = marketId ?? app.markets[0].id;
  final priceC = TextEditingController();
  final newNameC = TextEditingController();
  String? err;
  _sheet(
    context,
    StatefulBuilder(
      builder: (ctx, setS) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(app.t('submitPrice'), style: tsH2()),
            const SizedBox(height: 4),
            Text(
              '${app.t('priceFor')} ${cropById(cid)!.em} ${app.cropName(cropById(cid)!)}',
              style: tsSub(),
            ),
            const SizedBox(height: 16),
            if (err != null) _sheetErr(err!),
            _label(app.t('selectCrop')),
            _dropdown<String>(cid, [
              for (final c in crops)
                DropdownMenuItem(
                  value: c.id,
                  child: Text('${c.em} ${app.cropName(c)}'),
                ),
            ], (v) => setS(() => cid = v!)),
            const SizedBox(height: 12),
            _label(app.t('atMarket')),
            _dropdown<String>(mid, [
              ...app.markets.map(
                (m) => DropdownMenuItem(
                  value: m.id,
                  child: Text(app.marketName(m)),
                ),
              ),
              DropdownMenuItem(
                value: '__new',
                child: Text('➕ ${app.t('addMarket')}'),
              ),
            ], (v) => setS(() => mid = v!)),
            if (mid == '__new') ...[
              const SizedBox(height: 12),
              _label(app.t('marketName')),
              TextField(
                controller: newNameC,
                decoration: InputDecoration(hintText: app.t('marketName')),
              ),
            ],
            const SizedBox(height: 12),
            _label(app.t('pricePerKg')),
            TextField(
              controller: priceC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                prefixText: '৳ ',
                hintText: '0',
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '🕒 ${app.t('reportedBy')} ${firstName(u.name)} · ${app.t('today')}',
              style: tsMuted(),
            ),
            const SizedBox(height: 16),
            _sheetBtn('${app.t('submitPrice')} ✓', () async {
              final price = int.tryParse(priceC.text.trim());
              if (price == null || price <= 0) {
                setS(() => err = app.t('errPrice'));
                return;
              }
              await app.submitPrice(
                cropId: cid,
                marketId: mid,
                price: price,
                newMarketName: newNameC.text,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                snack(context, '✅ ${app.t('priceSubmitted')}', type: 'ok');
              }
            }),
          ],
        );
      },
    ),
  );
}

void setTargetSheet(BuildContext context, String cropId) {
  final u = app.currentUser!;
  final crop = cropById(cropId)!;
  final list = app
      .marketsWithPrice(cropId, 100)
      .where((m) => m.latest != null && m.fresh)
      .map((m) => m.latest!.price)
      .toList();
  final range = list.isEmpty
      ? '—'
      : '৳${app.n(list.reduce((a, b) => a < b ? a : b))} – ৳${app.n(list.reduce((a, b) => a > b ? a : b))}';
  final cur = u.targets[cropId];
  final valC = TextEditingController(text: cur?.toString() ?? '');
  String? err;
  _sheet(
    context,
    StatefulBuilder(
      builder: (ctx, setS) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(app.t('setTarget'), style: tsH2()),
            const SizedBox(height: 4),
            Text('${crop.em} ${app.cropName(crop)}', style: tsSub()),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: C.green50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '📈 ${app.t('currentRange')}: $range',
                style: const TextStyle(
                  color: C.green800,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (err != null) _sheetErr(err!),
            _label(app.t('targetValue')),
            TextField(
              controller: valC,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                prefixText: '🎯 ',
                hintText: '0',
              ),
            ),
            const SizedBox(height: 6),
            Text(app.t('targetHint'), style: tsMuted()),
            const SizedBox(height: 16),
            _sheetBtn(
              '${cur != null ? app.t('updateTarget') : app.t('setTarget')} ✓',
              () async {
                final v = int.tryParse(valC.text.trim());
                if (v == null || v <= 0) {
                  setS(() => err = app.t('errTarget'));
                  return;
                }
                await app.setTarget(cropId, v);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  snack(context, '🎯 ${app.t('targetSet')}', type: 'ok');
                }
              },
            ),
            if (cur != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: const BorderSide(color: C.line),
                    foregroundColor: C.danger,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () async {
                    await app.removeTarget(cropId);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      snack(context, '🗑️ ${app.t('targetRemoved')}');
                    }
                  },
                  child: Text(
                    app.t('removeTarget'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    ),
  );
}

void reminderSheet(BuildContext context, {Reminder? existing}) {
  final u = app.currentUser!;
  String type = existing?.type ?? 'irrigation';
  String cid =
      existing?.cropId ?? (u.crops.isNotEmpty ? u.crops[0] : crops[0].id);
  String repeat = existing?.repeat ?? 'daily';
  String time = existing?.time ?? '06:00';
  _sheet(
    context,
    StatefulBuilder(
      builder: (ctx, setS) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              existing != null ? app.t('edit') : app.t('addReminder'),
              style: tsH2(),
            ),
            const SizedBox(height: 14),
            _label(app.t('taskType')),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tp in taskTypes)
                  chipChoice(
                    '${tp.em} ${app.lang == 'bn' ? tp.bn : tp.en}',
                    type == tp.id,
                    () => setS(() => type = tp.id),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            _label(app.t('forCrop')),
            _dropdown<String>(cid, [
              for (final c in crops)
                DropdownMenuItem(
                  value: c.id,
                  child: Text('${c.em} ${app.cropName(c)}'),
                ),
            ], (v) => setS(() => cid = v!)),
            const SizedBox(height: 14),
            _label(app.t('repeat')),
            segmented(
              [
                app.t('repeatNone'),
                app.t('repeatDaily'),
                app.t('repeatWeekly'),
              ],
              const ['none', 'daily', 'weekly'],
              repeat,
              (v) => setS(() => repeat = v),
            ),
            const SizedBox(height: 14),
            _label(app.t('time')),
            GestureDetector(
              onTap: () async {
                final parts = time.split(':');
                final picked = await showTimePicker(
                  context: ctx,
                  initialTime: TimeOfDay(
                    hour: int.parse(parts[0]),
                    minute: int.parse(parts[1]),
                  ),
                );
                if (picked != null) {
                  setS(
                    () => time =
                        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}',
                  );
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F6F1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '🕒  $time',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: C.sky100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                app.lang == 'bn'
                    ? '🌦️ আবহাওয়া খারাপ হলে এই কাজ স্বয়ংক্রিয়ভাবে পিছিয়ে যাবে।'
                    : '🌦️ This task auto-reschedules if the weather turns bad on its day.',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: Color(0xFF075985),
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _sheetBtn('${app.t('save')} ✓', () async {
              await app.saveReminder(
                id: existing?.id,
                type: type,
                cropId: cid,
                repeat: repeat,
                time: time,
              );
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                snack(context, '✅ ${app.t('reminderSaved')}', type: 'ok');
              }
            }),
          ],
        );
      },
    ),
  );
}

void editCropsSheet(BuildContext context) {
  final u = app.currentUser!;
  final sel = Set<String>.from(u.crops);
  _sheet(
    context,
    StatefulBuilder(
      builder: (ctx, setS) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(app.t('myCrops'), style: tsH2()),
            const SizedBox(height: 4),
            Text(app.t('cropsSub'), style: tsSub()),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in crops)
                  chipChoice(
                    '${c.em} ${app.cropName(c)}',
                    sel.contains(c.id),
                    () => setS(
                      () =>
                          sel.contains(c.id) ? sel.remove(c.id) : sel.add(c.id),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            _sheetBtn('${app.t('save')} ✓', () async {
              if (sel.isEmpty) return;
              await app.setCrops(sel.toList());
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                snack(context, '✅ ${app.t('profileUpdated')}', type: 'ok');
              }
            }),
          ],
        );
      },
    ),
  );
}

void marketDetailSheet(BuildContext context, String marketId, String cropId) {
  final m = app.markets.firstWhere((x) => x.id == marketId);
  final entries = app.marketEntries(marketId, cropId);
  final crop = cropById(cropId)!;
  _sheet(
    context,
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(app.marketName(m), style: tsH2()),
        const SizedBox(height: 4),
        Text(
          '${crop.em} ${app.cropName(crop)} · ${app.t('latestPrice')}',
          style: tsSub(),
        ),
        const SizedBox(height: 14),
        if (entries.isEmpty)
          emptyState('🏷️', app.t('noRecent'), app.t('noRecentSub'))
        else
          for (final e in entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: kCard(
                child: Row(
                  children: [
                    Text(
                      e.role == 'trader'
                          ? '🛒'
                          : e.role == 'farmer'
                          ? '🧑‍🌾'
                          : '👤',
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.by,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(timeAgo(e.ts, app), style: tsMuted()),
                        ],
                      ),
                    ),
                    Text(
                      '৳${app.n(e.price)}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: C.green700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 8),
        _sheetBtn('🏷️ ${app.t('reportPrice')}', () {
          Navigator.pop(context);
          submitPriceSheet(context, cropId: cropId, marketId: marketId);
        }),
      ],
    ),
  );
}

// sheet helpers
Widget _label(String s) => Padding(
  padding: const EdgeInsets.only(bottom: 6, left: 2),
  child: Text(
    s,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: C.ink700,
    ),
  ),
);
Widget _sheetErr(String s) => Container(
  width: double.infinity,
  margin: const EdgeInsets.only(bottom: 12),
  padding: const EdgeInsets.all(10),
  decoration: BoxDecoration(
    color: const Color(0xFFFEF2F2),
    borderRadius: BorderRadius.circular(10),
  ),
  child: Text(
    s,
    style: const TextStyle(
      color: C.danger,
      fontSize: 13,
      fontWeight: FontWeight.w600,
    ),
  ),
);
Widget _sheetBtn(String label, VoidCallback onTap) => SizedBox(
  width: double.infinity,
  child: FilledButton(
    style: FilledButton.styleFrom(
      backgroundColor: C.green600,
      padding: const EdgeInsets.symmetric(vertical: 15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    onPressed: onTap,
    child: Text(
      label,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 15,
      ),
    ),
  ),
);
Widget _dropdown<T>(
  T value,
  List<DropdownMenuItem<T>> items,
  ValueChanged<T?> onChanged,
) => Container(
  padding: const EdgeInsets.symmetric(horizontal: 14),
  decoration: BoxDecoration(
    color: const Color(0xFFF1F6F1),
    borderRadius: BorderRadius.circular(14),
  ),
  child: DropdownButtonHideUnderline(
    child: DropdownButton<T>(
      value: value,
      isExpanded: true,
      items: items,
      onChanged: onChanged,
    ),
  ),
);
