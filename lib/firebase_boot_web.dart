// Web implementation: reads window.KB_FIREBASE injected in index.html.
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

Map<String, String>? readWebFirebaseConfig() {
  try {
    final w = globalContext;
    if (!w.has('KB_FIREBASE')) return null;
    final cfg = w.getProperty('KB_FIREBASE'.toJS);
    if (cfg.isUndefinedOrNull) return null;
    final obj = cfg as JSObject;
    String? g(String k) {
      if (!obj.has(k)) return null;
      final v = obj.getProperty(k.toJS);
      if (v.isUndefinedOrNull) return null;
      return (v as JSString).toDart;
    }

    final apiKey = g('apiKey');
    final projectId = g('projectId');
    if (apiKey == null || apiKey.isEmpty || apiKey.startsWith('PASTE_') || projectId == null || projectId.isEmpty) {
      return null;
    }
    return {
      'apiKey': apiKey,
      'appId': g('appId') ?? '',
      'messagingSenderId': g('messagingSenderId') ?? '',
      'projectId': projectId,
      'authDomain': g('authDomain') ?? '$projectId.firebaseapp.com',
      'storageBucket': g('storageBucket') ?? '$projectId.appspot.com',
    };
  } catch (_) {
    return null;
  }
}
