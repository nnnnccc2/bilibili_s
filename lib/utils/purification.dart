import 'dart:math' as math;

import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:get/get.dart';

/// 净化规则分类
abstract final class PurifyCat {
  static const clickbait = 'clickbait';
  static const insult = 'insult';
  static const japaneseUp = 'japaneseUp';
  static const japaneseTitle = 'japaneseTitle';
  static const duration = 'duration';
}

/// 单条视频命中净化规则的结果
class PurifyHit {
  final String category;
  final String reason;
  const PurifyHit(this.category, this.reason);
}

/// 净化引擎：标题党/引导词、侮辱贬低词库、日文字符、时长档位
abstract final class Purification {
  /// 内置标题党/引导词（命中标题即拦截，含全角/半角感叹号）
  static const List<String> defaultClickbait = [
    '！',
    '!',
    '疯了',
    '炸了',
    '屌爆了',
    '惊呆了',
    '吓尿了',
    '千万别看',
    '看完哭了',
    '震惊全网',
    '赶紧删',
    '竟然是这样',
    '秘密曝光',
    '终于瞒不住了',
    '泪目了',
    '泪崩',
    '全网首发',
    '看完沉默了',
  ];

  /// 内置侮辱、贬低词语屏蔽清单（32 个）
  static const List<String> defaultInsult = [
    '弱智',
    '脑残',
    '煞笔',
    '傻逼',
    '沙雕',
    '蠢货',
    '低能',
    '白痴',
    '贱人',
    'nt',
    'sb',
    'nc',
    '孤儿',
    '死全家',
    '没妈',
    '狗都不看',
    '垃圾UP',
    '小丑',
    '下头',
    '恶心',
    '晦气',
    '滚出',
    '闭嘴',
    '智障',
    '废物',
    '无脑',
    '狗屎',
    '装逼',
    '骗子',
    '恰烂饭',
    '黑料',
    '翻车塌房',
  ];

  /// 16 档时长档位（秒）
  static const List<int> durationTierValues = [
    10,
    28,
    30,
    60,
    120,
    180,
    240,
    300,
    360,
    420,
    480,
    540,
    600,
    720,
    840,
    900,
  ];

  /// 默认选中前三档：10 秒 / 28 秒 / 30 秒
  static const List<int> defaultDurationTiers = [10, 28, 30];

  /// 日文字符（平假名 / 片假名 / 半角片假名）检测
  static final RegExp _jpRegExp = RegExp(
    r'[\u3040-\u309F\u30A0-\u30FF\uFF66-\uFF9F]',
  );

  // ---------------- 配置读取 ----------------

  static bool get enableClickbait =>
      GStorage.setting.get(SettingBoxKey.pureClickbait, defaultValue: true);

  static bool get enableJapaneseUp =>
      GStorage.setting.get(SettingBoxKey.pureJapaneseUp, defaultValue: true);

  static bool get enableJapaneseTitle => GStorage.setting.get(
    SettingBoxKey.pureJapaneseTitle,
    defaultValue: true,
  );

  static bool get enableFilterTipBar =>
      GStorage.setting.get(SettingBoxKey.pureFilterTipBar, defaultValue: false);

  static List<String> get clickbaitWords =>
      (GStorage.setting.get(SettingBoxKey.pureClickbaitWords) as List?)
          ?.cast<String>() ??
      defaultClickbait;

  static List<String> get insultWords =>
      (GStorage.setting.get(SettingBoxKey.pureInsultWords) as List?)
          ?.cast<String>() ??
      defaultInsult;

  static List<int> get durationTiers =>
      (GStorage.setting.get(SettingBoxKey.pureDurationTiers) as List?)
          ?.map((e) => e as int)
          .toList() ??
      defaultDurationTiers;

  /// 是否存在任一启用的净化规则
  static bool get anyEnabled =>
      enableClickbait ||
      enableJapaneseUp ||
      enableJapaneseTitle ||
      durationTiers.isNotEmpty;

  // ---------------- 评估 ----------------

