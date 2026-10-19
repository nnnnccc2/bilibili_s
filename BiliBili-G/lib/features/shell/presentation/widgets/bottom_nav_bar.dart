import 'package:PiliPlus/core/theme/minibili_theme.dart';
import 'package:PiliPlus/models/common/nav_bar_config.dart';
import 'package:PiliPlus/features/shell/presentation/widgets/nav_icon_builder.dart';
import 'package:flutter/material.dart';

/// 底部导航栏 — MiniBili 浮动胶囊风格
///
/// 用于移动端竖屏模式，显示底部导航项。
/// 采用 MiniBili 设计：半透明白底胶囊、圆角、阴影、选中项 biliBlue。
class ShellBottomNavigationBar extends StatelessWidget {
  const ShellBottomNavigationBar({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.dynCount,
    required this.onDestinationSelected,
  });

  final List<NavigationBarType> items;
  final int selectedIndex;
  final int dynCount;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withOpacity(0.6),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: items.asMap().entries.map((entry) {
            final index = entry.key;
            final item = entry.value;
            final isSelected = index == selectedIndex;
            return Expanded(
              child: GestureDetector(
                onTap: () => onDestinationSelected(index),
                behavior: HitTestBehavior.opaque,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedScale(
                      scale: isSelected ? 1.08 : 1.0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      child: NavIconBuilder(
                        type: item,
                        selected: isSelected,
                        dynCount: dynCount,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? MiniBiliColors.biliBlue
                            : MiniBiliColors.biliMuted,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
