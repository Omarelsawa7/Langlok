import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/app_database.dart';
import '../core/file_scanner.dart';
import '../models/video_entry.dart';

enum LibraryStatus { uninitialized, loading, needsFolder, ready, error }

/// Owns the master video library: folder selection, permission handling,
/// scanning, and the two ordering modes (alphabetical / shuffled).
class LibraryController extends ChangeNotifier {
  LibraryStatus status = LibraryStatus.uninitialized;
  String? rootFolderPath;
  String? errorMessage;

  List<VideoEntry> allVideosList = [];
  List<VideoEntry> shuffledVideosList = [];

  String searchQuery = '';
  Set<String> favoritePaths = {};
  Set<String> completedPaths = {};

  /// Videos matching the current search query (by display title),
  /// case-insensitive. Empty query returns the full alphabetical list.
  List<VideoEntry> get searchResults {
    if (searchQuery.trim().isEmpty) return allVideosList;
    final lowerQuery = searchQuery.toLowerCase();
    return allVideosList
        .where((v) => v.displayTitle.toLowerCase().contains(lowerQuery))
        .toList();
  }

  List<VideoEntry> get favoriteVideos =>
      allVideosList.where((v) => favoritePaths.contains(v.path)).toList();

  void updateSearchQuery(String query) {
    searchQuery = query;
    notifyListeners();
  }

  /// Attempts to restore a previously saved folder on app launch.
  /// If none exists, transitions to [LibraryStatus.needsFolder].
  Future<void> initialize() async {
    status = LibraryStatus.loading;
    notifyListeners();

    final savedPath = await FileScanner.loadSavedRootPath();
    if (savedPath == null || !(await Directory(savedPath).exists())) {
      status = LibraryStatus.needsFolder;
      notifyListeners();
      return;
    }

    rootFolderPath = savedPath;
    await _scanAndPopulate(savedPath);
  }

  /// Requests storage permission (Android) then opens the native
  /// directory picker. On success, scans and persists the folder.
  Future<void> pickStudyFolder() async {
    // Android 11+ requires MANAGE_EXTERNAL_STORAGE-equivalent access for
    // arbitrary folder scanning; request the broad storage permission here.
    // On iOS / desktop this is effectively a no-op / always granted.
    if (Platform.isAndroid) {
      final storageStatus = await Permission.storage.request();
      final manageStatus = await Permission.manageExternalStorage.request();
      if (storageStatus.isDenied && manageStatus.isDenied) {
        status = LibraryStatus.error;
        errorMessage = 'Storage permission is required to read your video folder.';
        notifyListeners();
        return;
      }
    }

    final selectedPath = await FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Select your study folder',
    );

    if (selectedPath == null) {
      // User cancelled the picker; leave status as-is.
      return;
    }

    rootFolderPath = selectedPath;
    await FileScanner.saveRootPath(selectedPath);
    await _scanAndPopulate(selectedPath);
  }

  /// Re-scans the currently selected folder (e.g. "Re-scan" button after
  /// the user adds new files).
  Future<void> rescan() async {
    if (rootFolderPath == null) return;
    await _scanAndPopulate(rootFolderPath!);
  }

  /// Clears the saved folder and returns to the setup screen.
  Future<void> switchFolder() async {
    await FileScanner.clearSavedRootPath();
    rootFolderPath = null;
    allVideosList = [];
    shuffledVideosList = [];
    status = LibraryStatus.needsFolder;
    notifyListeners();
  }

  Future<void> _scanAndPopulate(String path) async {
    status = LibraryStatus.loading;
    notifyListeners();

    try {
      final videos = await FileScanner.scanFolder(path);
      allVideosList = videos;
      shuffledVideosList = List.from(videos)..shuffle();

      favoritePaths = await AppDatabase.instance.getAllFavoritePaths();
      completedPaths = await AppDatabase.instance.getCompletedVideoPaths();

      if (videos.isEmpty) {
        status = LibraryStatus.error;
        errorMessage =
            'No video files (.mkv, .mp4, .avi, .webm, .mov) found in this folder.';
      } else {
        status = LibraryStatus.ready;
        errorMessage = null;
      }
    } catch (e) {
      status = LibraryStatus.error;
      errorMessage = 'Failed to scan folder: $e';
    }
    notifyListeners();
  }

  /// Refreshes favorite/completed badges without a full re-scan — call
  /// this after toggling a favorite or finishing a video so the library
  /// and search screens reflect the change immediately.
  Future<void> refreshBadgeState() async {
    favoritePaths = await AppDatabase.instance.getAllFavoritePaths();
    completedPaths = await AppDatabase.instance.getCompletedVideoPaths();
    notifyListeners();
  }

  /// Re-shuffles Random Mode's list (e.g. pull-to-refresh in that tab).
  void reshuffle() {
    shuffledVideosList = List.from(allVideosList)..shuffle();
    notifyListeners();
  }
}
