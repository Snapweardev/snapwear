import 'dart:async';
import 'dart:js_interop';

@JS('window.sessionStorage')
external _Storage get _session;
@JS('window.localStorage')
external _Storage get _local;
@JS('window.indexedDB')
external _Idb get _idb;

extension type _Storage(JSObject _) implements JSObject {
  external int get length;
  external String? key(int i);
  external void removeItem(String key);
}

extension type _Idb(JSObject _) implements JSObject {
  external _Request open(String name);
}

extension type _Request(JSObject _) implements JSObject {
  external JSAny? get result;
  external set onsuccess(JSFunction f);
  external set onerror(JSFunction f);
  external set onblocked(JSFunction f);
}

extension type _Database(JSObject _) implements JSObject {
  external _Names get objectStoreNames;
  external _Transaction transaction(String store, String mode);
  external void close();
}

extension type _Names(JSObject _) implements JSObject {
  external bool contains(String name);
}

extension type _Transaction(JSObject _) implements JSObject {
  external _Store objectStore(String name);
  external set oncomplete(JSFunction f);
  external set onerror(JSFunction f);
}

extension type _Store(JSObject _) implements JSObject {
  @JS('delete')
  external _Request remove(String key);
}

/// Local demo auth only: avoid restoring an expired demo token before the
/// FlutterFire web plugin has connected its emulator. No production keys/data.
Future<void> resetLocalAuthMarker() async {
  const key = 'firebase:authUser:demo-local-key:[DEFAULT]';
  for (final storage in [_session, _local]) {
    final keys = <String>[];
    for (var i = 0; i < storage.length; i++) {
      final k = storage.key(i);
      if (k != null && k.endsWith('-firebaseEmulatorOrigin')) keys.add(k);
    }
    for (final k in keys) {
      storage.removeItem(k);
    }
    storage.removeItem(key);
  }
  final done = Completer<void>();
  void finish() {
    if (!done.isCompleted) done.complete();
  }

  try {
    final request = _idb.open('firebaseLocalStorageDb');
    request.onerror = ((JSAny? e) {
      finish();
    }).toJS;
    request.onblocked = ((JSAny? e) {
      finish();
    }).toJS;
    request.onsuccess = ((JSAny? e) {
      final db = _Database(request.result as JSObject);
      if (!db.objectStoreNames.contains('firebaseLocalStorage')) {
        db.close();
        finish();
        return;
      }
      final tx = db.transaction('firebaseLocalStorage', 'readwrite');
      tx.oncomplete = ((JSAny? e) {
        db.close();
        finish();
      }).toJS;
      tx.onerror = ((JSAny? e) {
        db.close();
        finish();
      }).toJS;
      tx.objectStore('firebaseLocalStorage').remove(key);
    }).toJS;
    await done.future.timeout(const Duration(seconds: 2), onTimeout: finish);
  } catch (_) {
    finish();
  }
}
