// Reads an optional Firebase config injected at runtime in web/index.html
// (window.KB_FIREBASE = {...}). Lets the app go live with cross-device sync
// without rebuilding. Uses a conditional import so non-web targets (the Dart
// VM used by `flutter test`) compile against a harmless stub.
import 'firebase_boot_stub.dart' if (dart.library.js_interop) 'firebase_boot_web.dart' as impl;

Map<String, String>? readWebFirebaseConfig() => impl.readWebFirebaseConfig();
