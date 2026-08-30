import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/library_controller.dart';
import '../models/video_entry.dart';

class SearchScreen extends StatefulWidget {
  /// Called when the user taps a result; the caller (feed screen) decides
  /// how to jump to that video (usually via Course Mode's jumpTo).
  final void Function(VideoEntry entry, int indexInAllVideos) onVideoSelected;

  const SearchScreen({super.key, required this.onVideoSelected});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryController>();
    final results = library.searchResults;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Search your library...',
            hintStyle: const TextStyle(color: Colors.white38),
            border: InputBorder.none,
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close, color: Colors.white54, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      library.updateSearchQuery('');
                    },
                  )
                : null,
          ),
          onChanged: library.updateSearchQuery,
        ),
      ),
      body: results.isEmpty
          ? Center(
              child: Text(
                library.searchQuery.isEmpty
                    ? 'Type to search your videos'
                    : 'No videos match "${library.searchQuery}"',
                style: const TextStyle(color: Colors.white38),
              ),
            )
          : ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final entry = results[index];
                final isFavorite = library.favoritePaths.contains(entry.path);
                final isCompleted = library.completedPaths.contains(entry.path);
                final actualIndex = library.allVideosList.indexOf(entry);

                return ListTile(
                  leading: Icon(
                    isCompleted ? Icons.check_circle : Icons.play_circle_outline,
                    color: isCompleted ? Colors.greenAccent : Colors.white54,
                  ),
                  title: Text(
                    entry.displayTitle,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: isFavorite
                      ? const Icon(Icons.favorite, color: Colors.redAccent, size: 20)
                      : null,
                  onTap: () => widget.onVideoSelected(entry, actualIndex),
                );
              },
            ),
    );
  }
}
