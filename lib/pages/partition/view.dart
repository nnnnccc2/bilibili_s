import 'package:PiliPlus/common/widgets/pure/pure.dart';
import 'package:PiliPlus/pages/rank/view.dart';
import 'package:material_ui/material_ui.dart';

/// 全站分区（对齐参考 demo）
class PartitionPage extends StatefulWidget {
  const PartitionPage({super.key});

  @override
  State<PartitionPage> createState() => _PartitionPageState();
}

class _PartitionPageState extends State<PartitionPage>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return const ColoredBox(
      color: PureColors.heroBg,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '全站分区',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: PureColors.titleText,
                        ),
                      ),
                      SizedBox(height: 3),
                      Text(
                        'Bilibili 官方分类频道 · 实时净化过滤',
                        style: TextStyle(
                          fontSize: 11,
                          color: PureColors.subText,
                        ),
                      ),
                    ],
                  ),
                ),
                PureDirectChip(),
              ],
            ),
          ),
          Expanded(child: PureBoard(child: RankPage())),
        ],
      ),
    );
  }
}
