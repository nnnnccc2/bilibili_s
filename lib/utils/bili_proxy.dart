import 'dart:convert';

import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/utils/wbi_sign.dart';
import 'package:dio/dio.dart';

/// WebView 数据桥：把 demo 前端发起的 `api.bilibili.com` 请求
/// 转发给 PiliPlus 的真实 HTTP 层执行（自动带上登录 Cookie / buvid，
/// 并对搜索类接口补 WBI 签名），再将原始 JSON 回吐给前端。
///
/// 前端因此无需直连 B 站（规避 WebView 中的 CORS / 风控拦截），
/// 且能拿到与 App 一致的登录态数据。
abstract final class BiliProxy {
  static const _allowedHosts = {'api.bilibili.com', 'app.bilibili.com'};

  /// 处理一次来自 JS 的代理请求，返回 `{status, body}`。
  static Future<Map<String, dynamic>> handle(Map<dynamic, dynamic> req) async {
    final rawUrl = (req['url'] ?? '').toString();
    final method = (req['method'] ?? 'GET').toString().toUpperCase();
    final rawBody = req['body'];

    try {
      final uri = Uri.parse(rawUrl);
      if (!_allowedHosts.contains(uri.host)) {
        return _error(403, 'host not allowed: ${uri.host}');
      }

      // 确保 Dio 单例已初始化（会注册 Cookie / 重试等拦截器）
      Request();

      final query = <String, Object>{};
      uri.queryParameters.forEach((k, v) => query[k] = v);

      // 搜索类接口需要 WBI 签名，否则 B 站直接返回 -403
      if (uri.path.startsWith('/x/web-interface/search/')) {
        final signed = await WbiSign.makSign(query);
        query
          ..clear()
          ..addAll(signed);
      }

      final base = Uri(
        scheme: uri.scheme,
        host: uri.host,
        path: uri.path,
      ).toString();

      final res = await Request.dio
          .request<String>(
            base,
            queryParameters: query.isEmpty ? null : query,
            data: method == 'POST' ? rawBody : null,
            options: Options(
              method: method,
              responseType: ResponseType.plain,
              // 保留原始状态码与响应体，交给前端自行判断
              validateStatus: (_) => true,
            ),
          )
          .timeout(const Duration(seconds: 20));

      return {
        'status': res.statusCode ?? 200,
        'body': res.data ?? '',
      };
    } catch (e) {
      return _error(500, '$e');
    }
  }

  static Map<String, dynamic> _error(int status, String msg) => {
    'status': status,
    'body': jsonEncode({'code': -1, 'message': msg}),
  };
}
