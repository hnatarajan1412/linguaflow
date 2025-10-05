// Minimal web auth backed by Firebase Web SDK via JS interop.
// We use the compat builds to keep the API simple: firebase.auth().

@JS('firebase')
library;

import 'dart:async';
import 'dart:js_util' as jsu;
import 'package:js/js.dart';

// ignore: avoid_classes_with_only_static_members
class _Fw {
  static dynamic get _firebase => jsu.getProperty(globalThis, 'firebase');
  static dynamic get _auth => jsu.callMethod(_firebase, 'auth', const []);
  static dynamic get _authNs => jsu.getProperty(_firebase, 'auth');
}

@JS('globalThis')
external dynamic get globalThis;

class AuthService {
  Stream<dynamic> authStateChanges() async* {
    // Not used on web in this app; return empty stream.
    yield* const Stream.empty();
  }

  dynamic get currentUser => jsu.getProperty(_Fw._auth, 'currentUser');

  Future<void> signInWithEmail(String email, String password) async {
    await jsu.promiseToFuture(jsu.callMethod(_Fw._auth, 'signInWithEmailAndPassword', [email, password]));
  }

  Future<void> signUpWithEmail(String email, String password) async {
    await jsu.promiseToFuture(jsu.callMethod(_Fw._auth, 'createUserWithEmailAndPassword', [email, password]));
  }

  Future<void> signInWithGoogle() async {
    final providerCtor = jsu.getProperty(_Fw._authNs, 'GoogleAuthProvider');
    final provider = jsu.callConstructor(providerCtor, const []);
    await jsu.promiseToFuture(jsu.callMethod(_Fw._auth, 'signInWithPopup', [provider]));
  }

  Future<void> signOut() async {
    await jsu.promiseToFuture(jsu.callMethod(_Fw._auth, 'signOut', const []));
  }
}
