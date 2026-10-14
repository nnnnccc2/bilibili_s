import 'package:PiliPlus/common/widgets/pure/pure.dart';
import 'package:PiliPlus/utils/purification.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:material_ui/material_ui.dart';

/// 垃圾过滤与设置中心（对齐参考 demo）
class PurificationSettingPage extends StatefulWidget {
  const PurificationSettingPage({super.key});

  @override
  State<PurificationSettingPage> createState() =>
      _PurificationSettingPageState();
}

class _PurificationSettingPageState extends State<PurificationSettingPage> {
  final _setting = GStorage.setting;

  bool get _enableClickbait => Purification.enableClickbait;
  bool get _enableJapaneseUp => Purification.enableJapaneseUp;
  bool get _enableJapaneseTitle => Purification.enableJapaneseTitle;
  bool get _enableFilterTipBar => Purification.enableFilterTipBar;

  void _refresh() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final stats = Purification.stats;
    final tiers = Purification.durationTiers;
    return Scaffold(
      backgroundColor: PureColors.board,
      appBar: AppBar(
        title: const Text('垃圾过滤与设置中心'),
        backgroundColor: PureColors.board,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: '拦截明细日志',
            onPressed: _showLog,
            icon: const Icon(Icons.receipt_long_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 40),
        children: [
          _board(stats),
          const SizedBox(height: 12),
          PureSwitchCard(
            title: '自动过滤垃圾与引导式标题',
            desc: '自动拦截包含「疯了」「炸了」「屌爆了」「！」等标点或夸张煽动词的视频',
            value: _enableClickbait,
            onChanged: (v) {
              _setting.put(SettingBoxKey.pureClickbait, v);
              _refresh();
            },
            chips: Purification.defaultClickbait,
          ),
          const SizedBox(height: 10),
          PureSwitchCard(
            title: '自动过滤博主名称含日语字',
            desc: '识别 UP 主昵称中的平假名 / 片假名字符并自动拦截其视频',
            value: _enableJapaneseUp,
            onChanged: (v) {
              _setting.put(SettingBoxKey.pureJapaneseUp, v);
              _refresh();
            },
          ),
          const SizedBox(height: 10),
          PureSwitchCard(
            title: '过滤日语标题视频',
            desc: '自动过滤含有日文字符的视频标题',
            value: _enableJapaneseTitle,
            onChanged: (v) {
              _setting.put(SettingBoxKey.pureJapaneseTitle, v);
              _refresh();
            },
          ),
          const SizedBox(height: 10),
          _durationCard(tiers),
          const SizedBox(height: 10),
          PureSwitchCard(
            title: '显示已过滤提示条',
            desc: '在首页顶部展示已净化视频条数与规则快捷入口',
            value: _enableFilterTipBar,
            onChanged: (v) {
              _setting.put(SettingBoxKey.pureFilterTipBar, v);
              _refresh();
            },
          ),
          const SizedBox(height: 18),
          _insultSection(),
        ],
      ),
    );
  }

  Widget _board(Map<String, int> stats) {
    return PureGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.shield_outlined, size: 16, color: PureColors.brand),
              SizedBox(width: 6),
              Text(
                '净化引擎实时看板',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: PureColors.brand,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [PureColors.brand, Color(0xFF38BDF8)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.verified_user, color: Colors.white, size: 26),
                const SizedBox(height: 8),
                Text(
                  '累计拦截低质视频 ${Purification.totalCount} 条',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PureStatTile(
                  icon: Icons.campaign_outlined,
                  iconColor: PureColors.roseText,
                  value: stats[PurifyCat.clickbait] ?? 0,
                  label: '标题党/惊悚\n引导词',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PureStatTile(
                  icon: Icons.timelapse_outlined,
                  iconColor: const Color(0xFFF59E0B),
                  value: stats[PurifyCat.duration] ?? 0,
                  label: '视频时长\n限制屏蔽',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PureStatTile(
                  icon: Icons.translate_outlined,
                  iconColor: PureColors.brand,
                  value: Purification.japaneseCount,
                  label: '博主/标题\n含日文字符',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PureStatTile(
                  icon: Icons.gavel_outlined,
                  iconColor: const Color(0xFF10B981),
                  value: stats[PurifyCat.insult] ?? 0,
                  label: '侮辱贬低\n词库拦截',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _durationCard(List<int> tiers) {
    return PureGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '根据视频时长屏蔽短视频',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: PureColors.titleText,
                  ),
                ),
              ),
              Text(
                '已选 ${tiers.length} 档',
                style: const TextStyle(
                  fontSize: 11,
                  color: PureColors.brand,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              PureToggle(
                value: tiers.isNotEmpty,
                onChanged: (v) {
                  _setting.put(
                    SettingBoxKey.pureDurationTiers,
                    v ? Purification.defaultDurationTiers : <int>[],
                  );
                  _refresh();
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '勾选的档位表示屏蔽视频时长小于或等于该档位的视频（拦截无实质内容的碎片短视频）',
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: PureColors.subText,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in Purification.durationTierValues)
                PureChip(
                  label: Purification.tierLabel(t),
                  type: PureChipType.amber,
                  selected: tiers.contains(t),
                  onTap: () {
                    final newTiers = tiers.toList();
                    if (newTiers.contains(t)) {
                      newTiers.remove(t);
                    } else {
                      newTiers.add(t);
                    }
                    newTiers.sort();
                    _setting.put(SettingBoxKey.pureDurationTiers, newTiers);
                    _refresh();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _insultSection() {
    final words = Purification.insultWords;
    final controller = TextEditingController();
    return PureGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '侮辱、贬低词语屏蔽清单',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: PureColors.titleText,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '内置常见攻击、侮辱性词汇，标题或简介命中该词时直接屏蔽：',
            style: TextStyle(fontSize: 11, color: PureColors.subText),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: '输入要屏蔽的侮辱/低质词语...',
                    hintStyle: const TextStyle(
                      fontSize: 12,
                      color: PureColors.subText,
                    ),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.8),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  final v = controller.text.trim();
                  if (v.isEmpty) {
                    SmartDialog.showToast('请输入有效词语');
                    return;
                  }
                  if (v.length > 20) {
                    SmartDialog.showToast('词语长度不能超过20个字符');
                    return;
                  }
                  if (words.contains(v)) {
                    SmartDialog.showToast('该词语已存在于词库中');
                    return;
                  }
                  _setting.put(SettingBoxKey.pureInsultWords, [...words, v]);
                  controller.clear();
                  _refresh();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: PureColors.brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text('添加'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Text(
                '词库 (${words.length}个):',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: PureColors.subText,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () {
                  _setting.put(
                    SettingBoxKey.pureInsultWords,
                    Purification.defaultInsult,
                  );
                  _refresh();
                },
                child: const Text('重置默认'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final w in words)
                GestureDetector(
                  onLongPress: () {
                    _setting.put(
                      SettingBoxKey.pureInsultWords,
                      words.where((e) => e != w).toList(),
                    );
                    _refresh();
                  },
                  child: PureChip(label: w, type: PureChipType.rose),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showLog() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        final logs = Purification.logs;
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          decoration: const BoxDecoration(
            color: PureColors.board,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '净化拦截实时日志',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: PureColors.titleText,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '显示最近触发过滤规则的视频与拦截依据',
                style: TextStyle(fontSize: 11, color: PureColors.subText),
              ),
              const SizedBox(height: 12),
              if (logs.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Text(
                      '暂无被拦截的视频记录',
                      style: TextStyle(color: PureColors.subText),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: logs.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 16, color: PureColors.chipBorder),
                    itemBuilder: (_, i) {
                      final item = logs[i];
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: PureChip(
                                  label: (item['reason'] ?? '').toString(),
                                  type: PureChipType.rose,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                (item['time'] ?? '').toString(),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: PureColors.subText,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            (item['title'] ?? '').toString(),
                            style: const TextStyle(
                              fontSize: 13,
                              color: PureColors.titleText,
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
