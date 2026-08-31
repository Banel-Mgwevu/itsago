import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'cloud_function_service.dart';

/// Records a single interview answer to a temp WAV file and transcribes it
/// via the transcribeAudio Cloud Function. Runs in parallel with the live
/// on-device recognizer, which keeps driving the live UI visuals. This
/// recorder exists only to produce an accurate final transcript.
class AnswerRecorder {
  final AudioRecorder _rec = AudioRecorder();
  String? _path;
  bool _recording = false;
  StreamSubscription<Amplitude>? _ampSub;

  static const int sampleRate = 16000;

  /// Begin recording the current answer. Safe to call even if permission
  /// is missing - it just no-ops so the interview continues normally.
  /// [onAmplitude] receives the current mic level in dBFS (~-45 silence,
  /// ~-20 speaking) every 300ms, so the UI can show live speaking state.
  Future<void> start({void Function(double dbfs)? onAmplitude}) async {
    try {
      if (!await _rec.hasPermission()) {
        print('ðŸŽ™ï¸ AnswerRecorder: no mic permission');
        return;
      }
      final dir = await getTemporaryDirectory();
      _path = '${dir.path}/answer_${DateTime.now().millisecondsSinceEpoch}.wav';
      await _rec.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: sampleRate,
          numChannels: 1,
        ),
        path: _path!,
      );
      _recording = true;
      print('ðŸŽ™ï¸ AnswerRecorder: recording started -> $_path');
      if (onAmplitude != null) {
        _ampSub = _rec
            .onAmplitudeChanged(const Duration(milliseconds: 300))
            .listen((a) {
          // Live mic level: silence is around -160 to -45 dBFS,
          // normal speech is around -30 to -10 dBFS.
          print('\u{1F399}\u{FE0F} mic level: ${a.current.toStringAsFixed(1)} dBFS');
          onAmplitude(a.current);
        });
      }
    } catch (e) {
      print('ðŸŽ™ï¸ AnswerRecorder: start failed: $e');
      _recording = false;
    }
  }

  /// Stop recording and return the transcript from the cloud. Returns an
  /// empty string on any failure (no permission, network down, etc.) so
  /// the caller falls back to the on-device transcript.
  Future<String> stopAndTranscribe() async {
    _ampSub?.cancel();
    _ampSub = null;
    if (!_recording) return '';
    _recording = false;
    try {
      final savedPath = await _rec.stop();
      print('\u{1F399}\u{FE0F} AnswerRecorder: stopped, transcribing in cloud...');
      final path = savedPath ?? _path;
      if (path == null) return '';
      final file = File(path);
      if (!await file.exists()) return '';

      final bytes = await file.readAsBytes();
      print('\u{1F399}\u{FE0F} AnswerRecorder: WAV file is ${bytes.length} bytes '
          '(~${(bytes.length / 32000).toStringAsFixed(1)}s of audio)');

      // Decisive diagnostic: scan the recorded PCM for its loudest sample.
      // A silent mic writes a full-size file of zeros, so file size alone
      // proves nothing - this does.
      int peak = 0;
      for (int i = 44; i + 1 < bytes.length; i += 2) {
        int sample = bytes[i] | (bytes[i + 1] << 8);
        if (sample > 32767) sample -= 65536; // little-endian signed 16-bit
        final abs = sample < 0 ? -sample : sample;
        if (abs > peak) peak = abs;
      }
      final peakPct = (peak / 32768 * 100).toStringAsFixed(1);
      print('\u{1F399}\u{FE0F} AnswerRecorder: peak sample $peak / 32768 ($peakPct% of full scale)');
      if (peak < 500) {
        print('\u{1F399}\u{FE0F} \u26A0\uFE0F AUDIO IS SILENT - the microphone fed the recorder '
            'no sound. Something else is holding the mic.');
      } else {
        print('\u{1F399}\u{FE0F} \u2705 Audio contains real sound - if the transcript is still '
            'empty, the problem is in the cloud/API side.');
      }
      if (bytes.length < 32000) {
        // Under ~1 second of 16kHz mono audio - the recorder captured
        // essentially nothing, so don't waste a cloud call.
        print('\u{1F399}\u{FE0F} AnswerRecorder: recording too small - mic captured no audio');
        try { await file.delete(); } catch (_) {}
        return '';
      }
      // Send the COMPLETE WAV file and let the Speech API read the RIFF
      // header itself. Manually stripping "44 bytes" is fragile - if the
      // recorder writes a longer header, every sample shifts and the API
      // hears noise, returning an empty transcript.
      final audioBase64 = base64Encode(bytes);

      // Clean up the temp file - we don't keep answer audio.
      try { await file.delete(); } catch (_) {}

      if (audioBase64.isEmpty) return '';

      final transcript = await CloudFunctionService.transcribeAudio(
        audioBase64: audioBase64,
        sampleRate: sampleRate,
        encoding: 'WAV',
      );
      print('\u{1F399}\u{FE0F} AnswerRecorder: cloud transcript: "$transcript"');
      return transcript;
    } catch (e) {
      print('\u{1F399}\u{FE0F} AnswerRecorder: transcription failed: $e');
      return '';
    }
  }

  /// Cancel any in-progress recording without transcribing (e.g. on dispose).
  Future<void> cancel() async {
    _ampSub?.cancel();
    _ampSub = null;
    if (!_recording) return;
    _recording = false;
    try {
      await _rec.stop();
      if (_path != null) {
        final f = File(_path!);
        if (await f.exists()) await f.delete();
      }
    } catch (_) {}
  }

  void dispose() {
    _rec.dispose();
  }
}
