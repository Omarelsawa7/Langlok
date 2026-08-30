import 'dart:io';
import 'package:path/path.dart' as p;

/// Represents a single playable video discovered on disk, along with
/// a lazily-resolved path to its matching subtitle file (if any).
class VideoEntry {
  final String path;
  final String fileName;

  VideoEntry(this.path) : fileName = p.basename(path);

  /// Cleaned title for display: strips extension and underscores/dashes.
  String get displayTitle {
    final withoutExt = p.basenameWithoutExtension(path);
    return withoutExt
        .replaceAll(RegExp(r'[_\-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Looks for a subtitle file next to the video.
  /// Checks, in order:
  ///   1. same_name.srt
  ///   2. same_name.<lang>.srt  (any language code, e.g. video.de.srt)
  /// Returns null if none found.
  String? findSubtitlePath() {
    final dir = p.dirname(path);
    final base = p.basenameWithoutExtension(path);

    final exactMatch = p.join(dir, '$base.srt');
    if (File(exactMatch).existsSync()) return exactMatch;

    try {
      final dirEntity = Directory(dir);
      if (!dirEntity.existsSync()) return null;

      final candidatePrefix = '$base.';
      for (final entity in dirEntity.listSync()) {
        if (entity is! File) continue;
        final entityName = p.basename(entity.path);
        if (entityName.startsWith(candidatePrefix) &&
            entityName.toLowerCase().endsWith('.srt')) {
          return entity.path;
        }
      }
    } catch (_) {
      // Directory listing can fail on permission-restricted paths; ignore.
    }
    return null;
  }

  /// Returns every subtitle file found next to the video (e.g.
  /// video.en.srt AND video.ar.srt for a dual-language setup), sorted
  /// alphabetically by filename so results are stable across scans.
  ///
  /// Used to support showing two subtitle tracks at once (learning
  /// language + native language) when both are present.
  List<String> findAllSubtitlePaths() {
    final dir = p.dirname(path);
    final base = p.basenameWithoutExtension(path);
    final results = <String>[];

    final exactMatch = p.join(dir, '$base.srt');
    if (File(exactMatch).existsSync()) results.add(exactMatch);

    try {
      final dirEntity = Directory(dir);
      if (!dirEntity.existsSync()) return results;

      final candidatePrefix = '$base.';
      for (final entity in dirEntity.listSync()) {
        if (entity is! File) continue;
        final entityName = p.basename(entity.path);
        if (entityName.startsWith(candidatePrefix) &&
            entityName.toLowerCase().endsWith('.srt') &&
            !results.contains(entity.path)) {
          results.add(entity.path);
        }
      }
    } catch (_) {
      // Ignore unreadable directories.
    }

    results.sort();
    return results;
  }

  @override
  bool operator ==(Object other) => other is VideoEntry && other.path == path;

  @override
  int get hashCode => path.hashCode;
}
