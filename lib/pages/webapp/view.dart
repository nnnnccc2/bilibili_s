import 'dart:collection';

import 'package:PiliPlus/utils/app_scheme.dart';
import 'package:PiliPlus/utils/bili_proxy.dart';
import 'package:PiliPlus/utils/login_utils.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:material_ui/material_ui.dart';

/// 直连 demo 前端地址（Expo / React Native Web 单页应用）
const String kPureWebAppUrl = 'https://app-f21s84ukr5dt.miaoda.online/home';

/// 在页面脚本执行前注入：拦截发往 `api.bilibili.com` 的 fetch，
/// 改为经原生桥（biliProxy）执行，规避 WebView 的 CORS / 风控拦截，
/// 并复用 App 的登录 Cookie 与 WBI 签名。
const String _kProxyScript = r'''
(function () {
  function install() {
    var f = window.fetch;
    if (!f || f.__biliPatched) return;
    var orig = f.bind(window);
    var wrapped = function (input, init) {
      try {
        var url = (typeof input === 'string') ? input : (input && input.url) || '';
        if (
          url.indexOf('api.bilibili.com') !== -1 &&
          window.flutter_inappwebview &&
          window.flutter_inappwebview.callHandler
        ) {
          var method = (init && init.method) || (input && input.method) || 'GET';
          return window.flutter_inappwebview
            .callHandler('biliProxy', {
              url: url,
              method: method,
              body: (init && typeof init.body === 'string') ? init.body : null
            })
            .then(function (res) {
              var body = (res && res.body) || '{"code":-1}';
              var status = (res && res.status) || 200;
              return new Response(body, {
                status: status,
                headers: { 'Content-Type': 'application/json; charset=utf-8' }
              });
            });
        }
      } catch (e) {}
      return orig(input, init);
    };
    wrapped.__biliPatched = true;
    window.fetch = wrapped;
  }
  install();
  var n = 0;
  var timer = setInterval(function () {
    install();
    if (++n > 30) clearInterval(timer);
  }, 100);
})();
''';

class WebAppPage extends StatefulWidget {
  const WebAppPage({super.key});

  @override
  State<WebAppPage> createState() => _WebAppPageState();
}

class _WebAppPageState extends State<WebAppPage> {
  InAppWebViewController? _controller;
  double _progress = 0;
  bool _failed = false;
  bool _webViewReady = false;

  @override
  void initState() {
    super.initState();
    // 把 PiliPlus 原生 cookie（登录态）同步进 WebView 的 cookie jar，
    // 这样 WebView 内部直接访问的页面（如播放 iframe）也带登录态
    Future.microtask(() {
      try {
        LoginUtils.setWebCookie();
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // iOS 手势返回 / 物理返回键：优先让 WebView 回退历史，
      // 退无可退时才退出页面
      canPop: !_webViewReady,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final canGo = await _controller?.canGoBack() ?? false;
        if (canGo) {
          await _controller?.goBack();
        } else {
          if (context.mounted) Navigator.of(context).maybePop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFA7D8F0),
        body: Stack(
          children: [
            InAppWebView(
              initialSettings: InAppWebViewSettings(
                javaScriptEnabled: true,
                useHybridComposition: true,
                mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
                transparentBackground: false,
                userAgent:
                    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) '
                    'AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 PiliPlus/2.1',
              ),
              initialUserScripts: UnmodifiableListView<UserScript>([
                UserScript(
                  source: _kProxyScript,
                  injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
                ),
              ]),
              initialUrlRequest: URLRequest(url: WebUri(kPureWebAppUrl)),
              onWebViewCreated: (controller) {
                _controller = controller;
                setState(() => _webViewReady = true);
                controller.addJavaScriptHandler(
                  handlerName: 'biliProxy',
                  callback: (args) {
                    final req = args.isNotEmpty ? args.first : null;
                    if (req is Map) {
                      return BiliProxy.handle(req);
                    }
                    return {'status': 400, 'body': '{"code":-1}'};
                  },
                );
                // 原生播放器跳转 handler：JS 侧可以 callHandler('openPlayer', {aid, bvid})
                controller.addJavaScriptHandler(
                  handlerName: 'openPlayer',
                  callback: (args) async {
                    if (args.isEmpty || args.first is! Map) return null;
                    final m = args.first as Map;
                    final aid = int.tryParse('${m['aid'] ?? ''}');
                    final bvid = m['bvid']?.toString();
                    if (aid != null || (bvid != null && bvid.isNotEmpty)) {
                      await PiliScheme.videoPush(aid, bvid);
                    }
                    return null;
                  },
                );
              },
              shouldOverrideUrlLoading: (controller, navigationAction) async {
                final host = navigationAction.request.url?.host ?? '';

                // 拦截播放器 iframe / 视频详情页 URL → 走原生播放器
                if (host == 'player.bilibili.com' ||
                    host == 'www.bilibili.com' ||
                    host == 'm.bilibili.com') {
                  final uri = navigationAction.request.url!;
                  // player.html?bvid=xxx&aid=xxx
                  if (uri.path.contains('player') ||
                      uri.path.startsWith('/video/')) {
                    final bvid = uri.queryParameters['bvid'] ??
                        _extractBvidFromPath(uri.path);
                    final aid = int.tryParse(uri.queryParameters['aid'] ?? '');
                    PiliScheme.videoPush(aid, bvid);
                    return NavigationActionPolicy.CANCEL;
                  }
                }

                // bilibili 登录 → 交给 WebView 自己处理，后续 cookie 再同步回原生
                if (host == 'passport.bilibili.com') {
                  return NavigationActionPolicy.ALLOW;
                }

                // 其他域名正常加载
                return NavigationActionPolicy.ALLOW;
              },
              onProgressChanged: (controller, progress) {
                setState(() => _progress = progress / 100);
              },
              onReceivedError: (controller, request, error) {
                if ((request.isForMainFrame ?? false) && !_failed) {
                  setState(() => _failed = true);
                }
              },
              onLoadStop: (controller, url) {
                // 每次页面加载完毕再补一次 cookie（WebView 可能丢失）
                try {
                  LoginUtils.setWebCookie();
                } catch (_) {}
              },
            ),
            if (_progress < 1)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  value: _progress == 0 ? null : _progress,
                ),
              ),
            if (_failed)
              Container(
                color: const Color(0xFFF5FBFF),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off,
                      size: 48,
                      color: Color(0xFF65758B),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      '页面加载失败，请检查网络',
                      style: TextStyle(color: Color(0xFF65758B)),
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () {
                        setState(() => _failed = false);
                        _controller?.reload();
                      },
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String? _extractBvidFromPath(String path) {
    final re = RegExp(r'(BV[0-9A-Za-z]+)');
    final m = re.firstMatch(path);
    return m?.group(1);
  }
}
