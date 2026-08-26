// KrishiBondhu — app entry point.
import 'package:flutter/material.dart';
import 'state.dart';
import 'theme.dart';
import 'screen_auth.dart';
import 'screen_main.dart';

final AppState app = AppState();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await app.init();
  runApp(const KrishiApp());
}

class KrishiApp extends StatelessWidget {
  const KrishiApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) => MaterialApp(
        title: 'KrishiBondhu',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const RootGate(),
      ),
    );
  }
}

class RootGate extends StatefulWidget {
  const RootGate({super.key});
  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  bool _revealed = false;
  bool _introShown = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1700), () {
      if (mounted) setState(() => _revealed = true);
    });
  }

  void _maybeIntro() {
    if (_revealed && !_introShown) {
      _introShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showIntroDialog(context);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_revealed) return const SplashScreen();
    _maybeIntro();
    return app.currentUser != null ? const Shell() : const AuthScreen();
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(colors: [C.green800, C.green600], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 96, height: 96,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(28)),
                child: const Center(child: Text('🌾', style: TextStyle(fontSize: 52))),
              ),
              const SizedBox(height: 20),
              Text(app.t('appName'), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 6),
              Text(app.t('tagline'), style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: .85))),
              const SizedBox(height: 28),
              SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white.withValues(alpha: .9))),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ //
// "Under construction" intro popup (bilingual) — shown each app open
// ------------------------------------------------------------------ //
void showIntroDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierColor: Colors.black.withValues(alpha: .55),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(22),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(color: C.card, borderRadius: BorderRadius.circular(26)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // caution-tape strip
            SizedBox(
              height: 9,
              child: Row(children: List.generate(40, (i) => Expanded(child: Container(color: i.isEven ? C.amber : const Color(0xFF1F2937))))),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 88, height: 88,
                  decoration: BoxDecoration(gradient: C.gradSun, borderRadius: BorderRadius.circular(24),
                      boxShadow: [BoxShadow(color: C.amber.withValues(alpha: .4), blurRadius: 24, offset: const Offset(0, 12))]),
                  child: const Center(child: Text('🚧', style: TextStyle(fontSize: 46))),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: C.amber100, borderRadius: BorderRadius.circular(999)),
                  child: const Text('🚧  UNDER CONSTRUCTION', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: C.amber700)),
                ),
                const SizedBox(height: 12),
                Text(app.t('appName'), style: tsH1()),
                const SizedBox(height: 10),
                const Text('This is a Mobile Web App and is currently under construction.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: C.ink700, height: 1.5)),
                const SizedBox(height: 6),
                const Text('এটি একটি মোবাইল ওয়েব অ্যাপ, বর্তমানে নির্মাণাধীন অবস্থায় আছে।',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 14.5, color: C.ink700, height: 1.7)),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(color: C.green50, borderRadius: BorderRadius.circular(14), border: Border.all(color: C.green100)),
                  child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('🎬  ', style: TextStyle(fontSize: 17)),
                    Expanded(child: Text('To test the app, please log in with a demo account.\nটেস্ট করার জন্য একটি ডেমো অ্যাকাউন্ট দিয়ে লগইন করুন।',
                        style: TextStyle(fontSize: 12.5, color: C.green800, height: 1.6))),
                  ]),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: C.green600, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: Text('${app.t('continue')}  →', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    ),
  );
}
