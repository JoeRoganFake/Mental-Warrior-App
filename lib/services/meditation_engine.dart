import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';

import 'package:mental_warior/services/tts_service.dart';

/// Phases of a guided meditation session.
enum MeditationPhase { opening, awareness, deep, closing }

/// Describes one phase's playback plan.
class _PhasePlan {
  final MeditationPhase phase;
  final List<String> sentences;
  final double pauseSeconds;

  _PhasePlan({
    required this.phase,
    required this.sentences,
    required this.pauseSeconds,
  });
}

/// Orchestrates a guided meditation session:
///  - Loads sentences from assets
///  - Splits duration into 4 timed phases (opening 10%, awareness 40%, deep 40%, closing 10%)
///  - Plays TTS audio for each sentence with calculated pauses
///  - Supports stop and pause/resume
class MeditationEngine {
  final AudioPlayer _player = AudioPlayer();
  final TTSService _ttsService = TTSService();
  final Random _random = Random();

  Map<String, List<String>>? _sentences;
  bool _isStopped = false;
  bool _isPaused = false;
  Completer<void>? _pauseCompleter;

  /// Exposes the current phase for UI display if needed.
  MeditationPhase? currentPhase;

  /// Whether the engine is currently running a session.
  bool get isRunning => !_isStopped && _sentences != null;

  /// Whether playback is paused.
  bool get isPaused => _isPaused;

  // ---------------------------------------------------------------------------
  // Sentence loading
  // ---------------------------------------------------------------------------

  Future<void> _loadSentences() async {
    if (_sentences != null) return;

    final jsonString = await rootBundle
        .loadString('assets/meditation_sentences/sentences.json');
    final Map<String, dynamic> data = json.decode(jsonString);

    _sentences = {
      'opening': List<String>.from(data['opening']),
      'awareness': List<String>.from(data['awareness']),
      'deep': List<String>.from(data['deep']),
      'closing': List<String>.from(data['closing']),
    };
  }

  // ---------------------------------------------------------------------------
  // Playlist building
  // ---------------------------------------------------------------------------

  /// Builds a list of [_PhasePlan]s for the given total [duration].
  ///
  /// Phase time splits: opening 10 %, awareness 40 %, deep 40 %, closing 10 %.
  /// Sentences are shuffled, de-duplicated across phases, and pauses are
  /// clamped to 5–60 s.
  List<_PhasePlan> _buildPlaylist(Duration duration) {
    final totalSeconds = duration.inSeconds.toDouble();

    // Phase durations (seconds).
    final phaseDurations = {
      MeditationPhase.opening: totalSeconds * 0.10,
      MeditationPhase.awareness: totalSeconds * 0.40,
      MeditationPhase.deep: totalSeconds * 0.40,
      MeditationPhase.closing: totalSeconds * 0.10,
    };

    // Map phase enum → JSON key.
    const phaseKeys = {
      MeditationPhase.opening: 'opening',
      MeditationPhase.awareness: 'awareness',
      MeditationPhase.deep: 'deep',
      MeditationPhase.closing: 'closing',
    };

    final usedSentences = <String>{};
    final plans = <_PhasePlan>[];

    for (final phase in MeditationPhase.values) {
      final phaseSeconds = phaseDurations[phase]!;
      final key = phaseKeys[phase]!;

      // Copy & shuffle available sentences, excluding already-used ones.
      final available = List<String>.from(_sentences![key]!)
        ..removeWhere((s) => usedSentences.contains(s))
        ..shuffle(_random);

      if (available.isEmpty) continue;

      // Estimate ~8 s average spoken duration per sentence.
      const estimatedSpokenDuration = 8.0;

      // How many sentences can we fit?
      // Each sentence occupies: spoken_duration + pause.
      // Start with a target pause of ~15 s and iterate:
      int count = max(1, (phaseSeconds / (estimatedSpokenDuration + 15)).floor());
      count = min(count, available.length);

      // Calculate actual pause to fill the phase evenly.
      // total = count * spoken + (count) * pause  (pause after each, last pause fills remaining)
      double pause = (phaseSeconds - count * estimatedSpokenDuration) / count;
      pause = pause.clamp(5.0, 60.0);

      // If clamping changed the pause, recalculate count to avoid overrun.
      if (pause == 5.0) {
        // Very dense — many sentences, short pauses.
        count = min(
          available.length,
          max(1, (phaseSeconds / (estimatedSpokenDuration + 5)).floor()),
        );
        pause = 5.0;
      } else if (pause == 60.0) {
        // Very sparse — few sentences, long pauses.
        count = min(
          available.length,
          max(1, (phaseSeconds / (estimatedSpokenDuration + 60)).floor()),
        );
        pause = 60.0;
      }

      final selected = available.take(count).toList();
      usedSentences.addAll(selected);

      plans.add(_PhasePlan(
        phase: phase,
        sentences: selected,
        pauseSeconds: pause,
      ));
    }

    return plans;
  }

  // ---------------------------------------------------------------------------
  // Playback
  // ---------------------------------------------------------------------------

  /// Starts a guided meditation for the given [duration].
  ///
  /// Returns when the session finishes naturally or is stopped via
  /// [stopMeditation].
  Future<void> startMeditation(Duration duration) async {
    _isStopped = false;
    _isPaused = false;
    _pauseCompleter = null;

    // Configure audio session for speech (higher priority than background music)
    try {
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration.speech());
    } catch (e) {
      print('⚠️ Could not configure audio session: $e');
    }

