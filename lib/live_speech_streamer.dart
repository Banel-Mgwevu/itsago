import 'dart:async';
import 'dart:convert';
import 'package:record/record.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as ws_status;

/// Streams microphone audio live to the ITSAGO Cloud Run speech proxy and
/// reports transcripts back as they arrive. This is the single source of
/// mic audio during an answer - there is no separate on-device recognizer,
/// so there is no mic conflict.
///
/// Usage per answer:
///   final s = LiveSpeechStreamer(onTranscript: (text, isFinal) {...});
///   await s.start();     // begins streaming, live callbacks start firing
///   ...
///   final full = await s.stop();  // returns the final accumulated transcript
class LiveSpeechStreamer {
  LiveSpeechStreamer({required this.onTranscript, required this.wsUrl});

  /// Called every time new words arrive. [isFinal] marks a completed phrase.
  final void Function(String transcript, bool isFinal) onTranscript;

  /// wss:// URL of the Cloud Run proxy.
  final String wsUrl;

  final AudioRecorder _rec = AudioRecorder();
  WebSocketChannel? _channel;
  StreamSubscription? _audioSub;
  StreamSubscription? _socketSub;

  String _committed = '';   // finalized phrases joined
  String _interim = '';     // current in-progress phrase
  bool _running = false;

  static const int sampleRate = 16000;

  String get currentTranscript =>
      (_committed + ' ' + _interim).trim();

  Future<bool> start() async {
    if (_running) return true;
    try {
      if (!await _rec.hasPermission()) return false;

      // Open the WebSocket to the proxy.
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));

      _socketSub = _channel!.stream.listen(
        _onSocketMessage,
        onError: (_) {},
        onDone: () {},
        cancelOnError: false,
      );

      // Start streaming raw PCM16 audio from the mic.
      final audioStream = await _rec.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: 1,
        ),
      );

      _audioSub = audioStream.listen((chunk) {
        // Forward each audio chunk straight to the proxy as a binary frame.
        try {
          _channel?.sink.add(chunk);
        } catch (_) {}
      });

      _running = true;
      return true;
    } catch (_) {
      await _cleanup();
      return false;
    }
  }

  void _onSocketMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data['type'];
      if (type == 'transcript') {
        final text = (data['transcript'] as String?)?.trim() ?? '';
        final isFinal = data['isFinal'] == true;
        if (text.isEmpty) return;
        if (isFinal) {
          _committed = (_committed + ' ' + text).trim();
          _interim = '';
        } else {
          _interim = text;
        }
        onTranscript(currentTranscript, isFinal);
      }
    } catch (_) {
      // ignore non-transcript control frames (ready, error, etc.)
    }
  }

  /// Stop streaming and return the full final transcript.
  Future<String> stop() async {
    if (!_running) return currentTranscript;
    _running = false;
    try {
      // Tell the proxy the answer is done so Google flushes its final result.
      _channel?.sink.add(jsonEncode({'type': 'end'}));
    } catch (_) {}
    // Give the proxy a brief moment to send the last final transcript.
    await Future.delayed(const Duration(milliseconds: 600));
    final result = currentTranscript;
    await _cleanup();
    return result;
  }

  Future<void> _cleanup() async {
    try { await _audioSub?.cancel(); } catch (_) {}
    try { await _rec.stop(); } catch (_) {}
    try { await _socketSub?.cancel(); } catch (_) {}
    try { _channel?.sink.close(ws_status.normalClosure); } catch (_) {}
    _audioSub = null;
    _socketSub = null;
    _channel = null;
  }

  Future<void> cancel() async {
    _running = false;
    _committed = '';
    _interim = '';
    await _cleanup();
  }

  void dispose() {
    _rec.dispose();
  }
}
