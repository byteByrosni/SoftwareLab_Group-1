// KrishiBondhu — authentication (login + register wizard + onboarding).
import 'package:flutter/material.dart';
import 'main.dart';
import 'state.dart';
import 'theme.dart';
import 'data.dart';
import 'ui.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  String mode = 'login'; // login | register
  String step = 'form'; // form | location | crops
  String? error;

  final nameC = TextEditingController();
  final credC = TextEditingController();
  final passC = TextEditingController();
  final locC = TextEditingController();
  String role = 'farmer';
  Loc? location;
  final Set<String> pickedCrops = {};
  bool _submitting = false;

  void _login() {
    if (_submitting) return;
    setState(() => _submitting = true);
    final err = app.login(credC.text, passC.text);
    // Always release the button. notifyListeners() only marks the tree dirty —
    // the rebuild that swaps this screen out happens on the next frame — so
    // this runs safely either way, and the button can never latch on failure.
    if (!mounted) return;
    setState(() {
      error = err;
      _submitting = false;
    });
  }

  bool _validateStep1() {
    if (nameC.text.trim().isEmpty) {
      setState(() => error = app.t('errName'));
      return false;
    }
    if (credC.text.trim().isEmpty) {
      setState(() => error = app.t('errCred'));
      return false;
    }
    if (!AppState.isValidPhone(credC.text) && !AppState.isValidEmail(credC.text)) {
      setState(() => error = app.t('errCredFormat'));
      return false;
    }
    if (passC.text.length < 4) {
      setState(() => error = app.t('errPass'));
      return false;
    }
    setState(() => error = null);
    return true;
  }

  void _finish() {
    if (pickedCrops.isEmpty) {
      setState(() => error = app.t('selectAtLeastOne'));
      return;
    }
    if (_submitting) return;
    setState(() => _submitting = true);
    final err = app.register(
      name: nameC.text, cred: credC.text, pass: passC.text, role: role,
      location: location ?? Loc(22.3569, 91.7832, locC.text.trim().isEmpty ? 'Chattogram' : locC.text.trim()),
      crops: pickedCrops.toList(),
    );
    if (!mounted) return;
    setState(() {
      error = err;
      _submitting = false;
    });
  }

  // System back: step backwards through the register wizard (crops → location →
  // form → login) rather than closing the app. Mirrors the in-app "← Back"
  // links, and covers step 1, which has no back affordance of its own.
  void _handleBack() {
    setState(() {
      if (step == 'crops') {
        step = 'location';
      } else if (step == 'location') {
        step = 'form';
      } else {
        mode = 'login';
        step = 'form';
      }
      error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: mode == 'login',
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(children: [
            _hero(),
            Container(
              width: double.infinity,
              transform: Matrix4.translationValues(0, -20, 0),
              decoration: const BoxDecoration(color: C.card, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 32),
              child: mode == 'login' ? _loginForm() : _registerFlow(),
            ),
          ]),
        ),
      ),
      ),
    );
  }

  Widget _hero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 40),
      decoration: const BoxDecoration(gradient: LinearGradient(colors: [C.green800, C.green600], begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 46, height: 46, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), borderRadius: BorderRadius.circular(14)), child: const Center(child: Text('🌾', style: TextStyle(fontSize: 24)))),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(app.t('appName'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
            Text(app.t('tagline'), style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: .85))),
          ]),
          const Spacer(),
          _langToggle(),
        ]),
        if (app.backendSyncing) ...[
          const SizedBox(height: 12),
          _syncingBadge(),
        ],
        const SizedBox(height: 20),
        Center(child: Text(mode == 'login' ? '🧑‍🌾' : '🌱', style: const TextStyle(fontSize: 54))),
      ]),
    );
  }

  Widget _syncingBadge() {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white.withValues(alpha: .85))),
      const SizedBox(width: 8),
      Text(app.t('syncingNow'), style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: .85))),
    ]);
  }

  Widget _langToggle() {
    return Container(
      width: 120,
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), borderRadius: BorderRadius.circular(10)),
      padding: const EdgeInsets.all(3),
      child: Row(children: [
        for (final l in ['en', 'bn'])
          Expanded(child: GestureDetector(
            onTap: () => app.setLang(l),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 6),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: app.lang == l ? Colors.white : Colors.transparent, borderRadius: BorderRadius.circular(8)),
              child: Text(l == 'en' ? 'EN' : 'বাংলা', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5, color: app.lang == l ? C.green700 : Colors.white)),
            ),
          )),
      ]),
    );
  }

  Widget _field(String label, TextEditingController c, {String? hint, bool obscure = false, String icon = ''}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(bottom: 6, left: 2), child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.ink700))),
      TextField(
        controller: c,
        obscureText: obscure,
        decoration: InputDecoration(hintText: hint, prefixIcon: icon.isEmpty ? null : Padding(padding: const EdgeInsets.only(left: 14, right: 8), child: Text(icon, style: const TextStyle(fontSize: 17))), prefixIconConstraints: const BoxConstraints(minWidth: 0)),
      ),
      const SizedBox(height: 14),
    ]);
  }

  Widget _errorBox() {
    if (error == null) return const SizedBox.shrink();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: const Color(0xFFFEF2F2), borderRadius: BorderRadius.circular(10)),
      child: Text(error!, style: const TextStyle(color: C.danger, fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }

  Widget _primaryBtn(String label, VoidCallback onTap, {bool loading = false}) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: C.green600, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
        onPressed: loading ? null : onTap,
        child: loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white))
            : Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
      ),
    );
  }

  // ---------------- LOGIN ----------------
  Widget _loginForm() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(app.t('welcome'), style: tsH1()),
      const SizedBox(height: 6),
      Text(app.t('signInSub'), style: tsSub()),
      const SizedBox(height: 18),
      _errorBox(),
      _field(app.t('phoneEmail'), credC, hint: '01XXXXXXXXX', icon: '📱'),
      _field(app.t('password'), passC, hint: '••••••', obscure: true, icon: '🔒'),
      _primaryBtn('${app.t('login')}  →', _login, loading: _submitting),
      const SizedBox(height: 18),
      Center(child: GestureDetector(
        onTap: () => setState(() { mode = 'register'; step = 'form'; error = null; }),
        child: RichText(text: TextSpan(style: tsSub(), children: [
          TextSpan(text: '${app.t('noAccount')} '),
          TextSpan(text: app.t('register'), style: const TextStyle(color: C.green700, fontWeight: FontWeight.w700)),
        ])),
      )),
    ]);
  }

  // ---------------- REGISTER ----------------
  Widget _registerFlow() {
    if (step == 'location') return _stepLocation();
    if (step == 'crops') return _stepCrops();
    return _stepForm();
  }

  Widget _stepDots(int active) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        for (var i = 1; i <= 3; i++) ...[
          Container(width: i <= active ? 22 : 8, height: 8, decoration: BoxDecoration(color: i <= active ? C.green600 : C.line, borderRadius: BorderRadius.circular(4))),
          if (i < 3) const SizedBox(width: 6),
        ],
      ]),
    );
  }

  Widget _stepForm() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _stepDots(1),
      Text(app.t('createAccount'), style: tsH1()),
      const SizedBox(height: 6),
      Text(app.t('registerSub'), style: tsSub()),
      const SizedBox(height: 18),
      _errorBox(),
      _field(app.t('fullName'), nameC, hint: app.t('fullName'), icon: '🧑'),
      _field(app.t('phoneEmail'), credC, hint: '01XXXXXXXXX', icon: '📱'),
      _field(app.t('password'), passC, hint: '••••••', obscure: true, icon: '🔒'),
      Text(app.t('role'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: C.ink700)),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final r in [['farmer', '🧑‍🌾', app.t('roleFarmer')], ['trader', '🛒', app.t('roleTrader')], ['user', '👤', app.t('roleUser')]])
          chipChoice('${r[1]} ${r[2]}', role == r[0], () => setState(() => role = r[0])),
      ]),
      const SizedBox(height: 18),
      _primaryBtn('${app.t('next')}  →', () { if (_validateStep1()) setState(() => step = 'location'); }),
      const SizedBox(height: 14),
      Center(child: GestureDetector(
        onTap: () => setState(() { mode = 'login'; error = null; }),
        child: RichText(text: TextSpan(style: tsSub(), children: [
          TextSpan(text: '${app.t('haveAccount')} '),
          TextSpan(text: app.t('login'), style: const TextStyle(color: C.green700, fontWeight: FontWeight.w700)),
        ])),
      )),
    ]);
  }

  Widget _stepLocation() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _stepDots(2),
      Text(app.t('setLocation'), style: tsH1()),
      const SizedBox(height: 6),
      Text(app.t('locationSub'), style: tsSub()),
      const SizedBox(height: 16),
      const Center(child: Text('📍', style: TextStyle(fontSize: 48))),
      const SizedBox(height: 16),
      _field(app.t('enterManually'), locC, hint: app.t('district'), icon: '📍'),
      _primaryBtn('${app.t('continue')}  →', () {
        final manual = locC.text.trim();
        final hit = manual.isNotEmpty ? lookupDistrict(manual) : null;
        location = Loc(hit?[0] ?? 22.3569, hit?[1] ?? 91.7832, manual.isEmpty ? 'Chattogram' : manual);
        setState(() { step = 'crops'; error = null; });
      }),
      const SizedBox(height: 12),
      Center(child: GestureDetector(onTap: () => setState(() => step = 'form'), child: Text('← ${app.t('back')}', style: tsSub()))),
    ]);
  }

  Widget _stepCrops() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _stepDots(3),
      Text(app.t('pickCrops'), style: tsH1()),
      const SizedBox(height: 6),
      Text(app.t('cropsSub'), style: tsSub()),
      const SizedBox(height: 16),
      _errorBox(),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final c in crops)
          chipChoice('${c.em} ${app.cropName(c)}', pickedCrops.contains(c.id), () => setState(() {
                pickedCrops.contains(c.id) ? pickedCrops.remove(c.id) : pickedCrops.add(c.id);
              })),
      ]),
      const SizedBox(height: 20),
      _primaryBtn('${app.t('done')}  ✓', _finish, loading: _submitting),
      const SizedBox(height: 12),
      Center(child: GestureDetector(onTap: () => setState(() => step = 'location'), child: Text('← ${app.t('back')}', style: tsSub()))),
    ]);
  }
}
