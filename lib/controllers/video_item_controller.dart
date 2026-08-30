import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';
import '../core/app_database.dart';
import '../models/subtitle_line.dart';
import '../models/video_entry.dart';

/// Owns exactly one [Player] instance for one video item in the feed.
///
/// Lifecycle: created when a PageView item becomes active (or pre-buffered
/// as a neighbor), disposed when it scrolls far enough away. Encapsulates:
///  - media_kit playback
///  - shadowing (5s loop) logic
///  - SRT parsing + active-line lookup for up to two subtitle tracks
///  - playback speed / fast-forward rate state
///  - watch-progress persistence for Course Mode resume
class VideoItemController extends ChangeNotifier {
  final VideoEntry entry;

  late final Player player;
  late final VideoController videoController;

  /// Primary subtitle track (learning language). Kept as `subtitles` for
  /// backwards compatibility with existing overlay widgets.
  List<SubtitleLine> subtitles = [];
  SubtitleLine? activeSubtitle;

  /// Secondary subtitle track (native language), shown beneath the
  /// primary line when a second .srt file is present next to the video.
  List<SubtitleLine> secondarySubtitles = [];
  SubtitleLine? activeSecondarySubtitle;
  bool get hasDualSubtitles => secondarySubtitles.isNotEmpty;

  bool isShadowingActive = false;
  Duration? _shadowLoopStart;
  Duration? _shadowLoopEnd;

  double currentSpeed = 1.0;
  bool isFastForwarding = false;

  Duration position = Duration.zero;
  Duration duration = Duration.zero;
  bool isPlaying = false;

  bool isFavorite = false;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  StreamSubscription<bool>? _playingSub;
  Timer? _progressSaveTimer;

  bool _disposed = false;

  VideoItemController(this.entry) {
    player = Player();
    videoController = VideoController(player);
    _bindStreams();
    _loadSubtitlesIfPresent();
    _loadFavoriteState();
    _startProgressAutosave();
  }

  /// Opens the media file and starts playback. If prior watch progress
  /// exists for this video (Course Mode resume), seeks there first.
  Future<void> initializeAndPlay() async {
    await player.open(Media(entry.path), play: true);

    final saved = await AppDatabase.instance.getProgress(entry.path);
    if (saved != null && _disposed == false) {
      final savedPositionMs = saved['position_ms'] as int? ?? 0;
      final completed = (saved['completed'] as int? ?? 0) == 1;
      // Don't resume into the last few seconds of an already-completed
      // video — that would immediately re-trigger completion and feel
      // like the app "skipped" the video.
      if (!completed && savedPositionMs > 2000) {
        await player.seek(Duration(milliseconds: savedPositionMs));
      }
    }
  }

  void _bindStreams() {
    _positionSub = player.stream.position.listen((pos) {
      if (_disposed) return;
      position = pos;
      _handleShadowingTick(pos);
      _updateActiveSubtitle(pos);
      notifyListeners();
    });

    _durationSub = player.stream.duration.listen((d) {
      if (_disposed) return;
      duration = d;
      notifyListeners();
    });

    _playingSub = player.stream.playing.listen((playing) {
      if (_disposed) return;
      isPlaying = playing;
      notifyListeners();
    });
  }

  // ---------------------------------------------------------------------
  // Basic transport controls
  // ---------------------------------------------------------------------

  Future<void> togglePlayPause() async {
    await player.playOrPause();
  }

  Future<void> seekRelative(Duration delta) async {
    final target = position + delta;
    final clamped = target < Duration.zero
        ? Duration.zero
        : (target > duration ? duration : target);
    await player.seek(clamped);
  }

  Future<void> seekTo(Duration target) async {
    await player.seek(target);
  }

  // ---------------------------------------------------------------------
  // Long-press fast-forward (2.0x while held)
  // ---------------------------------------------------------------------

  Future<void> startFastForward() async {
    isFastForwarding = true;
    currentSpeed = 2.0;
    await player.setRate(2.0);
    notifyListeners();
  }

  Future<void> stopFastForward() async {
    isFastForwarding = false;
    currentSpeed = 1.0;
    await player.setRate(1.0);
    notifyListeners();
  }

  /// Cycles the persistent (non-long-press) playback speed: 1.0 -> 1.25 -> 1.5 -> 1.0
  Future<void> cycleSpeed() async {
    if (currentSpeed == 1.0) {
      currentSpeed = 1.25;
    } else if (currentSpeed == 1.25) {
      currentSpeed = 1.5;
    } else {
      currentSpeed = 1.0;
    }
    await player.setRate(currentSpeed);
    notifyListeners();
  }

  // ---------------------------------------------------------------------
  // Shadowing engine (5-second rolling loop)
  // ---------------------------------------------------------------------

