// KrishiBondhu — shared UI widgets & helpers.
import 'package:flutter/material.dart';
import 'main.dart';
import 'theme.dart';
import 'data.dart';

void snack(BuildContext c, String msg, {String type = ''}) {
  final bg = type == 'ok' ? C.green700 : type == 'warn' ? C.amber700 : C.ink900;
  ScaffoldMessenger.of(c)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(12),
      duration: const Duration(milliseconds: 2600),
    ));
}

Color condColor(String cond) {
  switch (cond) {
    case 'storm':
      return const Color(0xFF7C3AED);
    case 'rain':
      return C.sky;
    case 'cloud':
      return const Color(0xFF64748B);
    default:
      return C.amber;
  }
}

Widget kCard({required Widget child, EdgeInsetsGeometry? padding}) {
  return Container(
    padding: padding ?? const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: C.card,
      borderRadius: BorderRadius.circular(18),
      boxShadow: const [BoxShadow(color: Color(0x0F14532D), blurRadius: 18, offset: Offset(0, 6))],
    ),
    child: child,
  );
}

Widget sectionHeader(String title, {Widget? action}) {
  return Padding(
    padding: const EdgeInsets.only(top: 22, bottom: 12),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(title, style: tsH2()),
      if (action != null) action,
    ]),
  );
}

Widget linkText(String label, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: Text('$label →', style: const TextStyle(color: C.green700, fontWeight: FontWeight.w700, fontSize: 13.5)),
  );
}

Widget emptyState(String em, String title, String sub) {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
    alignment: Alignment.center,
    child: Column(children: [
      Text(em, style: const TextStyle(fontSize: 40)),
      const SizedBox(height: 10),
      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: C.ink700)),
      const SizedBox(height: 4),
      Text(sub, textAlign: TextAlign.center, style: tsMuted()),
    ]),
  );
}

Widget pill(String label, bool on, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      decoration: BoxDecoration(
        color: on ? C.green600 : C.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: on ? C.green600 : C.line),
        boxShadow: on ? [BoxShadow(color: C.green600.withValues(alpha: .25), blurRadius: 10, offset: const Offset(0, 4))] : null,
      ),
      child: Text(label, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5, color: on ? Colors.white : C.ink700)),
    ),
  );
}

Widget chipChoice(String label, bool on, VoidCallback onTap) {
  return GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: on ? C.green50 : C.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: on ? C.green500 : C.line, width: on ? 1.6 : 1),
      ),
      child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: on ? C.green800 : C.ink700)),
    ),
  );
}

Widget segmented(List<String> labels, List<String> values, String current, ValueChanged<String> onPick) {
  return Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(color: const Color(0xFFEDF3ED), borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      for (var i = 0; i < labels.length; i++)
        Expanded(
          child: GestureDetector(
            onTap: () => onPick(values[i]),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(vertical: 9),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: current == values[i] ? C.card : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
                boxShadow: current == values[i] ? const [BoxShadow(color: Color(0x14000000), blurRadius: 6)] : null,
              ),
              child: Text(labels[i], style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: current == values[i] ? C.green700 : C.ink500)),
            ),
          ),
        ),
    ]),
  );
}

Widget advisoryCard(Map adv, {String? cropId}) {
  final level = adv['level'];
  final emoji = level == 'crit' ? '⛈️' : level == 'warn' ? '🌦️' : '🌱';
  final bg = level == 'crit' ? const Color(0xFFFFF1F2) : level == 'warn' ? const Color(0xFFFFF7ED) : C.green50;
  final accent = level == 'crit' ? C.danger : level == 'warn' ? C.amber : C.green600;
  final crop = cropById(cropId);
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(18),
      border: Border(left: BorderSide(color: accent, width: 4)),
    ),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(emoji, style: const TextStyle(fontSize: 26)),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(adv['title'], style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: C.ink900)),
          const SizedBox(height: 5),
          Text(adv['text'], style: const TextStyle(fontSize: 13, color: C.ink700, height: 1.5)),
          if (crop != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .7), borderRadius: BorderRadius.circular(999)),
              child: Text('${crop.em} ${app.cropName(crop)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: C.ink700)),
            ),
          ],
        ]),
      ),
    ]),
  );
}

Widget badge(String text, Color bg, Color fg) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
    child: Text(text, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: fg)),
  );
}
