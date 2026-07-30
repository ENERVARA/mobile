import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import 'chat_provider.dart';

/// Mic capture + speech-to-text. Ported from `useVoiceRecorder.ts` — records
/// via the platform mic, then uploads the clip to our backend (which proxies
/// ElevenLabs Scribe) and hands the transcript back for the caller to drop
/// into the chat input for review before sending. Never calls ElevenLabs
/// directly — the API key stays server-side.
enum RecorderStatus { idle, requesting, recording, transcribing, error }

/// Number of bars in the live waveform.
const int kVoiceWaveformBars = 24;

class VoiceState {
  final RecorderStatus status;
  final Duration elapsed;
  final List<double> levels;
  final String? error;

  /// Set once per completed transcription; the composer consumes it via
  /// `ref.listen` then calls [VoiceController.consumeTranscript].
  final String? transcript;

  const VoiceState({
    this.status = RecorderStatus.idle,
    this.elapsed = Duration.zero,
    this.levels = const [],
    this.error,
    this.transcript,
  });

  bool get isActive =>
      status == RecorderStatus.requesting ||
      status == RecorderStatus.recording ||
      status == RecorderStatus.transcribing;

  VoiceState copyWith({
    RecorderStatus? status,
    Duration? elapsed,
    List<double>? levels,
    String? error,
    bool clearError = false,
    String? transcript,
    bool clearTranscript = false,
  }) {
    return VoiceState(
      status: status ?? this.status,
      elapsed: elapsed ?? this.elapsed,
      levels: levels ?? this.levels,
      error: clearError ? null : (error ?? this.error),
      transcript: clearTranscript ? null : (transcript ?? this.transcript),
    );
  }
}

final voiceProvider = StateNotifierProvider<VoiceController, VoiceState>((ref) {
  final controller = VoiceController(ref);
  ref.onDispose(controller._teardown);
  return controller;
});

class VoiceController extends StateNotifier<VoiceState> {
  VoiceController(this._ref)
    : super(VoiceState(levels: List.filled(kVoiceWaveformBars, 0)));

  final Ref _ref;
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _ampSub;
  Timer? _timer;
  DateTime? _startedAt;
  String? _path;

  static const _maxDuration = Duration(seconds: 60);
  static const _recordConfig = RecordConfig(
    encoder: AudioEncoder.aacLc,
    bitRate: 128000,
    sampleRate: 44100,
    numChannels: 1,
    autoGain: true,
    echoCancel: true,
    noiseSuppress: true,
  );

  Future<void> start() async {
    if (state.status == RecorderStatus.recording ||
        state.status == RecorderStatus.requesting) {
      return;
    }
    state = VoiceState(
      status: RecorderStatus.requesting,
      levels: List.filled(kVoiceWaveformBars, 0),
    );

    try {
      final granted = await _recorder.hasPermission();
      if (!granted) {
        state = state.copyWith(
          status: RecorderStatus.error,
          error: 'Microphone access was blocked. Allow it in Settings.',
        );
        return;
      }

      final dir = await getTemporaryDirectory();
      _path =
          '${dir.path}/nova-voice-${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(_recordConfig, path: _path!);

      _startedAt = DateTime.now();
      state = state.copyWith(
        status: RecorderStatus.recording,
        elapsed: Duration.zero,
        clearError: true,
      );

      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        final elapsed = DateTime.now().difference(_startedAt!);
        if (elapsed >= _maxDuration) {
          // Auto-stop at the cap — still transcribes what was captured.
          stop();
          return;
        }
        state = state.copyWith(elapsed: elapsed);
      });

      _ampSub = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 120))
          .listen((amp) {
            // dBFS is roughly -60 (near-silence) .. 0 (peak) for speech — map that
            // range to a lively 0..1 for the waveform.
            final level = ((amp.current + 60) / 60).clamp(0.0, 1.0);
            state = state.copyWith(levels: [...state.levels.skip(1), level]);
          });
    } catch (_) {
      _teardown();
      state = state.copyWith(
        status: RecorderStatus.error,
        error: 'Could not start recording on this device.',
      );
    }
  }

  /// Stop + transcribe → [VoiceState.transcript].
  Future<void> stop() async {
    if (state.status != RecorderStatus.recording) return;
    _stopTicking();

    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}

    if (path == null || path.isEmpty) {
      state = VoiceState(levels: List.filled(kVoiceWaveformBars, 0));
      return;
    }

    state = state.copyWith(
      status: RecorderStatus.transcribing,
      clearError: true,
    );
    try {
      final text = await _ref.read(chatServiceProvider).transcribe(path);
      state = VoiceState(
        status: RecorderStatus.idle,
        levels: List.filled(kVoiceWaveformBars, 0),
        transcript: text.isNotEmpty ? text : null,
      );
    } catch (_) {
      // The api client's error interceptor already toasts the server
      // message — keep local state clean, matching the dashboard's hook.
      state = VoiceState(levels: List.filled(kVoiceWaveformBars, 0));
    } finally {
      try {
        await File(path).delete();
      } catch (_) {}
    }
  }

  /// Stop + discard (no transcription).
  Future<void> cancel() async {
    _stopTicking();
    try {
      await _recorder.cancel();
    } catch (_) {}
    state = VoiceState(levels: List.filled(kVoiceWaveformBars, 0));
  }

  /// Called by the composer after it has read+applied [VoiceState.transcript].
  void consumeTranscript() {
    if (state.transcript != null) state = state.copyWith(clearTranscript: true);
  }

  void _stopTicking() {
    _timer?.cancel();
    _timer = null;
    _ampSub?.cancel();
    _ampSub = null;
  }

  void _teardown() {
    _stopTicking();
    _recorder.dispose();
  }
}
