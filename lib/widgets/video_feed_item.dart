import 'dart:async';
import 'package:flutter/material.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import '../controllers/library_controller.dart';
import '../controllers/video_item_controller.dart';
import 'right_action_column.dart';
import 'subtitle_overlay.dart';

/// One full-screen page in the vertical feed: video surface + all gesture
/// bindings + overlays (top bar handled by the parent screen, this widget
/// owns everything below that).
class VideoFeedItem extends StatefulWidget {
  final VideoItemController controller;

  const VideoFeedItem({super.key, required this.controller});

  @override
  State<VideoFeedItem> createState() => _VideoFeedItemState();
}

class _VideoFeedItemState extends State<VideoFeedItem> {
  bool _showPlayPauseBadge = false;
  IconData _playPauseIcon = Icons.play_arrow;
  Timer? _badgeTimer;

  bool _hasReportedCompletion = false;
  bool _lastKnownFavoriteState = false;

  @override
  void initState() {
    super.initState();
    _lastKnownFavoriteState = widget.controller.isFavorite;
    widget.controller.addListener(_onControllerChanged);
  }

  void _onControllerChanged() {
    final controller = widget.controller;

    // Detect completion (90%+ watched) once per item and refresh the
    // library's badge cache so Search/Course lists reflect it promptly,
    // without waiting for a full re-scan.
    if (!_hasReportedCompletion &&
        controller.duration.inMilliseconds > 0 &&
        controller.position.inMilliseconds >=
            controller.duration.inMilliseconds * 0.9) {
      _hasReportedCompletion = true;
      if (mounted) context.read<LibraryController>().refreshBadgeState();
    }

    // Refresh badges immediately when the user toggles favorite, rather
    // than waiting for the next scan/search open.
    if (controller.isFavorite != _lastKnownFavoriteState) {
      _lastKnownFavoriteState = controller.isFavorite;
      if (mounted) context.read<LibraryController>().refreshBadgeState();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _badgeTimer?.cancel();
    super.dispose();
  }

  void _handleSingleTap() {
    final controller = widget.controller;
    final willPlay = !controller.isPlaying;
    controller.togglePlayPause();

    setState(() {
      _playPauseIcon = willPlay ? Icons.play_arrow : Icons.pause;
      _showPlayPauseBadge = true;
    });

    _badgeTimer?.cancel();
    _badgeTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _showPlayPauseBadge = false);
    });
  }

  void _handleDoubleTap(TapDownDetails details, double width) {
    final dx = details.localPosition.dx;
    final leftZone = width * 0.30;
    final rightZoneStart = width * 0.70;

    if (dx <= leftZone) {
      widget.controller.seekRelative(const Duration(seconds: -10));
      _flashSeekBadge(forward: false);
    } else if (dx >= rightZoneStart) {
      widget.controller.seekRelative(const Duration(seconds: 10));
      _flashSeekBadge(forward: true);
    }
    // Middle 40% ignored for double tap (reserved for pure play/pause taps).
  }

  void _flashSeekBadge({required bool forward}) {
    // Reuses the same center badge slot with a directional icon.
    setState(() {
      _playPauseIcon = forward ? Icons.forward_10 : Icons.replay_10;
      _showPlayPauseBadge = true;
    });
    _badgeTimer?.cancel();
    _badgeTimer = Timer(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _showPlayPauseBadge = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final library = context.read<LibraryController>();

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _handleSingleTap,
              onDoubleTapDown: (details) => _handleDoubleTap(details, width),
              onDoubleTap: () {}, // Required to enable onDoubleTapDown detection.
              onLongPressStart: (_) => controller.startFastForward(),
              onLongPressEnd: (_) => controller.stopFastForward(),
              onLongPressCancel: () => controller.stopFastForward(),
              child: Container(
                color: Colors.black,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // --- Base video layer ---
                    Video(
                      controller: controller.videoController,
                      fit: BoxFit.contain,
                      controls: NoVideoControls,
                    ),

                    // --- Center play/pause/seek badge ---
                    if (_showPlayPauseBadge)
                      Center(
                        child: AnimatedOpacity(
                          opacity: _showPlayPauseBadge ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 150),
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: const BoxDecoration(
                              color: Colors.black45,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(_playPauseIcon, color: Colors.white, size: 52),
                          ),
                        ),
                      ),

                    // --- Top-center fast-forward badge ---
                    if (controller.isFastForwarding)
                      Positioned(
                        top: 90,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.black87,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              '2.0x Fast Forward ▶▶',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                      ),

                    // --- Right vertical action column ---
                    Positioned(
                      right: 10,
                      top: 0,
                      bottom: 0,
                      child: RightActionColumn(controller: controller, library: library),
                    ),

                    // --- Bottom overlay: title, subtitles, progress bar ---
                    Positioned(
                      left: 0,
                      right: 70,
                      bottom: 0,
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                controller.entry.displayTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  shadows: [Shadow(blurRadius: 4, color: Colors.black87)],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              SubtitleOverlay(controller: controller),
                              const SizedBox(height: 6),
                              _ProgressBar(controller: controller),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final VideoItemController controller;

  const _ProgressBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    final total = controller.duration.inMilliseconds;
    final current = controller.position.inMilliseconds.clamp(0, total == 0 ? 1 : total);

    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackHeight: 2.5,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
        activeTrackColor: Colors.white,
        inactiveTrackColor: Colors.white24,
        thumbColor: Colors.white,
      ),
      child: Slider(
        min: 0,
        max: total == 0 ? 1 : total.toDouble(),
        value: current.toDouble(),
        onChanged: total == 0
            ? null
            : (value) {
                controller.seekTo(Duration(milliseconds: value.round()));
              },
      ),
    );
  }
}