    await _loadSentences();
    final plans = _buildPlaylist(duration);

    _logSession(plans, duration);

    for (final plan in plans) {
      if (_isStopped) break;

      currentPhase = plan.phase;
      print('🧘 Phase: ${plan.phase.name} — '
          '${plan.sentences.length} sentences, '
          '${plan.pauseSeconds.toStringAsFixed(1)}s pause');

      for (int i = 0; i < plan.sentences.length; i++) {
        if (_isStopped) break;

        final sentence = plan.sentences[i];

        try {
          // Wait if paused.
          await _waitIfPaused();
          if (_isStopped) break;

          // Generate / fetch cached audio.
          final audioFile = await _ttsService.getOrCreateAudio(sentence);
          if (_isStopped) break;

          // Play the sentence.
          await _player.setFilePath(audioFile.path);
          _player.play(); // fire — we await completion below.

          // Wait for playback to finish (or stop/pause).
          await _awaitPlaybackComplete();
          if (_isStopped) break;

          // Inter-sentence pause (skip after the very last sentence of closing).
          final isLastSentence =
              plan.phase == MeditationPhase.closing &&
              i == plan.sentences.length - 1;

          if (!isLastSentence) {
            await _cancellableDelay(
              Duration(milliseconds: (plan.pauseSeconds * 1000).round()),
            );
          }
        } catch (e) {
          // Log and skip this sentence — don't crash the session.
          print('⚠️ MeditationEngine error on sentence "$sentence": $e');
        }
      }
    }

    currentPhase = null;
    print('🧘 Meditation session ${_isStopped ? "stopped" : "completed"}.');
  }

  /// Stops the session and halts audio immediately.
  Future<void> stopMeditation() async {
    _isStopped = true;

    // Release any pause gate so loops can exit.
    if (_pauseCompleter != null && !_pauseCompleter!.isCompleted) {
      _pauseCompleter!.complete();
    }

    try {
      await _player.stop();
    } catch (_) {}
  }

  /// Pauses the current playback and the inter-sentence delay.
  Future<void> pauseMeditation() async {
    if (_isPaused) return;
    _isPaused = true;
    _pauseCompleter = Completer<void>();

    try {
      await _player.pause();
    } catch (_) {}
  }

  /// Resumes playback after a pause.
  Future<void> resumeMeditation() async {
    if (!_isPaused) return;
    _isPaused = false;

    // Release the pause gate.
    if (_pauseCompleter != null && !_pauseCompleter!.isCompleted) {
      _pauseCompleter!.complete();
    }

    try {
      await _player.play();
    } catch (_) {}
  }

  /// Releases native resources. Call when the widget is disposed.
  void dispose() {
    _isStopped = true;
    if (_pauseCompleter != null && !_pauseCompleter!.isCompleted) {
      _pauseCompleter!.complete();
    }
    _player.dispose();
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Blocks while [_isPaused] is true. Resolves immediately when resumed or
  /// stopped.
  Future<void> _waitIfPaused() async {
    while (_isPaused && !_isStopped) {
      _pauseCompleter ??= Completer<void>();
      await _pauseCompleter!.future;
      // After resume, reset completer for next potential pause.
      if (!_isPaused) _pauseCompleter = null;
    }
  }

  /// Waits for the audio player to reach [ProcessingState.completed].
  /// Also respects pause and stop.
  Future<void> _awaitPlaybackComplete() async {
    final completer = Completer<void>();

    late StreamSubscription<PlayerState> sub;
    sub = _player.playerStateStream.listen((state) {
      if (_isStopped) {
        if (!completer.isCompleted) completer.complete();
        sub.cancel();
        return;
      }
      if (state.processingState == ProcessingState.completed) {
        if (!completer.isCompleted) completer.complete();
        sub.cancel();
      }
    });

    await completer.future;
  }

  /// A delay that can be interrupted by [stopMeditation] or frozen by
  /// [pauseMeditation]. Checks every 500 ms.
  Future<void> _cancellableDelay(Duration total) async {
    final deadline = DateTime.now().add(total);

    while (DateTime.now().isBefore(deadline)) {
      if (_isStopped) return;

      // If paused, wait until resumed (time keeps ticking by design –
      // the meditation timer also keeps running while paused is handled
      // at the countdown-screen level).
      await _waitIfPaused();
      if (_isStopped) return;

      // Sleep in small chunks so we stay responsive.
      final remaining = deadline.difference(DateTime.now());
      if (remaining.isNegative) break;

      await Future.delayed(
        Duration(milliseconds: min(500, remaining.inMilliseconds)),
      );
    }
  }

  /// Prints a summary of the planned session for debugging.
  void _logSession(List<_PhasePlan> plans, Duration duration) {
    print('\n${'=' * 50}');
    print('🧘 GUIDED MEDITATION SESSION');
    print('   Total duration: ${duration.inMinutes} min');
    for (final p in plans) {
      print('   ${p.phase.name.toUpperCase()}: '
          '${p.sentences.length} sentences, '
          '${p.pauseSeconds.toStringAsFixed(1)}s pause');
    }
    print('${'=' * 50}\n');
  }
}
