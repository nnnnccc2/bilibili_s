import 'package:material_ui/material_ui.dart';

/// 纯净版（BiliBili 直连）设计 Token —— 对齐参考 demo
abstract final class PureColors {
  /// 品牌蓝：选中胶囊、主按钮、激活文字
  static const brand = Color(0xFF0DA2E7);

  /// 顶部 Hero 浅蓝底
  static const heroBg = Color(0xFFA7D8F0);

  /// Hero 天蓝叠加层（rgba(14,165,233,0.15)）
  static const heroOverlay = Color(0x260EA5E9);

  /// 内容面板
  static const board = Color(0xFFF5FBFF);

  /// 卡片：70% 半透明白
  static const cardBg = Color(0xB3FFFFFF);

  /// 标题文字
  static const titleText = Color(0xFF0F1729);

  /// 次要文字（作者 / 统计）
  static const subText = Color(0xFF65758B);

  /// 导航灰
  static const navGray = Color(0xFF64748B);

  /// 未选 tab 文字
  static const tabGray = Color(0xFF475569);

  /// 玫红（屏蔽词 chip）
  static const roseText = Color(0xFFE11D48);
  static const roseBg = Color(0xFFFFF1F2);
  static const roseBorder = Color(0xFFFFE4E6);

  /// 琥珀（时长档位选中）
  static const amberBg = Color(0xFFFFFBEB);
  static const amberBorder = Color(0xFFFCD34D);
  static const amberText = Color(0xFF78350F);

  /// 中性 chip
  static const chipBg = Color(0xFFF8FAFC);
  static const chipBorder = Color(0xFFE2E8F0);
  static const chipText = Color(0xFF475569);

  /// 开关
  static const switchTrack = Color(0xFF0EA5E9);
  static const switchThumb = Color(0xFF009688);

  /// 玻璃掠光
  static const glassBorder = Color(0x80FFFFFF);

  /// 时长角标
  static const badgeBg = Color(0xE60F172A);
}

/// 状态胶囊 "BiliBili 直连"
class PureDirectChip extends StatelessWidget {
  const PureDirectChip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0x0D0F1729),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_tethering, size: 12, color: PureColors.subText),
          SizedBox(width: 4),
          Text(
            'BiliBili 直连',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: PureColors.subText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Hero 头部：浅蓝背景 + 装饰圆 + 内容
class PureHeroHeader extends StatelessWidget {
  const PureHeroHeader({super.key, required this.child, this.height = 128});

  final Widget child;
  final double height;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: PureColors.heroBg,
      child: Stack(
        children: [
          // 左上装饰大圆
          Positioned(
            left: -70,
            top: -90,
            child: _circle(160, Colors.white.withValues(alpha: 0.25)),
          ),
          // 右上装饰小圆
          Positioned(
            right: -40,
            top: -50,
            child: _circle(110, Colors.white.withValues(alpha: 0.12)),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: child,
          ),
        ],
      ),
    );
  }

  Widget _circle(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );
}

/// 内容面板：圆角 24 顶部，覆盖在 Hero 之上
class PureBoard extends StatelessWidget {
  const PureBoard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        color: PureColors.board,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: child,
    );
  }
}

/// 胶囊 Tab 栏
class PurePillTabs extends StatelessWidget {
  const PurePillTabs({
    super.key,
    required this.labels,
    required this.index,
    required this.onTap,
    this.center = false,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onTap;
  final bool center;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 40,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: PureColors.glassBorder),
      ),
      child: Row(
        mainAxisSize: center ? MainAxisSize.min : MainAxisSize.max,
        children: [
          for (var i = 0; i < labels.length; i++)
            _tab(labels[i], i == index, () => onTap(i)),
        ],
      ),
    );
  }

  Widget _tab(String label, bool selected, VoidCallback onTap) {
    return Expanded(
      flex: center ? 0 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? PureColors.brand : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : PureColors.tabGray,
            ),
          ),
        ),
      ),
    );
  }
}

/// 通用 chip
enum PureChipType { rose, amber, neutral, brand }

class PureChip extends StatelessWidget {
  const PureChip({
    super.key,
    required this.label,
    this.type = PureChipType.neutral,
    this.selected = false,
    this.onTap,
  });

