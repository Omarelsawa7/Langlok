import 'package:flutter/material.dart';
import '../controllers/library_controller.dart';
import '../controllers/video_item_controller.dart';

class RightActionColumn extends StatelessWidget {
  final VideoItemController controller;
  final LibraryController library;

  const RightActionColumn({
    super.key,
    required this.controller,
    required this.library,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _ActionIcon(
              icon: controller.isFavorite ? Icons.favorite : Icons.favorite_border,
              label: 'Save',
              isActive: controller.isFavorite,
              activeColor: Colors.redAccent,
              onTap: () => controller.toggleFavorite(),
            ),
            const SizedBox(height: 22),
            _ActionIcon(
              icon: Icons.folder,
              label: 'Folder',
              onTap: () => library.switchFolder(),
            ),
            const SizedBox(height: 22),
            _ActionIcon(
              icon: Icons.refresh,
              label: 'Re-scan',
              onTap: () => library.rescan(),
            ),
            const SizedBox(height: 22),
            _ActionIcon(
              icon: Icons.loop,
              label: '5s',
              isActive: controller.isShadowingActive,
              onTap: () => controller.toggleShadowing(),
            ),
            const SizedBox(height: 22),
            _ActionIcon(
              icon: Icons.speed,
              label: '${controller.currentSpeed}x'.replaceAll('.0x', 'x'),
              isActive: controller.currentSpeed != 1.0,
              onTap: () => controller.cycleSpeed(),
            ),
          ],
        );
      },
    );
  }
}

class _ActionIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;

  const _ActionIcon({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.activeColor = Colors.amberAccent,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? activeColor : Colors.white;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.black38,
              shape: BoxShape.circle,
              border: isActive ? Border.all(color: activeColor, width: 1.5) : null,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