  /// 判断一条视频是否命中净化规则，命中则返回原因，未命中返回 null
  static PurifyHit? evaluate({
    required String title,
    String? upName,
    required int duration,
  }) {
    // 标题党/引导词
    if (enableClickbait) {
      for (final w in clickbaitWords) {
        if (w.isEmpty) continue;
        if (_isPunctOnly(w)) {
          // 纯标点（如「！」）仅在夸张重复（≥2 次）时判定为标题党，避免误伤正常标题
          if (_countOccurrences(title, w) >= 2) {
            return PurifyHit(PurifyCat.clickbait, '引导式/标题党关键词: "$w"');
          }
        } else if (title.contains(w)) {
          return PurifyHit(PurifyCat.clickbait, '引导式/标题党关键词: "$w"');
        }
      }
    }
    // 博主昵称含日文字符
    if (enableJapaneseUp && upName != null && upName.isNotEmpty) {
      if (_jpRegExp.hasMatch(upName)) {
        return PurifyHit(PurifyCat.japaneseUp, '博主包含日文字符 ($upName)');
      }
    }
    // 标题含日文字符
    if (enableJapaneseTitle && _jpRegExp.hasMatch(title)) {
      return const PurifyHit(PurifyCat.japaneseTitle, '标题包含日文字符');
    }
    // 侮辱、贬低词库
    final lowerTitle = title.toLowerCase();
    for (final w in insultWords) {
      if (w.isNotEmpty && lowerTitle.contains(w.toLowerCase())) {
        return PurifyHit(PurifyCat.insult, '侮辱贬低词库: "$w"');
      }
    }
    // 时长档位：屏蔽时长小于或等于任一选中档位的视频
    final tiers = durationTiers;
    if (duration > 0 && tiers.isNotEmpty) {
      final maxTier = stagesMax(tiers);
      if (duration <= maxTier) {
        return PurifyHit(
          PurifyCat.duration,
          '视频时长限制: ≤${_fmtDuration(maxTier)}',
        );
      }
    }
    return null;
  }

  static int stagesMax(List<int> list) {
    int m = list.first;
    for (final e in list) {
      m = math.max(m, e);
    }
    return m;
  }

  /// 关键词是否为纯标点/符号（不含中文、字母、数字）
  static bool _isPunctOnly(String w) =>
      !RegExp(r'[\u4e00-\u9FA5A-Za-z0-9]').hasMatch(w);

  /// 统计子串在文本中出现的次数（不重叠）
  static int _countOccurrences(String text, String sub) {
    if (sub.isEmpty) return 0;
    var count = 0;
    var i = 0;
    while ((i = text.indexOf(sub, i)) != -1) {
      count++;
      i += sub.length;
    }
    return count;
  }

  static String _fmtDuration(int seconds) {
    if (seconds < 60) return '$seconds秒';
    if (seconds % 60 == 0) return '${seconds ~/ 60}分钟';
    return '${seconds ~/ 60}分${seconds % 60}秒';
  }

  /// 时长档位的展示文案
  static String tierLabel(int seconds) {
    if (seconds < 60) return '$seconds秒';
    if (seconds % 60 == 0) return '${seconds ~/ 60}分钟';
    return '${seconds ~/ 60}分${seconds % 60}秒';
  }

  // ---------------- 统计看板与拦截日志 ----------------

  static final RxInt sessionCount = 0.obs;

  static Map<String, int> get stats {
    final raw = GStorage.setting.get(SettingBoxKey.pureStats);
    final result = <String, int>{
      PurifyCat.clickbait: 0,
      PurifyCat.insult: 0,
      PurifyCat.japaneseUp: 0,
      PurifyCat.japaneseTitle: 0,
      PurifyCat.duration: 0,
    };
    if (raw is Map) {
      raw.forEach((k, v) {
        final key = k.toString();
        if (v is int) result[key] = v;
      });
    }
    return result;
  }

  static int get totalCount =>
      stats.values.fold(0, (prev, e) => prev + e);

  /// 合并展示：博主/标题含日文字符
  static int get japaneseCount =>
      (stats[PurifyCat.japaneseUp] ?? 0) + (stats[PurifyCat.japaneseTitle] ?? 0);

  static List<Map<String, dynamic>> get logs {
    final raw = GStorage.setting.get(SettingBoxKey.pureLog);
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
    }
    return const [];
  }

  /// 记录一条拦截：累加看板计数并写入拦截日志
  static void record(PurifyHit hit, {required String title}) {
    sessionCount.value++;

    final newStats = stats;
    newStats[hit.category] = (newStats[hit.category] ?? 0) + 1;
    GStorage.setting.put(SettingBoxKey.pureStats, newStats);

    final newLogs = logs.toList()
      ..insert(0, {
        'reason': hit.reason,
        'title': title,
        'time': _timeLabel(DateTime.now()),
      });
    if (newLogs.length > 60) {
      newLogs.removeRange(60, newLogs.length);
    }
    GStorage.setting.put(SettingBoxKey.pureLog, newLogs);
  }

  static void resetStats() {
    GStorage.setting
      ..put(SettingBoxKey.pureStats, <String, int>{})
      ..put(SettingBoxKey.pureLog, <Map<String, dynamic>>[]);
    sessionCount.value = 0;
  }

  static void clearLog() {
    GStorage.setting.put(SettingBoxKey.pureLog, <Map<String, dynamic>>[]);
  }

  static String _timeLabel(DateTime t) {
    String two(int v) => v < 10 ? '0$v' : '$v';
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}
