import 'dart:collection';

import 'package:PiliPlus/utils/bili_api.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:material_ui/material_ui.dart';

/// 本地前端入口（打包进 App assets，零网络启动）
const String _kEntryAsset = 'assets/webapp/index.html';

class WebAppPage extends StatefulWidget {
  const WebAppPage({super.key});

  @override
  State<WebAppPage> createState() => _WebAppPageState();
}

class _WebAppPageState extends State<WebAppPage> {
  InAppWebViewController? _controller;
  bool _webViewReady = false;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final topPadding = media.padding.top;
    final bottomPadding = media.padding.bottom;
    const heroBg = Color(0xFFA7D8F0);

    return PopScope(
      canPop: !_webViewReady,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final canGo = await _controller?.canGoBack() ?? false;
        if (canGo) {
          await _controller?.goBack();
        } else if (context.mounted) {
          Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
        backgroundColor: heroBg,
        extendBodyBehindAppBar: true,
        body: Column(
          children: [
            // 刘海区域：Hero 蓝填充，正文从刘海下边缘开始
            Container(height: topPadding, color: heroBg),
            Expanded(
              child: InAppWebView(
                initialSettings: InAppWebViewSettings(
                  javaScriptEnabled: true,
                  useHybridComposition: true,
                  allowsInlineMediaPlayback: true,
                  sharedCookiesEnabled: true,
                  mixedContentMode:
                      MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                  transparentBackground: false,
                  domStorageEnabled: true,
                  cacheEnabled: true,
                  mediaPlaybackRequiresUserGesture: false,
                  javaScriptCanOpenWindowsAutomatically: false,
                  
                  userAgent:
                      'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
                      'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
                      'Mobile/15E148 Safari/604.1 PiliPlus/2.1',
                ),
                initialUserScripts: UnmodifiableListView<UserScript>([
                  UserScript(
                    source: _kReadySignal,
                    injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
                  ),
                ]),
                // 直接加载打包进 assets 的本地 HTML
                initialFile: _kEntryAsset,
                onWebViewCreated: (controller) {
                  _controller = controller;
                  setState(() => _webViewReady = true);

                  // 所有前端 API 调用统一走这个 handler，由 BiliApi 分派
                  controller.addJavaScriptHandler(
                    handlerName: 'biliApi',
                    callback: (args) async {
                      final req = args.isNotEmpty ? args.first : null;
                      if (req is! Map) {
                        return {
                          'code': -1,
                          'message': 'invalid call format',
                        };
                      }
                      try {
                        // 把 JS 传过来的 Map 转成 Dart Map，key 全部转 String
                        final params = Map<String, dynamic>.from(req);
                        final result = await BiliApi.call(params);
                        // 把结果转成纯 JSON-compatible Map 返回给 JS
                        return _toJsonable(result);
                      } catch (e) {
                        return {'code': -1, 'message': e.toString()};
                      }
                    },
                  );
                },
              ),
            ),
            Container(height: bottomPadding, color: heroBg),
          ],
        ),
      ),
    );
  }

  /// 把可能包含 Dart 类型（int? / DateTime / List<dynamic> 等）的对象
  /// 递归转成 JS 能吃的纯 Map/List/String/num/bool。
  static dynamic _toJsonable(dynamic v) {
    if (v == null) return null;
    if (v is String || v is num || v is bool) return v;
    if (v is Map) {
      final out = <String, dynamic>{};
      for (final e in v.entries) {
        out[e.key.toString()] = _toJsonable(e.value);
      }
      return out;
    }
    if (v is List) {
      return v.map(_toJsonable).toList();
    }
    return v.toString();
  }
}

/// 页面加载完后主动通知原生（可选调试用）
const String _kReadySignal = r'''
try {
  if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
    window.flutter_inappwebview.callHandler('biliApi', {
      action: 'toast',
      params: {'msg': '前端就绪'}
    });
  }
} catch(e){}
''';
