import 'package:flutter/material.dart';

class ModeTopBar extends StatelessWidget {
  final bool isCourseMode;
  final ValueChanged<bool> onModeChanged;
  final VoidCallback? onEpisodeListTap;
  final VoidCallback? onSearchTap;
  final VoidCallback? onVocabBankTap;
  final VoidCallback? onThemeToggleTap;
  final bool isDarkMode;

  const ModeTopBar({
    super.key,
    required this.isCourseMode,
    required this.onModeChanged,
    this.onEpisodeListTap,
    this.onSearchTap,
    this.onVocabBankTap,
    this.onThemeToggleTap,
    this.isDarkMode = true,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.search, color: Colors.white),
              onPressed: onSearchTap,
            ),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ModeButton(
                    label: 'Random',
                    selected: !isCourseMode,
                    onTap: () => onModeChanged(false),
                  ),
                  _ModeButton(
                    label: 'Course',
                    selected: isCourseMode,
                    onTap: () => onModeChanged(true),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isCourseMode)
                  IconButton(
                    icon: const Icon(Icons.list, color: Colors.white),
                    onPressed: onEpisodeListTap,
                  ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: Colors.white),
                  color: const Color(0xFF1C1C1E),
                  onSelected: (value) {
                    if (value == 'vocab') onVocabBankTap?.call();
                    if (value == 'theme') onThemeToggleTap?.call();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'vocab',
                      child: Row(
                        children: [
                          Icon(Icons.bookmark, color: Colors.white70, size: 20),
                          SizedBox(width: 10),
                          Text('Vocabulary', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'theme',
                      child: Row(
                        children: [
                          Icon(
                            isDarkMode ? Icons.light_mode : Icons.dark_mode,
                            color: Colors.white70,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isDarkMode ? 'Light Mode' : 'Dark Mode',
                            style: const TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ModeButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
