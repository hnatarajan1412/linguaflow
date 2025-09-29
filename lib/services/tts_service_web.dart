import 'dart:async';
import 'dart:html' as html;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:convert';


import 'tts_service.dart';

class WebTtsService implements TtsService {
  final html.SpeechSynthesis? _synth = html.window.speechSynthesis;
  html.SpeechSynthesisUtterance? _current;
  String _language = 'en-US';
  double _volume = 1.0; // 0..1
  double _rate = 1.0;   // 0.1..10 (but we keep ~0.8..1.2 typical)
  double _pitch = 1.0;  // 0..2
  html.SpeechSynthesisVoice? _voice;
  bool _voicesLoaded = false;
  bool _unlocked = false; // Workaround for some browsers that require a user gesture unlock

  // Avoid re-attaching event listeners repeatedly
  bool _voicesListenerAdded = false;

  // Prebuilt short WAV beep (generated on first use) and a single reusable audio element
  String? _beepDataUrl;
  html.AudioElement? _beeper;
  DateTime? _lastBeepAt;

  @override
  Future<void> init({String? language}) async {
    if (language != null) _language = language;
    await _ensureVoicesLoaded();
  }

  Future<void> _ensureVoicesLoaded() async {
    _tryLoadVoices();
    if (_voicesLoaded) return;

    final synth = _synth;
    if (synth == null) return;

    final completer = Completer<void>();
    void resolveOnce([_]) { if (!completer.isCompleted) completer.complete(); }

    // voiceschanged event + a timed fallback
    if (!_voicesListenerAdded) {
      _voicesListenerAdded = true;
      synth.addEventListener('voiceschanged', resolveOnce);
    }

    // Poll for up to ~2s because some engines populate slowly until a user gesture
    const int attempts = 10;
    for (var i = 0; i < attempts && !_voicesLoaded; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      _tryLoadVoices();
      if (_voicesLoaded) break;
    }

    // Fallback wait if still not loaded
    if (!_voicesLoaded) {
      await Future.any([
        Future.delayed(const Duration(milliseconds: 300)),
        completer.future,
      ]);
      _tryLoadVoices();
    }

    // ignore: avoid_print
    print('[TTS][web] voices loaded: ' + (_voicesLoaded ? 'yes' : 'no') +
        ' (count=' + ((_synth?.getVoices().length ?? 0)).toString() + ') ' +
        ' chosen=' + (_voice?.name ?? 'null') + ' lang=' + (_voice?.lang ?? _language));
  }

  void _tryLoadVoices() {
    final voices = _synth?.getVoices() ?? const <html.SpeechSynthesisVoice>[];
    _voicesLoaded = voices.isNotEmpty;
    if (_voicesLoaded && _voice == null) {
      // Try to pick a voice matching the language
      final lc = _language.toLowerCase().split('-').first;
      _voice = voices.firstWhere(
        (v) => (v.lang?.toLowerCase() ?? '').startsWith(lc),
        orElse: () => voices.first,
      );
    }
  }

  @override
  Future<void> setLanguage(String language) async {
    _language = language;
    _tryLoadVoices();
  }

  @override
  Future<void> setPitch(double pitch) async { _pitch = pitch; }

  @override
  Future<void> setRate(double rate) async { _rate = rate.clamp(0.1, 2.0); }

  @override
  Future<void> setVolume(double volume) async { _volume = volume.clamp(0.0, 1.0); }