  final String label;
  final PureChipType type;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    late Color bg;
    late Color border;
    late Color text;
    switch (type) {
      case PureChipType.rose:
        bg = PureColors.roseBg;
        border = PureColors.roseBorder;
        text = PureColors.roseText;
      case PureChipType.amber:
        bg = selected ? PureColors.amberBg : PureColors.chipBg;
        border = selected ? PureColors.amberBorder : PureColors.chipBorder;
        text = selected ? PureColors.amberText : PureColors.chipText;
      case PureChipType.brand:
        bg = selected
            ? PureColors.brand
            : Colors.white.withValues(alpha: 0.7);
        border = selected
            ? PureColors.brand
            : Colors.white.withValues(alpha: 0.5);
        text = selected ? Colors.white : PureColors.chipText;
      case PureChipType.neutral:
        bg = Colors.white.withValues(alpha: 0.7);
        border = PureColors.chipBorder;
        text = PureColors.chipText;
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(
            type == PureChipType.brand ? 999 : 8,
          ),
          border: Border.all(color: border),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: type == PureChipType.rose ? 11 : 12,
            fontWeight: FontWeight.w600,
            color: text,
          ),
        ),
      ),
    );
  }
}

/// 半透明玻璃卡片
class PureGlassCard extends StatelessWidget {
  const PureGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 16,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: PureColors.cardBg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
      ),
      child: child,
    );
    if (onTap == null) return card;
    return GestureDetector(onTap: onTap, child: card);
  }
}

/// 净化开关行（标题 + 描述 + 开关 + 可选 chip 列表）
class PureSwitchCard extends StatelessWidget {
  const PureSwitchCard({
    super.key,
    required this.title,
    required this.desc,
    required this.value,
    required this.onChanged,
    this.chips = const [],
  });

  final String title;
  final String desc;
  final bool value;
  final ValueChanged<bool> onChanged;
  final List<String> chips;

  @override
  Widget build(BuildContext context) {
    return PureGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: PureColors.titleText,
                  ),
                ),
              ),
              _PureSwitch(value: value, onChanged: onChanged),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            desc,
            style: const TextStyle(
              fontSize: 11,
              height: 1.5,
              color: PureColors.subText,
            ),
          ),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in chips)
                  PureChip(label: c, type: PureChipType.rose),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PureSwitch extends StatelessWidget {
  const _PureSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return PureToggle(value: value, onChanged: onChanged);
  }
}

/// 纯净版开关
class PureToggle extends StatelessWidget {
  const PureToggle({super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 40,
        height: 22,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value
              ? PureColors.switchTrack.withValues(alpha: 0.3)
              : PureColors.chipBorder,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: value ? PureColors.switchTrack : PureColors.chipBorder,
            width: 1.5,
          ),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 150),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: value ? PureColors.switchThumb : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// 悬浮胶囊底栏导航项
class PureNavItem {
  const PureNavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final Widget icon;
  final Widget selectedIcon;
  final String label;
}

/// 悬浮胶囊底栏 + 右侧圆形搜索按钮（对齐参考 demo）
class PureFloatingNav extends StatelessWidget {
  const PureFloatingNav({
    super.key,
    required this.items,
    required this.index,
    required this.onTap,
    this.onSearch,
    this.bottomPadding = 10,
  });

  final List<PureNavItem> items;
  final int index;
  final ValueChanged<int> onTap;
  final VoidCallback? onSearch;
  final double bottomPadding;

  @override
  Widget build(BuildContext context) {
    final viewPadding = MediaQuery.viewPaddingOf(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16 + viewPadding.left,
        0,
        16 + viewPadding.right,
        bottomPadding + viewPadding.bottom,
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: PureColors.glassBorder),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x140F172A),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  for (var i = 0; i < items.length; i++)
                    Expanded(
                      child: _item(items[i], i == index, () => onTap(i)),
                    ),
                ],
              ),
            ),
          ),
          if (onSearch != null) ...[
            const SizedBox(width: 10),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onSearch,
              child: Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: PureColors.brand,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x330DA2E7),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(Icons.search, color: Colors.white, size: 24),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _item(PureNavItem item, bool selected, VoidCallback onTap) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: selected ? PureColors.brand : Colors.transparent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: IconTheme.merge(
              data: IconThemeData(
                size: 20,
                color: selected ? Colors.white : PureColors.navGray,
              ),
              child: selected ? item.selectedIcon : item.icon,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? PureColors.brand : PureColors.tabGray,
            ),
          ),
        ],
      ),
    );
  }
}

/// 统计小格
class PureStatTile extends StatelessWidget {
  const PureStatTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(height: 6),
          Text(
            '$value 次',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: PureColors.titleText,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10,
              height: 1.3,
              color: PureColors.subText,
            ),
          ),
        ],
      ),
    );
  }
}
