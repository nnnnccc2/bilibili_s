import 'dart:collection';

import 'package:PiliPlus/utils/bili_proxy.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:get/get.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFA7D8F0),
      body: Stack(
        children: [
          InAppWebView(
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              useHybridComposition: true,
              mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
              transparentBackground: false,
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
            },
            onProgressChanged: (controller, progress) {
              if (progress >= 100) {
                if (_progress != 1) setState(() => _progress = 1);
              } else {
                setState(() => _progress = progress / 100);
              }
            },
            onReceivedError: (controller, request, error) {
              if ((request.isForMainFrame ?? false) && !_failed) {
                setState(() => _failed = true);
              }
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
          SafeArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: GestureDetector(
                  onTap: Get.back,
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.7),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chevron_left,
                      size: 22,
                      color: Color(0xFF0F1729),
                    ),
                  ),
                ),
              ),
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
    );
  }
}
