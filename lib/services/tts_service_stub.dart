import 'dart:async';

import 'tts_service.dart';

class _NoopTtsService implements TtsService {
  String _lang = 'en-US';
  @override
  Future<void> init({String? language}) async { _lang = language ?? _lang; }

  @override
  Future<void> setLanguage(String language) async { _lang = language; }

  @override
  Future<void> setPitch(double pitch) async {}

  @override
  Future<void> setRate(double rate) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> speak(String text) async {
    // ignore: avoid_print
    print('[TTS][noop] speak: ' + text);
  }

  @override
  Future<void> stop() async {}

  @override
  Future<List<Map<String, String>>> voices() async => <Map<String, String>>[];

  @override
  Future<void> setVoice(Map<String, String> voice) async {}
}

TtsService getTtsService() => _NoopTtsService();
