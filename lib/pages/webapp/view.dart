import 'dart:io';
import 'dart:typed_data';

import 'package:PiliPlus/utils/bili_api.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:material_ui/material_ui.dart';

/// 把打包进 App 的 demo 前端资源（HTML/CSS/JS）通过一个本机 HTTP 服务
/// 暴露出来，再让 WebView 以 `http://127.0.0.1:<port>/` 作为入口加载。
///
/// 为什么不直接用 `initialFile`（file:// 源）：
/// WebKit 已按 HTML 规范限制 `file:` URL 下的 `history.pushState`，
/// 而本 demo 是 Expo Router 应用，站内路由完全依赖 pushState，
/// 在 file:// 源下会抛 SecurityError，导致首页重定向 / 点击视频等
/// 全部站内导航失效、界面表现异常。换成 http 源后与网页端行为一致。
class _WebAssetServer {
  static HttpServer? _server;
  static int? _port;

  static const Map<String, String> _mime = {
    'html': 'text/html; charset=utf-8',
    'js': 'application/javascript; charset=utf-8',
    'css': 'text/css; charset=utf-8',
    'json': 'application/json; charset=utf-8',
    'svg': 'image/svg+xml',
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'webp': 'image/webp',
    'gif': 'image/gif',
    'ttf': 'font/ttf',
    'woff': 'font/woff',
    'woff2': 'font/woff2',
  };

  /// 启动本地服务并返回入口地址（幂等，端口随机）
  static Future<String> start() async {
    if (_server != null && _port != null) {
      return 'http://127.0.0.1:$_port/index.html';
    }
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    _port = server.port;
    server.listen(_handle, onError: (_) {});
    return 'http://127.0.0.1:$_port/index.html';
  }

  static Future<void> _handle(HttpRequest req) async {
    try {
      var path = req.uri.path;
      if (path.isEmpty || path == '/') path = '/index.html';

      var data = await _load('assets/webapp$path');
      if (data == null || path.endsWith('/')) {
        // SPA 回退：/home、/video/xxx、/partition 等客户端路由
        // 统一返回入口 HTML，由前端自己解析路由。
        data = await _load('assets/webapp/index.html');
        path = '/index.html';
      }
      if (data == null) {
        req.response.statusCode = HttpStatus.notFound;
      } else {
        final ct = _mime[path.split('.').last.toLowerCase()];
        req.response.headers.contentType = ContentType.parse(
          ct ?? 'application/octet-stream',
        );
        req.response.add(data);
      }
    } catch (_) {
      // 忽略单个请求异常
    } finally {
      try {
        await req.response.close();
      } catch (_) {}
    }
  }

  static Future<Uint8List?> _load(String key) async {
    try {
      final d = await rootBundle.load(key);
      return d.buffer.asUint8List(d.offsetInBytes, d.lengthInBytes);
    } catch (_) {
      return null;
    }
  }
}

class WebAppPage extends StatefulWidget {
  const WebAppPage({super.key});

  @override
  State<WebAppPage> createState() => _WebAppPageState();
}

class _WebAppPageState extends State<WebAppPage> {
  InAppWebViewController? _controller;
  String? _entryUrl;
  bool _webViewReady = false;

  @override
  void initState() {
    super.initState();
    _WebAssetServer.start().then((url) {
      if (mounted) setState(() => _entryUrl = url);
    });
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final topPadding = media.padding.top;
    final bottomPadding = media.padding.bottom;
    const heroBg = Color(0xFFA7D8F0);

    final url = _entryUrl;
    final Widget body = url == null
        ? const ColoredBox(
            color: heroBg,
            child: Center(child: CircularProgressIndicator()),
          )
        : InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(url)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              allowsInlineMediaPlayback: true,
              sharedCookiesEnabled: true,
              mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              transparentBackground: false,
              domStorageEnabled: true,
              cacheEnabled: true,
              mediaPlaybackRequiresUserGesture: false,
              javaScriptCanOpenWindowsAutomatically: false,
              useShouldOverrideUrlLoading: false,
              userAgent:
                  'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
                  'AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 '
                  'Mobile/15E148 Safari/604.1 PiliPlus/2.1',
            ),
            onWebViewCreated: (controller) {
              _controller = controller;
              _webViewReady = true;

              // 前端所有 API 调用统一走这里，由 BiliApi 分派到原生能力
              controller.addJavaScriptHandler(
                handlerName: 'biliApi',
                callback: (args) async {
                  final req = args.isNotEmpty ? args.first : null;
                  if (req is! Map) {
                    return {'code': -1, 'message': 'invalid call format'};
                  }
                  try {
                    final params = Map<String, dynamic>.from(req);
                    final result = await BiliApi.call(params);
                    return _toJsonable(result);
                  } catch (e) {
                    return {'code': -1, 'message': e.toString()};
                  }
                },
              );
            },
          );

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
        body: Column(
          children: [
            // 刘海区域：Hero 蓝填充，正文从刘海下边缘开始
            Container(height: topPadding, color: heroBg),
            Expanded(child: body),
            Container(height: bottomPadding, color: heroBg),
          ],
        ),
      ),
    );
  }

  /// 递归把 Dart 对象转成 JS 能直接消费的纯 Map/List/String/num/bool
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
