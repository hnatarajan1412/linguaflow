// Cross-platform TTS abstraction with conditional imports.
// - Web: uses browser SpeechSynthesis API
// - Mobile (Android/iOS): uses flutter_tts
// - Fallback: no-op

import 'tts_service_stub.dart'
    if (dart.library.html) 'tts_service_web.dart'
    if (dart.library.io) 'tts_service_mobile.dart';

abstract class TtsService {
  Future<void> init({String? language});
  Future<void> setVolume(double volume); // 0.0 - 1.0
  Future<void> setRate(double rate);     // 0.1 - 1.0 (web typical range)
  Future<void> setPitch(double pitch);   // 0.5 - 2.0
  Future<void> setLanguage(String language);
  Future<List<Map<String, String>>> voices(); // [{"name":..., "locale":...}]
  Future<void> setVoice(Map<String, String> voice);
  Future<void> speak(String text);
  Future<void> stop();
}

TtsService createTtsService() => getTtsService();
