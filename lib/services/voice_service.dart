import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:permission_handler/permission_handler.dart';
import '../models/request_model.dart';

class VoiceService extends ChangeNotifier {
  final FlutterTts _flutterTts = FlutterTts();
  final SpeechToText _speechToText = SpeechToText();

  bool _isSpeaking = false;
  bool _isListening = false;
  String _lastRecognizedWords = '';
  Completer<String?>? _commandCompleter;

  bool get isSpeaking => _isSpeaking;
  bool get isListening => _isListening;
  String get lastRecognizedWords => _lastRecognizedWords;

  VoiceService() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    // Handler needed for Android/iOS variations
    _flutterTts.setStartHandler(() {
      _isSpeaking = true;
      notifyListeners();
    });

    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
      notifyListeners();
    });

    _flutterTts.setErrorHandler((msg) {
      _isSpeaking = false;
      notifyListeners();
    });
  }

  /// Speak the request details
  Future<void> speakRequest(RequestModel request) async {
    // Ensure accurate speaking
    await _stop();

    final text =
        'New ${request.requestType} request from ${request.creatorName ?? "a member"}. '
        'Title: ${request.title}. '
        'Importance: ${request.getImportanceDisplayName()}. '
        'Say "Approve" to accept, "Reject" to deny, or "Stop" to cancel.';

    await _flutterTts.speak(text);
  }

  /// Stop speaking & listening
  Future<void> stop() async {
    await _stop();
  }

  Future<void> _stop() async {
    await _flutterTts.stop();
    await _speechToText.stop();
    _isSpeaking = false;
    _isListening = false;
    notifyListeners();
  }

  /// Listen for a specific command ("approve", "reject", "okay", "yes")
  /// Returns 'approved', 'rejected', or null if no command recognized
  Future<String?> listenForCommand() async {
    // 1. Request microphone permission explicitly first
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      debugPrint('Microphone permission denied');
      return null;
    }

    // 2. Initialize text-to-speech if not already
    bool avail = await _speechToText.initialize(
      onError: (e) => debugPrint('STT Error: $e'),
      onStatus: (s) => debugPrint('STT Status: $s'),
    );

    if (!avail) {
      debugPrint('Speech recognition not available on device');
      return null;
    }

    // 3. Reset state
    _isListening = true;
    _lastRecognizedWords = '';
    notifyListeners();

    _commandCompleter = Completer<String?>();

    // 4. Start listening
    await _speechToText.listen(
      onResult: (result) {
        _lastRecognizedWords = result.recognizedWords;
        // Notify UI of partial results
        notifyListeners();

        final words = result.recognizedWords.toLowerCase();

        // Check for specific commands
        if (words.contains('approve') ||
            words.contains('yes') ||
            words.contains('okay') ||
            words.contains('accept')) {
          _completeListening('approved');
        } else if (words.contains('reject') ||
            words.contains('deny') ||
            words.contains('no')) {
          _completeListening('rejected');
        } else if (words.contains('stop') || words.contains('cancel')) {
          _completeListening(null);
        }
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      localeId: "en_US",
      partialResults: true,
      cancelOnError: true,
      listenMode: ListenMode.confirmation,
    );

    // 5. Wait for completer or timeout
    return _commandCompleter!.future.timeout(
      const Duration(seconds: 12),
      onTimeout: () {
        _stop();
        return null;
      },
    );
  }

  void _completeListening(String? result) {
    if (_commandCompleter != null && !_commandCompleter!.isCompleted) {
      _commandCompleter!.complete(result);
      _stop(); // Stop listening once we have a result
    }
  }
}
