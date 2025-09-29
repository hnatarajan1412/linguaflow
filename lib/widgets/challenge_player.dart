import 'package:flutter/material.dart';
import 'package:linguaflow/models/challenge.dart';
import 'package:linguaflow/services/firebase_service.dart';
import 'package:linguaflow/services/tts_service.dart';

class ChallengePlayerController {
  _ChallengePlayerState? _state;
  void _bind(_ChallengePlayerState s) { _state = s; }

  // Returns true if the current input is correct.
  bool checkAnswer() => _state?._checkCurrentAnswer() ?? false;

  // Clears all user input and status.
  void reset() => _state?._resetState();
}

class ChallengePlayer extends StatefulWidget {
  final Challenge challenge;
  final FirebaseService firebaseService;
  final void Function(bool isCorrect) onAnswered;
  final ChallengePlayerController? controller;

  const ChallengePlayer({
    super.key,
    required this.challenge,
    required this.firebaseService,
    required this.onAnswered,
    this.controller,
  });

  @override
  State<ChallengePlayer> createState() => _ChallengePlayerState();
}

class _ChallengePlayerState extends State<ChallengePlayer> {
  late Challenge _challenge;
  bool _loading = true;
  String? _statusMsg;

  // State for different patterns
  int? _singleSelectedIdx;
  final Set<int> _multiSelected = {};
  final List<int> _wordOrder = []; // indexes into options list
  int? _selectedLeft; // displayOrder key for matching
  final Set<int> _matchedPairs = {}; // store displayOrder keys that are matched
  final TextEditingController _textController = TextEditingController();

  // Text-to-Speech via platform-aware service (web uses SpeechSynthesis)
  final TtsService _tts = createTtsService();
  bool _speaking = false;
  bool _ttsReady = false;

  @override
  void initState() {
    super.initState();
    _challenge = widget.challenge;
    widget.controller?._bind(this);
    _initTts();
    _ensureOptions();
  }

  @override
  void didUpdateWidget(covariant ChallengePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.challenge.id != widget.challenge.id) {
      _challenge = widget.challenge;
      _resetState();
      _ensureOptions();
    }
    if (oldWidget.controller != widget.controller) {
      widget.controller?._bind(this);
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _tts.stop();
    super.dispose();
  }

  Future<void> _initTts() async {
    // Heuristic: choose Spanish voice if the prompt/options look Spanish, otherwise English.
    String guessLocale = _guessLocaleFromChallenge() ?? 'en-US';
    try {
      await _tts.init(language: guessLocale);
      // Configure baseline params
      await _tts.setVolume(1.0);
      await _tts.setRate(0.9); // web typical range ~0.8-1.2, mobile maps to speechRate
      await _tts.setPitch(1.0);

      // Try to pick a concrete voice matching the locale (especially important on web)
      final voices = await _tts.voices();
      if (voices.isNotEmpty) {
        Map<String, String>? match;
        for (final m in voices) {
          final loc = (m['locale'] ?? '').toString();
          if (loc.toLowerCase().startsWith(guessLocale.split('-').first.toLowerCase())) {
            match ??= m;
            if (loc.toLowerCase() == guessLocale.toLowerCase()) { match = m; break; }
          }
        }
        if (match != null) {
          await _tts.setVoice({'name': match['name'] ?? 'default', 'locale': match['locale'] ?? guessLocale});
          final loc = match['locale'];
          if (loc != null && loc.isNotEmpty) {
            await _tts.setLanguage(loc);
          }
        } else {
          await _tts.setLanguage(guessLocale);
        }
      } else {
        await _tts.setLanguage(guessLocale);
      }

      // ignore: avoid_print
      print('[TTS] Initialized with locale: ' + guessLocale);
      setState(() { _ttsReady = true; });
    } catch (e) {
      // ignore: avoid_print
      print('[TTS] Init error: ' + e.toString());
      setState(() { _ttsReady = true; }); // allow attempts anyway
    }
  }

  String? _guessLocaleFromChallenge() {
    final t = (widget.challenge.promptText ?? '') +
        ' ' + widget.challenge.options.map((o) => o.contentText ?? '').join(' ');
    final s = t.toLowerCase();
    // Very light heuristic for Spanish vs English
    const spanishHints = ['hola', 'gracias', 'adiós', 'buenos', 'días', 'hasta', 'luego', 'yo', 'soy'];
    for (final h in spanishHints) {
      if (s.contains(h)) return 'es-ES';
    }
    return null; // default handled by caller
  }

  Future<void> _ensureOptions() async {
    setState(() => _loading = true);
    try {
      if (_challenge.options.isEmpty) {
        final opts = await widget.firebaseService.getOptionsForChallenge(_challenge.id);
        opts.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
        setState(() {
          _challenge = _challenge.copyWith(options: opts);
        });
      }
    } catch (e) {
      setState(() { _statusMsg = 'Failed to load options: $e'; });
    } finally {
      setState(() => _loading = false);
    }
  }