  void toggleShadowing() {
    isShadowingActive = !isShadowingActive;
    if (isShadowingActive) {
      final start = position - const Duration(seconds: 5);
      _shadowLoopStart = start < Duration.zero ? Duration.zero : start;
      _shadowLoopEnd = position;
    } else {
      _shadowLoopStart = null;
      _shadowLoopEnd = null;
    }
    notifyListeners();
  }

  void _handleShadowingTick(Duration pos) {
    if (!isShadowingActive || _shadowLoopEnd == null || _shadowLoopStart == null) {
      return;
    }
    if (pos >= _shadowLoopEnd!) {
      // Fire-and-forget seek back to loop start; do not await inside the
      // stream listener to avoid backpressure on the position stream.
      player.seek(_shadowLoopStart!);
    }
  }

  // ---------------------------------------------------------------------
  // SRT subtitle loading + active line tracking
  // ---------------------------------------------------------------------

  Future<void> _loadSubtitlesIfPresent() async {
    final srtPaths = entry.findAllSubtitlePaths();
    if (srtPaths.isEmpty) return;

    try {
      final primaryFile = File(srtPaths.first);
      if (await primaryFile.exists()) {
        final raw = await primaryFile.readAsString();
        subtitles = SrtParser.parse(raw);
      }

      // If a second .srt file exists alongside the first (e.g.
      // video.en.srt + video.ar.srt), treat it as the native-language
      // track shown beneath the primary line.
      if (srtPaths.length > 1) {
        final secondaryFile = File(srtPaths[1]);
        if (await secondaryFile.exists()) {
          final raw = await secondaryFile.readAsString();
          secondarySubtitles = SrtParser.parse(raw);
        }
      }

      notifyListeners();
    } catch (_) {
      // Malformed or unreadable subtitle file — fail silently, video still plays.
      subtitles = [];
      secondarySubtitles = [];
    }
  }

  Future<void> _loadFavoriteState() async {
    isFavorite = await AppDatabase.instance.isFavorite(entry.path);
    notifyListeners();
  }

  Future<void> toggleFavorite() async {
    isFavorite = !isFavorite;
    notifyListeners();
    if (isFavorite) {
      await AppDatabase.instance.addFavorite(entry.path);
    } else {
      await AppDatabase.instance.removeFavorite(entry.path);
    }
  }

  /// Periodically persists playback position so Course Mode can resume
  /// exactly where the user left off, even after fully closing the app.
  /// Runs on a timer (rather than every position tick) to avoid hammering
  /// the database dozens of times per second.
  void _startProgressAutosave() {
    _progressSaveTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (_disposed || duration.inMilliseconds <= 0) return;
      AppDatabase.instance.saveProgress(
        videoPath: entry.path,
        positionMs: position.inMilliseconds,
        durationMs: duration.inMilliseconds,
      );
    });
  }

  /// Forces an immediate progress save — call this when leaving the video
  /// (e.g. on swipe) rather than waiting for the next timer tick, so
  /// resume position doesn't lag behind by up to 3 seconds.
  Future<void> saveProgressNow() async {
    if (duration.inMilliseconds <= 0) return;
    await AppDatabase.instance.saveProgress(
      videoPath: entry.path,
      positionMs: position.inMilliseconds,
      durationMs: duration.inMilliseconds,
    );
  }

  void _updateActiveSubtitle(Duration pos) {
    if (subtitles.isEmpty) {
      if (activeSubtitle != null) activeSubtitle = null;
    } else {
      // Linear scan is fine for typical subtitle track sizes (hundreds of
      // lines); could be replaced with binary search for very long tracks.
      SubtitleLine? match;
      for (final line in subtitles) {
        if (line.containsPosition(pos)) {
          match = line;
          break;
        }
      }
      if (match != activeSubtitle) {
        activeSubtitle = match;
      }
    }

    if (secondarySubtitles.isEmpty) {
      if (activeSecondarySubtitle != null) activeSecondarySubtitle = null;
      return;
    }
    SubtitleLine? secondaryMatch;
    for (final line in secondarySubtitles) {
      if (line.containsPosition(pos)) {
        secondaryMatch = line;
        break;
      }
    }
    if (secondaryMatch != activeSecondarySubtitle) {
      activeSecondarySubtitle = secondaryMatch;
    }
  }

  // ---------------------------------------------------------------------
  // Cleanup
  // ---------------------------------------------------------------------

  Future<void> disposeController() async {
    _disposed = true;
    await saveProgressNow();
    _progressSaveTimer?.cancel();
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    await _playingSub?.cancel();
    await player.dispose();
  }

  @override
  void dispose() {
    // Ensure resources are released even if disposeController() wasn't
    // explicitly awaited by the caller.
    if (!_disposed) {
      _disposed = true;
      _progressSaveTimer?.cancel();
      _positionSub?.cancel();
      _durationSub?.cancel();
      _playingSub?.cancel();
      player.dispose();
    }
    super.dispose();
  }
}
