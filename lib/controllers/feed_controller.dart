import 'package:flutter/foundation.dart';
import '../core/app_database.dart';
import '../models/video_entry.dart';
import 'video_item_controller.dart';

enum FeedMode { random, course }

/// Manages the list of videos for one feed (Random or Course), the current
/// page index, and the lifecycle of [VideoItemController]s.
///
/// Only the active index (and optionally one preloaded neighbor) holds a
/// live [Player]; everything else is disposed to keep memory/decoder
/// usage bounded, per the "release previous item's resources" requirement.
class FeedController extends ChangeNotifier {
  final FeedMode mode;
  List<VideoEntry> videos;

  int currentIndex = 0;

  /// Sparse map: only the current (and briefly, the previous) index has
  /// a live controller at any given time.
  final Map<int, VideoItemController> _activeControllers = {};

  FeedController({required this.mode, required this.videos});

  VideoItemController? controllerFor(int index) => _activeControllers[index];

  VideoItemController? get currentController => _activeControllers[currentIndex];

  void updateVideos(List<VideoEntry> newVideos) {
    videos = newVideos;
    if (currentIndex >= videos.length) {
      currentIndex = videos.isEmpty ? 0 : videos.length - 1;
    }
    notifyListeners();
  }

  /// Called when the PageView settles on a new page. Disposes the
  /// controller for the page we're leaving and creates+plays the one for
  /// the page we're entering.
  Future<void> onPageChanged(int newIndex) async {
    if (newIndex == currentIndex && _activeControllers.containsKey(newIndex)) {
      return;
    }

    final previousIndex = currentIndex;
    currentIndex = newIndex;

    // Pause immediately for responsiveness before teardown completes.
    final leaving = _activeControllers[previousIndex];
    if (leaving != null && previousIndex != newIndex) {
      await leaving.player.pause();
    }

    // Ensure the new index has a live controller.
    await _ensureController(newIndex);

    // Tear down the controller we left, now that the new one is playing.
    if (leaving != null && previousIndex != newIndex) {
      _activeControllers.remove(previousIndex);
      await leaving.disposeController();
      leaving.dispose();
    }

    // Course Mode persists its position so the app can resume exactly
    // where the user left off on next launch.
    if (mode == FeedMode.course) {
      await AppDatabase.instance.saveLastCourseIndex(newIndex);
    }

    notifyListeners();
  }

  /// Creates the initial controller for the first-shown page. For Course
  /// Mode, [preferSavedIndex] restores the last watched position instead
  /// of always starting at index 0.
  Future<void> initializeAt(int index, {bool preferSavedIndex = false}) async {
    int startIndex = index;

    if (preferSavedIndex && mode == FeedMode.course) {
      final saved = await AppDatabase.instance.getLastCourseIndex();
      if (saved != null && saved >= 0 && saved < videos.length) {
        startIndex = saved;
      }
    }

    currentIndex = startIndex;
    await _ensureController(startIndex);
    notifyListeners();
  }

  Future<void> _ensureController(int index) async {
    if (index < 0 || index >= videos.length) return;
    if (_activeControllers.containsKey(index)) return;

    final entry = videos[index];
    final controller = VideoItemController(entry);
    _activeControllers[index] = controller;
    await controller.initializeAndPlay();
  }

  /// Jump directly to an arbitrary index (used by Course Mode's episode
  /// selector). Treated the same as a swipe-driven page change.
  Future<void> jumpTo(int index) async {
    await onPageChanged(index);
  }

  Future<void> disposeAll() async {
    for (final controller in _activeControllers.values) {
      await controller.disposeController();
      controller.dispose();
    }
    _activeControllers.clear();
  }

  @override
  void dispose() {
    // Best-effort synchronous cleanup; disposeAll() should be awaited
    // explicitly by the owning widget's dispose() where possible.
    for (final controller in _activeControllers.values) {
      controller.disposeController();
      controller.dispose();
    }
    _activeControllers.clear();
    super.dispose();
  }
}