  void _resetState() {
    setState(() {
      _loading = false;
      _statusMsg = null;
      _singleSelectedIdx = null;
      _multiSelected.clear();
      _wordOrder.clear();
      _selectedLeft = null;
      _matchedPairs.clear();
      _textController.clear();
    });
  }

  String _normalize(String s) {
    return s
        .toLowerCase()
        .replaceAll(RegExp(r"[\p{P}\p{S}]", unicode: true), '')
        .replaceAll(RegExp(r"\s+"), ' ')
        .trim();
  }

  Future<void> _speak(String text) async {
    if (text.trim().isEmpty) return;
    try {
      // Do not await anything here to preserve the browser's user activation for web TTS
      if (!_ttsReady) {
        // Kick off init in background; do not await
        // ignore: unawaited_futures
        _initTts();
      }
      setState(() { _speaking = true; });
      // ignore: avoid_print
      print('[TTS] speak: ' + text);
      try { _tts.stop(); } catch (_) {}
      // Fire speak without await so it runs in the same gesture tick
      // ignore: unawaited_futures
      _tts.speak(text);
    } catch (e) {
      // ignore: avoid_print
      print('[TTS] speak error: ' + e.toString());
    } finally {
      // Reset the speaking indicator after a short delay
      Future.delayed(const Duration(milliseconds: 900), () {
        if (mounted) setState(() { _speaking = false; });
      });
    }
  }

  String? _extractTtsPayload(String? source, {String? fallback}) {
    if (source == null) return null;
    final s = source.trim();
    if (s.toLowerCase().startsWith('tts:')) {
      return s.substring(4).trim().isNotEmpty ? s.substring(4).trim() : fallback;
    }
    // If not tts: prefix, but we have no URL player, we can still try to TTS the fallback or source
    // Prefer using fallback (e.g., promptText) to avoid URLs
    return fallback ?? s;
  }

  void _answer(bool correct, {String? msg}) {
    setState(() { _statusMsg = msg; });
    widget.onAnswered(correct);
  }

  bool _checkCurrentAnswer() {
    if (_loading) return false;
    final pattern = _challenge.interactionPattern;
    switch (pattern) {
      case 'multiple_choice': {
        if (_singleSelectedIdx == null) return false;
        final ok = _challenge.options[_singleSelectedIdx!].isCorrect;
        _answer(ok, msg: ok ? 'Correct!' : 'Try again');
        return ok;
      }
      case 'multiple_choice_multi': {
        if (_multiSelected.isEmpty) return false;
        final correctIdx = <int>[];
        for (var i = 0; i < _challenge.options.length; i++) {
          if (_challenge.options[i].isCorrect) correctIdx.add(i);
        }
        final ok = Set.of(correctIdx).containsAll(_multiSelected) && Set.of(_multiSelected).containsAll(correctIdx);
        _answer(ok, msg: ok ? 'Correct!' : 'Not quite, check your selection');
        return ok;
      }
      case 'word_bank_order':
      case 'audio_tokens': {
        final opts = _challenge.options;
        final expected = <String>[];
        for (final o in opts.where((o) => o.isCorrect).toList()..sort((a,b)=>a.displayOrder.compareTo(b.displayOrder))) {
          expected.add(_normalize(o.contentText ?? ''));
        }
        final chosen = _wordOrder.map((i) => _normalize(opts[i].contentText ?? '')).toList();
        final ok = chosen.length == expected.length && List.generate(expected.length, (i) => expected[i] == chosen[i]).every((e) => e);
        _answer(ok, msg: ok ? 'Great!' : 'Order is not correct yet');
        return ok;
      }
      case 'pair_matching': {
        final leftCount = _challenge.options.where((o) => o.itemType == 'pair_left').length;
        final ok = _matchedPairs.length == leftCount;
        _answer(ok, msg: ok ? 'All pairs matched!' : 'Finish matching the pairs');
        return ok;
      }
      case 'free_text':
      case 'audio_free_text': {
        final input = _normalize(_textController.text);
        if (input.isEmpty) return false;
        final correctAnswers = _challenge.options.where((o) => o.isCorrect).map((o) => _normalize(o.contentText ?? '')).toSet();
        final ok = correctAnswers.contains(input);
        _answer(ok, msg: ok ? 'Correct!' : 'Not quite');
        return ok;
      }
      default: {
        return false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_challenge.interactionPattern) {
      case 'multiple_choice':
        return _buildMultipleChoice(single: true);
      case 'multiple_choice_multi':
        return _buildMultipleChoice(single: false);
      case 'word_bank_order':
        return _buildWordBankOrder();
      case 'pair_matching':
        return _buildPairMatching();
      case 'free_text':
      case 'audio_free_text':
        return _buildFreeText();
      case 'audio_tokens':
        return _buildWordBankOrder();
      default:
        return _buildMultipleChoice(single: true);
    }
  }

  Widget _buildHeader() {
    final promptText = widget.challenge.promptText;
    final promptImage = widget.challenge.promptImage;
    final promptAudio = _extractTtsPayload(widget.challenge.promptAudio, fallback: promptText);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (promptImage != null) ...[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              promptImage,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stack) {
                return Container(
                  height: 160,
                  width: double.infinity,
                  color: Colors.grey.withValues(alpha: 0.2),
                  alignment: Alignment.center,
                  child: const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.image_not_supported, color: Colors.grey, size: 40),
                      SizedBox(height: 8),
                      Text('Image unavailable', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (promptText != null)
          Text(promptText, style: Theme.of(context).textTheme.titleLarge),
        if (promptAudio != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: () => _speak(promptAudio),
                icon: Icon(_speaking ? Icons.volume_off : Icons.volume_up),
                label: const Text('Play'),
              ),
            ],
          ),
        ],
        if (_statusMsg != null) ...[
          const SizedBox(height: 8),
          Text(_statusMsg!, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ],
    );
  }

