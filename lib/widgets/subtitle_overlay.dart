import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_database.dart';
import '../controllers/video_item_controller.dart';
import '../models/subtitle_line.dart';

class SubtitleOverlay extends StatelessWidget {
  final VideoItemController controller;

  const SubtitleOverlay({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final SubtitleLine? active = controller.activeSubtitle;
    final SubtitleLine? secondary = controller.activeSecondarySubtitle;

    if ((active == null || active.text.trim().isEmpty) &&
        (secondary == null || secondary.text.trim().isEmpty)) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (active != null && active.text.trim().isNotEmpty)
            _buildInteractiveLine(context, active.text),
          // Secondary (native-language) line is shown as plain text below
          // the primary interactive line — it's a reading aid, not meant
          // for word-tap lookups since it's the user's own language.
          if (secondary != null && secondary.text.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              secondary.text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 13,
                fontStyle: FontStyle.italic,
                height: 1.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInteractiveLine(BuildContext context, String text) {
    final words = text.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 4,
      children: words.map((word) {
        return InkWell(
          borderRadius: BorderRadius.circular(4),
          onTap: () => _onWordTapped(context, word, text),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
            child: Text(
              word,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
                height: 1.3,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _onWordTapped(BuildContext context, String word, String sentence) {
    // Pause playback while inspecting the word.
    controller.player.pause();

    // Strip common trailing punctuation for a cleaner display/copy target.
    final cleaned = word.replaceAll(RegExp(r'^[¿¡"“”‘’(\[]+|[.,!?;:"“”‘’)\]]+$'), '');
    final displayWord = cleaned.isEmpty ? word : cleaned;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayWord,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  sentence,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white38, fontSize: 13),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: displayWord));
                          if (sheetContext.mounted) Navigator.of(sheetContext).pop();
                        },
                        icon: const Icon(Icons.copy, color: Colors.white70, size: 18),
                        label: const Text(
                          'Copy',
                          style: TextStyle(color: Colors.white70),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white24),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await AppDatabase.instance.saveWord(
                            word: displayWord,
                            sourceSentence: sentence,
                            videoPath: controller.entry.path,
                            videoTitle: controller.entry.displayTitle,
                          );
                          if (sheetContext.mounted) {
                            Navigator.of(sheetContext).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('"$displayWord" saved to vocabulary'),
                                duration: const Duration(seconds: 2),
                                backgroundColor: const Color(0xFF1C1C1E),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.bookmark_add, size: 18),
                        label: const Text('Save'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Close', style: TextStyle(color: Colors.white38)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