  Future<void> _unlockIfNeeded() async {
    final synth = _synth;
    if (synth == null || _unlocked) return;

    try {
      // Attempt to resume in case the context is suspended
      synth.resume();

      // Speak a near-silent dot to unlock on iOS Safari and some Chromium builds
      final unlockUtt = html.SpeechSynthesisUtterance('.')
        ..lang = _voice?.lang ?? _language
        ..pitch = _pitch
        ..rate = _rate
        ..volume = 0.001; // effectively inaudible

      final c = Completer<void>();
      unlockUtt.addEventListener('end', (_) { if (!c.isCompleted) c.complete(); });
      unlockUtt.addEventListener('error', (_) { if (!c.isCompleted) c.complete(); });

      synth.speak(unlockUtt);
      await c.future.timeout(const Duration(milliseconds: 400), onTimeout: () {});
      _unlocked = true;

      // ignore: avoid_print
      print('[TTS][web] audio unlocked');
    } catch (e) {
      // ignore: avoid_print
      print('[TTS][web] unlock error: ' + e.toString());
    }
  }

  // Build a very short sine beep as WAV and return a data URI
  String _ensureBeepDataUrl() {
    if (_beepDataUrl != null) return _beepDataUrl!;

    const int sampleRate = 44100;
    const double durationSec = 0.12;
    const double freq = 880.0; // A5
    const double amplitude = 0.55; // 0..1 (louder to ensure audibility)

    final int sampleCount = (sampleRate * durationSec).round();
    final Int16List pcm = Int16List(sampleCount);

    for (int i = 0; i < sampleCount; i++) {
      final double t = i / sampleRate;
      // Simple linear fade-out to reduce click
      final double env = 1.0 - (i / sampleCount);
      final double s = math.sin(2 * math.pi * freq * t) * amplitude * env;
      pcm[i] = (s * 32767.0).clamp(-32768.0, 32767.0).round();
    }

    // WAV header
    final int numChannels = 1;
    final int bitsPerSample = 16;
    final int byteRate = sampleRate * numChannels * (bitsPerSample ~/ 8);
    final int blockAlign = numChannels * (bitsPerSample ~/ 8);
    final int dataSize = pcm.length * 2; // 16-bit
    final int fileSize = 36 + dataSize;

    final BytesBuilder bb = BytesBuilder();

    // RIFF header
    bb.add(ascii.encode('RIFF'));
    bb.add(_u32le(fileSize));
    bb.add(ascii.encode('WAVE'));

    // fmt chunk
    bb.add(ascii.encode('fmt '));
    bb.add(_u32le(16)); // PCM chunk size
    bb.add(_u16le(1)); // audio format PCM
    bb.add(_u16le(numChannels));
    bb.add(_u32le(sampleRate));
    bb.add(_u32le(byteRate));
    bb.add(_u16le(blockAlign));
    bb.add(_u16le(bitsPerSample));

    // data chunk
    bb.add(ascii.encode('data'));
    bb.add(_u32le(dataSize));

    // PCM data
    final ByteData pcmBytes = ByteData(dataSize);
    for (int i = 0; i < pcm.length; i++) {
      pcmBytes.setInt16(i * 2, pcm[i], Endian.little);
    }
    bb.add(pcmBytes.buffer.asUint8List());

    final String base64Wav = base64Encode(bb.takeBytes());
    _beepDataUrl = 'data:audio/wav;base64,' + base64Wav;
    return _beepDataUrl!;
  }

  List<int> _u16le(int v) {
    final b = ByteData(2);
    b.setUint16(0, v, Endian.little);
    return b.buffer.asUint8List();
  }

  List<int> _u32le(int v) {
    final b = ByteData(4);
    b.setUint32(0, v, Endian.little);
    return b.buffer.asUint8List();
  }