  Widget _buildMultipleChoice({required bool single}) {
    final options = _challenge.options;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 12),
        Expanded(
          child: ListView.builder(
            itemCount: options.length,
            itemBuilder: (context, index) {
              final opt = options[index];
              final selected = single ? _singleSelectedIdx == index : _multiSelected.contains(index);
              final audioPayload = _extractTtsPayload(opt.contentAudio, fallback: opt.contentText);

              return Card(
                child: ListTile(
                  leading: single
                      ? Radio<int>(
                          value: index,
                          groupValue: _singleSelectedIdx,
                          onChanged: (v) {
                            setState(() { _singleSelectedIdx = v; });
                          },
                        )
                      : Checkbox(
                          value: selected,
                          onChanged: (v) {
                            setState(() {
                              if (v == true) { _multiSelected.add(index); } else { _multiSelected.remove(index); }
                            });
                          },
                        ),
                  title: Text(opt.contentText ?? '[Option]'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (opt.contentImage != null) ...[
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            opt.contentImage!,
                            height: 120,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stack) {
                              return Container(
                                height: 120,
                                width: double.infinity,
                                color: Colors.grey.withValues(alpha: 0.2),
                                alignment: Alignment.center,
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.broken_image, color: Colors.grey),
                                    SizedBox(width: 8),
                                    Text('Image failed to load', style: TextStyle(color: Colors.grey)),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      if (audioPayload != null) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => _speak(audioPayload),
                            icon: const Icon(Icons.volume_up),
                            label: const Text('Play'),
                          ),
                        ),
                      ],
                    ],
                  ),
                  onTap: () {
                    setState(() {
                      if (single) {
                        _singleSelectedIdx = index;
                      } else {
                        if (selected) { _multiSelected.remove(index); } else { _multiSelected.add(index); }
                      }
                    });
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWordBankOrder() {
    final options = _challenge.options;
    final tokens = List.generate(options.length, (i) => i);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _wordOrder.map((i) {
            final opt = options[i];
            return Chip(
              label: Text(opt.contentText ?? ''),
              backgroundColor: Colors.blue.withValues(alpha: 0.15),
              onDeleted: () {
                setState(() { _wordOrder.remove(i); });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tokens.where((i) => !_wordOrder.contains(i)).map((i) {
            final opt = options[i];
            return ChoiceChip(
              label: Text(opt.contentText ?? ''),
              selected: false,
              onSelected: (_) {
                setState(() { _wordOrder.add(i); });
              },
            );
          }).toList(),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildPairMatching() {
    // Left items: itemType == 'pair_left'; Right items: itemType == 'pair_right'
    final left = _challenge.options.where((o) => o.itemType == 'pair_left').toList();
    final right = _challenge.options.where((o) => o.itemType == 'pair_right').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 12),
        Expanded(
          child: Row(
            children: [
              Expanded(child: _buildMatchColumn(left, isLeft: true)),
              const SizedBox(width: 12),
              Expanded(child: _buildMatchColumn(right, isLeft: false)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMatchColumn(List<ChallengeOption> items, {required bool isLeft}) {
    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final key = item.displayOrder; // serve as pair key
        final matched = _matchedPairs.contains(key);
        final selected = _selectedLeft == key && isLeft;
        return GestureDetector(
          onTap: matched
              ? null
              : () {
                  setState(() {
                    if (isLeft) {
                      _selectedLeft = key;
                    } else {
                      // selecting a right item: check if left is selected and matches
                      if (_selectedLeft != null) {
                        if (_selectedLeft == key) {
                          _matchedPairs.add(key);
                          _selectedLeft = null;
                          // Do not automatically complete; waiting for external check
                        } else {
                          _answer(false, msg: 'That does not match. Try again.');
                        }
                      }
                    }
                  });
                },
          child: Card(
            color: matched
                ? Colors.green.withValues(alpha: 0.15)
                : selected
                    ? Colors.blue.withValues(alpha: 0.15)
                    : null,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(item.contentText ?? ''),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFreeText() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 12),
        TextField(
          controller: _textController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Type your answer',
          ),
          minLines: 1,
          maxLines: 3,
        ),
        const Spacer(),
      ],
    );
  }
}
