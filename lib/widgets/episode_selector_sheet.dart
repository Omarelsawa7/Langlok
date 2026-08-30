import 'package:flutter/material.dart';
import '../models/video_entry.dart';

Future<int?> showEpisodeSelectorSheet({
  required BuildContext context,
  required List<VideoEntry> videos,
  required int currentIndex,
  Set<String> completedPaths = const {},
}) {
  return showModalBottomSheet<int>(
    context: context,
    backgroundColor: const Color(0xFF161616),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) {
          return Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  'Episodes',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: videos.length,
                  itemBuilder: (context, index) {
                    final entry = videos[index];
                    final isCurrent = index == currentIndex;
                    final isCompleted = completedPaths.contains(entry.path);
                    return ListTile(
                      leading: Icon(
                        isCurrent
                            ? Icons.play_circle_fill
                            : (isCompleted ? Icons.check_circle : Icons.play_circle_outline),
                        color: isCurrent
                            ? Colors.amberAccent
                            : (isCompleted ? Colors.greenAccent : Colors.white54),
                      ),
                      title: Text(
                        entry.displayTitle,
                        style: TextStyle(
                          color: isCurrent ? Colors.amberAccent : Colors.white,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.of(context).pop(index),
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    },
  );
}