  // Minimal fallback beep using Web Audio API (avoids <audio> source support issues)
  void _beepFallback() {
    try {
      final now = DateTime.now();
      if (_lastBeepAt != null && now.difference(_lastBeepAt!).inMilliseconds < 300) {
        return; // rate limit
      }
      _lastBeepAt = now;

      // Only attempt if the browser reports support for WAV
      final testEl = html.AudioElement();
      final support = testEl.canPlayType('audio/wav');
      if (support.isEmpty) {
        // ignore: avoid_print
        print('[TTS][web] Skipping beep: audio/wav not supported');
        return;
      }

      final url = _ensureBeepDataUrl();
      _beeper ??= html.AudioElement()
        ..autoplay = false
        ..controls = false;
      _beeper!
        ..src = url
        ..volume = _volume;
      _beeper!.currentTime = 0;
      _beeper!.play().then((_) {
        // ignore: avoid_print
        print('[TTS][web] Beep fallback');
      }).catchError((e) {
        // ignore: avoid_print
        print('[TTS][web] Beep playback error: ' + e.toString());
      });
    } catch (e) {
      // ignore: avoid_print
      print('[TTS][web] Beep fallback failed: ' + e.toString());
    }
  }

  @override
  Future<void> speak(String text) async {
    final synth = _synth;
    if (synth == null) {
      // ignore: avoid_print
      print('[TTS][web] speechSynthesis not available');
      _beepFallback();
      return;
    }

    // Cancel immediately without awaiting to preserve user activation
    try { synth.cancel(); } catch (_) {}

    // Kick off voice loading and unlocking in the background; do not await
    // to keep this call within the same user gesture tick.
    // Intentionally ignore returned Futures.
    // ignore: unawaited_futures
    _ensureVoicesLoaded();
    // ignore: unawaited_futures
    _unlockIfNeeded();

    // Some engines require a resume right before speak
    try { synth.resume(); } catch (_) {}

    final utt = html.SpeechSynthesisUtterance(text)
      ..lang = _voice?.lang ?? _language
      ..pitch = _pitch
      ..rate = _rate
      ..volume = _volume;

    // Only assign a voice if we actually have one
    if (_voice != null) {
      try { utt.voice = _voice; } catch (_) {}
    }

    _current = utt;

    // Optional end/error logs to aid debugging
    utt.addEventListener('end', (_) {
      // ignore: avoid_print
      print('[TTS][web] end');
    });
    utt.addEventListener('error', (event) {
      // ignore: avoid_print
      print('[TTS][web] error: ' + event.type.toString());
      // If speaking fails (e.g., voices blocked / empty), emit a short beep so the user hears feedback
      _beepFallback();
    });

    try {
      synth.speak(utt);

      // If we know we have no voices yet, also play a soft beep as immediate feedback
      // This covers engines that silently drop the utterance without firing error events
      final count = _synth?.getVoices().length ?? 0;
      if (!_voicesLoaded || count == 0) {
        _beepFallback();
      }
    } catch (e) {
      // ignore: avoid_print
      print('[TTS][web] speak() threw: ' + e.toString());
      _beepFallback();
    }
  }

  @override
  Future<void> stop() async {
    final synth = _synth;
    if (synth != null && ((synth.speaking ?? false) || (synth.pending ?? false))) {
      synth.cancel();
    }
    _current = null;
  }

  @override
  Future<List<Map<String, String>>> voices() async {
    final v = _synth?.getVoices() ?? const <html.SpeechSynthesisVoice>[];
    return v
        .map((e) => {
              'name': e.name ?? '',
              'locale': e.lang ?? '',
            })
        .toList();
  }

  @override
  Future<void> setVoice(Map<String, String> voice) async {
    final name = voice['name'];
    final locale = voice['locale'];
    final voices = _synth?.getVoices() ?? const <html.SpeechSynthesisVoice>[];
    html.SpeechSynthesisVoice? chosen;
    if (name != null && name.isNotEmpty) {
      chosen = voices.firstWhere((v) => v.name == name, orElse: () => voices.first);
    } else if (locale != null && locale.isNotEmpty) {
      chosen = voices.firstWhere(
        (v) => (v.lang ?? '').toLowerCase() == locale.toLowerCase(),
        orElse: () => voices.first,
      );
    }
    _voice = chosen ?? (voices.isNotEmpty ? voices.first : null);
    if (locale != null && locale.isNotEmpty) {
      _language = locale;
    }
  }
}

TtsService getTtsService() => WebTtsService();
