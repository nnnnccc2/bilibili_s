import 'package:PiliPlus/app/router/app_routes.dart';
import 'package:PiliPlus/shared/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/core/constants/constants.dart';
import 'package:PiliPlus/core/theme/minibili_theme.dart';
import 'package:PiliPlus/features/account/domain/entities/account_state.dart';
import 'package:PiliPlus/features/account/presentation/providers/account_provider.dart';
import 'package:PiliPlus/features/home/domain/entities/home_tab_config.dart';
import 'package:PiliPlus/utils/page_utils.dart';
import 'package:PiliPlus/features/home/presentation/providers/search_controller.dart';
import 'package:go_router/go_router.dart';
import 'package:PiliPlus/features/shell/presentation/providers/unread_provider.dart';
import 'package:PiliPlus/models/common/dynamic/dynamic_badge_mode.dart';
import 'package:PiliPlus/models/common/image_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// 首页顶部栏
///
/// MiniBili 风格：
/// - 用户头像（圆形）
/// - 搜索框（圆角胶囊，半透明背景）
/// - 消息按钮（带未读角标）
class HomeAppBar extends ConsumerWidget {
  final HomeTabConfig config;

  const HomeAppBar({
    super.key,
    required this.config,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const padding = EdgeInsets.fromLTRB(14, 6, 14, 0);
    final child = Row(
      spacing: 8,
      children: [
        const UserAvatar(),
        Expanded(child: SearchBar(config: config)),
        const MsgBadge(),
      ],
    );

    return Container(
      height: StyleString.topBarHeight,
      padding: padding,
      child: child,
    );
  }
}

/// 用户头像
class UserAvatar extends ConsumerWidget {
  const UserAvatar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accountState = ref.watch(accountControllerProvider);

    return Semantics(
      label: "我的",
      child: GestureDetector(
        onTap: () => _handleTap(context, ref),
        child: accountState.isLogin
            ? _buildLoggedInAvatar(context, ref, theme, accountState)
            : _buildLoggedOutAvatar(context, ref, theme),
      ),
    );
  }

  /// 构建已登录头像
  Widget _buildLoggedInAvatar(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
    AccountState accountState,
  ) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        NetworkImgLayer(
          type: ImageType.avatar,
          width: 34,
          height: 34,
          src: accountState.face,
        ),
        if (accountState.isAnonymous)
          Positioned(
            right: -4,
            bottom: -4,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: MiniBiliColors.biliMutedSurface,
                ),
                child: Icon(
                  size: 14,
                  MdiIcons.incognito,
                  color: MiniBiliColors.biliSubtext,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 构建未登录头像
  Widget _buildLoggedOutAvatar(
    BuildContext context,
    WidgetRef ref,
    ThemeData theme,
  ) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: MiniBiliColors.biliMutedSurface,
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.person_rounded,
        size: 20,
        color: MiniBiliColors.biliBlue,
      ),
    );
  }

  /// 处理点击事件 - 跳转到我的页面
  void _handleTap(BuildContext context, WidgetRef ref) {
    context.pushNamed(AppRoutes.mine);
  }
}

/// 搜索框
class SearchBar extends ConsumerWidget {
  final HomeTabConfig config;

  const SearchBar({
    super.key,
    required this.config,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(searchSuggestionControllerProvider);

    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: MiniBiliColors.biliCard.withOpacity(0.8),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(
          color: MiniBiliColors.biliBorder,
          width: 0.5,
        ),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(19),
          splashColor: MiniBiliColors.biliBlue.withOpacity(0.08),
          highlightColor: Colors.transparent,
          onTap: () => PageUtils.pushNamed(
            AppRoutes.search,
            parameters:
                config.enableSearchWord && searchState.defaultSearch.isNotEmpty
                ? {'hintText': searchState.defaultSearch}
                : null,
          ),
          child: Row(
            children: [
              const SizedBox(width: 14),
              Icon(
                Icons.search_outlined,
                size: 20,
                color: MiniBiliColors.biliMuted,
                semanticLabel: '搜索',
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  searchState.defaultSearch,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: MiniBiliColors.biliMuted,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 5),
            ],
          ),
        ),
      ),
    );
  }
}

/// 消息角标
class MsgBadge extends ConsumerWidget {
  const MsgBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountState = ref.watch(accountControllerProvider);
    final msgBadgeMode = ref.read(msgBadgeModeProvider);

    if (!accountState.isLogin) {
      return const SizedBox.shrink();
    }

    final unreadMessage = ref.watch(unreadMessageControllerProvider);
    final isNumBadge = msgBadgeMode == DynamicBadgeMode.number;
    final hasUnread =
        msgBadgeMode != DynamicBadgeMode.hidden && unreadMessage.hasUnread;

    return GestureDetector(
      onTap: () {
        ref.read(unreadMessageControllerProvider.notifier).clear();
        ref.read(unreadMessageControllerProvider.notifier).resetCheckTime();
        PageUtils.pushNamed(AppRoutes.whisper);
      },
      child: Container(
        width: 38,
        height: 38,
        alignment: Alignment.center,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(
              Icons.notifications_none,
              size: 24,
              color: MiniBiliColors.biliText,
            ),
            if (hasUnread)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  alignment: Alignment.center,
                  child: isNumBadge
                      ? Text(
                          unreadMessage.displayText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
