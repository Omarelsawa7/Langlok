import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/video_entry.dart';

/// Handles persistence of the chosen study folder and recursive scanning
/// of that folder for supported video files.
class FileScanner {
  static const String _prefsKey = 'root_folder_path';

  static const List<String> supportedExtensions = [
    '.mkv',
    '.mp4',
    '.avi',
    '.webm',
    '.mov',
  ];

  /// Reads the previously saved root folder path, or null if never set.
  static Future<String?> loadSavedRootPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKey);
  }

  /// Persists the chosen root folder path so the user isn't asked again.
  static Future<void> saveRootPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, path);
  }

  static Future<void> clearSavedRootPath() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  /// Recursively scans [rootPath] for supported video files.
  ///
  /// Returns a list of [VideoEntry], sorted alphabetically by full path.
  /// Runs on the calling isolate; for very large libraries you may want
  /// to move this to `compute()` — the entry point is kept synchronous-ish
  /// via `listSync` per the spec, wrapped in a Future for UI responsiveness.
  static Future<List<VideoEntry>> scanFolder(String rootPath) async {
    final dir = Directory(rootPath);
    if (!await dir.exists()) {
      throw FileSystemException('Selected folder does not exist', rootPath);
    }

    final List<VideoEntry> found = [];

    late final List<FileSystemEntity> entities;
    try {
      entities = dir.listSync(recursive: true, followLinks: false);
    } on FileSystemException {
      // Some sub-directories may be inaccessible (permissions); fall back
      // to a best-effort manual walk that skips unreadable directories.
      entities = _safeRecursiveList(dir);
    }

    for (final entity in entities) {
      if (entity is! File) continue;
      final lowerPath = entity.path.toLowerCase();
      final matches = supportedExtensions.any((ext) => lowerPath.endsWith(ext));
      if (matches) {
        found.add(VideoEntry(entity.path));
      }
    }

    found.sort((a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
    return found;
  }

  /// Manual recursive walk that tolerates permission errors on individual
  /// subdirectories instead of aborting the entire scan.
  static List<FileSystemEntity> _safeRecursiveList(Directory dir) {
    final List<FileSystemEntity> results = [];
    List<FileSystemEntity> shallow;
    try {
      shallow = dir.listSync(recursive: false, followLinks: false);
    } catch (_) {
      return results;
    }

    for (final entity in shallow) {
      if (entity is Directory) {
        results.add(entity);
        results.addAll(_safeRecursiveList(entity));
      } else {
        results.add(entity);
      }
    }
    return results;
  }
}
