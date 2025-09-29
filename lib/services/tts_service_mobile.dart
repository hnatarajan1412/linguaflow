import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';

import 'tts_service.dart';

class MobileTtsService implements TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _inited = false;

  @override
  Future<void> init({String? language}) async {
    if (_inited) return;
    if (language != null) {
      await _tts.setLanguage(language);
    }
    _inited = true;
  }

  @override
  Future<void> setLanguage(String language) => _tts.setLanguage(language);

  @override
  Future<void> setPitch(double pitch) => _tts.setPitch(pitch);

  @override
  Future<void> setRate(double rate) => _tts.setSpeechRate(rate);

  @override
  Future<void> setVolume(double volume) => _tts.setVolume(volume);

  @override
  Future<void> speak(String text) async {
    await _tts.stop();
    await _tts.speak(text);
  }

  @override
  Future<void> stop() => _tts.stop();

  @override
  Future<List<Map<String, String>>> voices() async {
    final v = await _tts.getVoices;
    if (v is List) {
      return v.map<Map<String, String>>((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return {
          'name': (m['name'] ?? '').toString(),
          'locale': (m['locale'] ?? '').toString(),
        };
      }).toList();
    }
    return <Map<String, String>>[];
  }

  @override
  Future<void> setVoice(Map<String, String> voice) async {
    await _tts.setVoice(voice);
    final locale = voice['locale'];
    if (locale != null && locale.isNotEmpty) {
      await _tts.setLanguage(locale);
    }
  }
}

TtsService getTtsService() => MobileTtsService();
