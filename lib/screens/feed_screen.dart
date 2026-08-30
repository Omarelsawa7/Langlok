import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/feed_controller.dart';
import '../controllers/library_controller.dart';
import '../controllers/theme_controller.dart';
import '../widgets/episode_selector_sheet.dart';
import '../widgets/mode_top_bar.dart';
import '../widgets/video_feed_item.dart';
import 'search_screen.dart';
import 'vocab_bank_screen.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  bool _isCourseMode = false;

  late FeedController _randomFeed;
  late FeedController _courseFeed;
  late PageController _randomPageController;
  PageController? _coursePageController;

  bool _initialized = false;
  bool _courseFeedReady = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final library = context.read<LibraryController>();

    _randomFeed = FeedController(mode: FeedMode.random, videos: library.shuffledVideosList);
    _courseFeed = FeedController(mode: FeedMode.course, videos: library.allVideosList);

    _randomPageController = PageController();

    _initializeFeeds();
  }

  Future<void> _initializeFeeds() async {
    await _randomFeed.initializeAt(0);

    // Course Mode resumes from the last watched video, if any was saved
    // in a previous session. The PageController is constructed only after
    // the resume index is known, using initialPage — this avoids the
    // "flash of index 0 then jump" that jumpToPage() causes after first
    // frame, and is safer than jumping before the view has laid out.
    await _courseFeed.initializeAt(0, preferSavedIndex: true);

    if (!mounted) return;
    setState(() {
      _coursePageController = PageController(initialPage: _courseFeed.currentIndex);
      _courseFeedReady = true;
    });
  }

  @override
  void dispose() {
    _randomFeed.disposeAll();
    _courseFeed.disposeAll();
    _randomPageController.dispose();
    _coursePageController?.dispose();
    super.dispose();
  }

  FeedController get _activeFeed => _isCourseMode ? _courseFeed : _randomFeed;

  Future<void> _openEpisodeSelector() async {
    if (_coursePageController == null) return;
    final library = context.read<LibraryController>();
    final selected = await showEpisodeSelectorSheet(
      context: context,
      videos: _courseFeed.videos,
      currentIndex: _courseFeed.currentIndex,
      completedPaths: library.completedPaths,
    );
    if (selected != null && mounted) {
      _coursePageController!.jumpToPage(selected);
      await _courseFeed.jumpTo(selected);
    }
  }

  Future<void> _openSearch() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          onVideoSelected: (entry, indexInAllVideos) async {
            // Search results are always positions within allVideosList, so
            // jumping to one only makes sense in Course Mode (which shares
            // that ordering) — switch modes if the user was in Random Mode.
            Navigator.of(context).pop();
            if (_coursePageController == null || indexInAllVideos < 0) return;

            setState(() => _isCourseMode = true);
            _coursePageController!.jumpToPage(indexInAllVideos);
            await _courseFeed.jumpTo(indexInAllVideos);
          },
        ),
      ),
    );
  }

  void _openVocabBank() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const VocabBankScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeController = context.watch<ThemeController>();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Both feeds are kept in the widget tree (via IndexedStack-like
          // visibility) so switching modes doesn't destroy playback state
          // of the inactive feed; only the active feed's page is "live".
          Offstage(
            offstage: _isCourseMode,
            child: _FeedPageView(
              feedController: _randomFeed,
              pageController: _randomPageController,
            ),
          ),
          if (_courseFeedReady)
            Offstage(
              offstage: !_isCourseMode,
              child: _FeedPageView(
                feedController: _courseFeed,
                pageController: _coursePageController!,
              ),
            )
          else if (_isCourseMode)
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // Top bar overlays both feeds.
          ModeTopBar(
            isCourseMode: _isCourseMode,
            onModeChanged: (courseMode) {
              setState(() => _isCourseMode = courseMode);
            },
            onEpisodeListTap: _openEpisodeSelector,
            onSearchTap: _openSearch,
            onVocabBankTap: _openVocabBank,
            onThemeToggleTap: () => themeController.toggleDarkMode(),
            isDarkMode: themeController.isDarkMode,
          ),
        ],
      ),
    );
  }
}

class _FeedPageView extends StatelessWidget {
  final FeedController feedController;
  final PageController pageController;

  const _FeedPageView({required this.feedController, required this.pageController});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: feedController,
      builder: (context, _) {
        if (feedController.videos.isEmpty) {
          return const Center(
            child: Text('No videos found.', style: TextStyle(color: Colors.white70)),
          );
        }

        return PageView.builder(
          controller: pageController,
          scrollDirection: Axis.vertical,
          itemCount: feedController.videos.length,
          onPageChanged: (index) => feedController.onPageChanged(index),
          itemBuilder: (context, index) {
            final itemController = feedController.controllerFor(index);
            if (itemController == null) {
              // Neighbor not yet initialized (e.g. fast fling); show a
              // lightweight placeholder instead of blocking the gesture.
              return const ColoredBox(color: Colors.black);
            }
            return VideoFeedItem(controller: itemController);
          },
        );
      },
    );
  }
}
