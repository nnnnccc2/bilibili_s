import 'dart:convert';

import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/utils/purification.dart';
import 'package:PiliPlus/utils/wbi_sign.dart';
import 'package:dio/dio.dart';

/// WebView 数据桥：把 demo 前端发起的 `api.bilibili.com` 请求
/// 转发给 PiliPlus 的真实 HTTP 层执行（自动带上登录 Cookie / buvid，
/// 并对搜索类接口补 WBI 签名），再将原始 JSON 回吐给前端。
///
/// 响应返回前会对视频列表类字段执行净化过滤（剔除命中条目）。
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
              validateStatus: (_) => true,
            ),
          )
          .timeout(const Duration(seconds: 20));

      String body = res.data ?? '';

      // 尝试解析 JSON 并做净化过滤
      try {
        final json = jsonDecode(body);
        _filterPurification(json, uri.path);
        body = jsonEncode(json);
      } catch (_) {
        // 非 JSON 响应，原样透传
      }

      return {
        'status': res.statusCode ?? 200,
        'body': body,
      };
    } catch (e) {
      return _error(500, '$e');
    }
  }

  /// 对响应 JSON 中常见的视频列表字段执行净化过滤。
  /// B 站 API 通常把业务数据放在 `result` / `data` 字段中，
  /// 视频卡片有 `title` / `author.name` / `duration` / `length` 等字段。
  static void _filterPurification(dynamic json, String path) {
    if (!Purification.anyEnabled) return;
    if (json is! Map) return;
    // path 参数保留以便后续按接口粒度精细化过滤时使用
    void _unused() => path;
    _unused();

    // 只处理返回成功的业务响应
    final code = json['code'];
    if (code != null && code != 0) return;

    void filterList(List list) {
      list.removeWhere((item) {
        if (item is! Map) return false;
        final title = (item['title'] ?? '').toString();
        final upName = _pickUpName(item);
        final duration = _pickDuration(item);
        if (title.isEmpty && upName == null && duration == null) {
          return false; // 不是视频卡片，保留
        }
        final hit = Purification.evaluate(
          title: title,
          upName: upName,
          duration: duration ?? 0,
        );
        if (hit != null) Purification.record(hit, title: title);
        return hit != null;
      });
    }

    // 不同接口把视频列表放在不同字段下，遍历查找并过滤
    final candidates = <String>['result', 'data'];
    for (final key in candidates) {
      final value = json[key];
      if (value is List) {
        filterList(value);
      } else if (value is Map) {
        // 嵌套情况，如 {"data": {"list": [...]}}
        for (final subKey in value.keys) {
          final sub = value[subKey];
          if (sub is List && sub.isNotEmpty && sub.first is Map) {
            filterList(sub);
          }
        }
      }
    }

    // 某些接口直接返回根层 list（很少见）
    if (json['result'] == null && json['data'] == null) {
      for (final key in json.keys) {
        final v = json[key];
        if (v is List && v.isNotEmpty && v.first is Map) {
          filterList(v);
        }
      }
    }
  }

  static String? _pickUpName(Map m) {
    final a = m['author'];
    if (a is Map) {
      final name = a['name'];
      if (name != null) return name.toString();
    }
    final up = m['up'];
    if (up is Map) {
      final name = up['name'];
      if (name != null) return name.toString();
    }
    final owner = m['owner'];
    if (owner is Map) {
      final name = owner['name'];
      if (name != null) return name.toString();
    }
    // app 端接口有时直接在顶层给 up_name
    final direct = m['up_name'] ?? m['uname'];
    if (direct != null) return direct.toString();
    return null;
  }

  static int? _pickDuration(Map m) {
    final duration = m['duration'];
    if (duration != null) return int.tryParse(duration.toString());
    final length = m['length'];
    if (length != null) {
      // 可能是 "MM:SS" 格式字符串
      final s = length.toString();
      final parts = s.split(':');
      if (parts.length == 2) {
        final m = int.tryParse(parts[0]);
        final sec = int.tryParse(parts[1]);
        if (m != null && sec != null) return m * 60 + sec;
      }
      return int.tryParse(s);
    }
    return null;
  }

  static Map<String, dynamic> _error(int status, String msg) => {
    'status': status,
    'body': jsonEncode({'code': -1, 'message': msg}),
  };
}
