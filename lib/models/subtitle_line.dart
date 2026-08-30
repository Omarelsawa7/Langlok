/// A single parsed line/cue from an SRT file.
class SubtitleLine {
  final Duration start;
  final Duration end;
  final String text;

  const SubtitleLine({
    required this.start,
    required this.end,
    required this.text,
  });

  bool containsPosition(Duration position) {
    return position >= start && position <= end;
  }

  @override
  String toString() => '[$start -> $end] $text';
}

/// Parses raw .srt file content into a list of [SubtitleLine].
///
/// Handles the standard SRT block format:
/// ```
/// 1
/// 00:00:01,000 --> 00:00:04,000
/// Hello world
///
/// 2
/// 00:00:05,200 --> 00:00:07,800
/// Second line
/// ```
class SrtParser {
  static final RegExp _timeRangePattern = RegExp(
    r'(\d{2}):(\d{2}):(\d{2})[,.](\d{3})\s*-->\s*(\d{2}):(\d{2}):(\d{2})[,.](\d{3})',
  );

  static List<SubtitleLine> parse(String raw) {
    final List<SubtitleLine> result = [];

    // Normalize line endings and split into blocks separated by blank lines.
    final normalized = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final blocks = normalized.split(RegExp(r'\n\s*\n'));

    for (final block in blocks) {
      final lines = block.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.isEmpty) continue;

      // Find the timing line within this block (it may not always be line[1]
      // if the index line is missing/malformed).
      int timingLineIndex = -1;
      RegExpMatch? match;
      for (int i = 0; i < lines.length; i++) {
        final m = _timeRangePattern.firstMatch(lines[i]);
        if (m != null) {
          timingLineIndex = i;
          match = m;
          break;
        }
      }

      if (match == null || timingLineIndex == -1) continue;

      final start = Duration(
        hours: int.parse(match.group(1)!),
        minutes: int.parse(match.group(2)!),
        seconds: int.parse(match.group(3)!),
        milliseconds: int.parse(match.group(4)!),
      );
      final end = Duration(
        hours: int.parse(match.group(5)!),
        minutes: int.parse(match.group(6)!),
        seconds: int.parse(match.group(7)!),
        milliseconds: int.parse(match.group(8)!),
      );

      final textLines = lines.sublist(timingLineIndex + 1);
      // Strip basic HTML-ish tags (<i>, <b>, <font ...>) commonly found in SRT.
      final text = textLines
          .join('\n')
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .trim();

      if (text.isEmpty) continue;

      result.add(SubtitleLine(start: start, end: end, text: text));
    }

    // Ensure chronological order for binary/linear search during playback.
    result.sort((a, b) => a.start.compareTo(b.start));
    return result;
  }
}
