import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';

/// Shared spoken-feedback layer.
///
/// Any part of the app (task executor, notifications, home screen) can call
/// [SpeechFeedback.speak] without owning a TTS engine of its own, so a finished
/// or failed task is always announced out loud — even when the phone is on the
/// table and the screen is inside another app.
///
/// Settings it reads from SharedPreferences:
///   voice_feedback_enabled : bool   (default true)
///   voice_language         : String (e.g. 'en-US', 'hi-IN')
///   voice_rate             : double (default 0.55)
/// Phone ki bhasha: Hindi phone par Hindi, warna system default.
String _deviceLanguage() {
  try {
    final tag = Platform.localeName.replaceAll('_', '-');
    return tag.isEmpty ? 'en-US' : tag;
  } catch (_) {
    return 'en-US';
  }
}

class SpeechFeedback {
  SpeechFeedback._();
  static final SpeechFeedback instance = SpeechFeedback._();

  FlutterTts? _tts;
  bool _ready = false;
  bool _enabled = true;

  Future<void> _ensureReady() async {
    if (_ready) return;
    final prefs = await SharedPreferences.getInstance();
    _enabled = prefs.getBool('voice_feedback_enabled') ?? true;
    if (!_enabled) {
      _ready = true;
      return;
    }
    final tts = FlutterTts();
    final rate =
        (prefs.getDouble('voice_rate') ?? 0.55).clamp(0.1, 1.0).toDouble();
    final lang = prefs.getString('voice_language') ?? _deviceLanguage();
    try {
      await tts.setVolume(1.0);
      await tts.setPitch(1.0);
      await tts.setSpeechRate(rate);
      if (lang != null && lang.isNotEmpty) {
        await tts.setLanguage(lang);
      }
      // Queue announcements instead of cutting the previous one off.
      await tts.setQueueMode(1);
    } catch (_) {
      // Older TTS engines may not support every option; ignore.
    }
    _tts = tts;
    _ready = true;
  }

  /// Speak [text] out loud. Never throws.
  Future<void> speak(String text) async {
    final cleaned = text.trim();
    if (cleaned.isEmpty) return;
    try {
      await _ensureReady();
      if (!_enabled) return;
      await _tts?.speak(cleaned);
    } catch (_) {
      // Speech is a nicety, never a failure path.
    }
  }

  /// Announce a task result as "<title>. <body>", trimmed to stay short.
  Future<void> announce(String title, String body) async {
    final short = body.length > 140 ? '${body.substring(0, 140)}...' : body;
    await speak('$title. $short');
  }

  Future<void> stop() async {
    try {
      await _tts?.stop();
    } catch (_) {}
  }

  /// Call after the user changes voice settings.
  void reset() {
    _ready = false;
    _tts = null;
  }
}

class VoiceService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final FlutterTts _tts = FlutterTts();
  bool _isInitialized = false;
  bool _isListening = false;

  bool get isListening => _isListening;

  Future<void> init() async {
    if (_isInitialized) return;

    _isInitialized = await _speech.initialize(
      onError: (error) {
        _isListening = false;
      },
    );

    // Configure TTS — full volume, user-tunable language and rate.
    final prefs = await SharedPreferences.getInstance();
    final rate =
        (prefs.getDouble('voice_rate') ?? 0.5).clamp(0.1, 1.0).toDouble();
    final lang = prefs.getString('voice_language') ?? _deviceLanguage();
    try {
      await _tts.setLanguage(lang);
      await _tts.setSpeechRate(rate);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      await _tts.setQueueMode(1);
    } catch (_) {
      // Ignore engines that reject a setting.
    }
  }

  /// Start listening for speech. Returns transcribed text via callback.
  Future<void> startListening({
    required Function(String) onResult,
    required Function() onDone,
  }) async {
    if (!_isInitialized) await init();
    if (!_isInitialized) return;

    _isListening = true;

    await _speech.listen(
      onResult: (SpeechRecognitionResult result) {
        if (result.finalResult) {
          _isListening = false;
          onResult(result.recognizedWords);
          onDone();
        }
      },
      listenOptions: stt.SpeechListenOptions(
        listenMode: stt.ListenMode.confirmation,
        partialResults: false,
      ),
    );
  }

  /// Stop listening
  Future<void> stopListening() async {
    _isListening = false;
    await _speech.stop();
  }

  /// Speak text aloud
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    if (!_isInitialized) await init();
    await _tts.speak(text);
  }

  /// Stop speaking
  Future<void> stopSpeaking() async {
    await _tts.stop();
  }

  void dispose() {
    _speech.stop();
    _tts.stop();
  }
}
