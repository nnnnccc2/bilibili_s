// JS Bridge 原生后端：为嵌入的本地 HTML/JS 前端提供所有 Bilibili API 能力
// 复用 PiliPlus 现有 Request.dio（自动携带 cookie / buvid / wbi 签名拦截器链）
// 以及 Purification 净化引擎

import 'dart:convert';

import 'package:PiliPlus/http/init.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/http/login.dart';
import 'package:PiliPlus/models/common/account_type.dart';
import 'package:PiliPlus/pages/login/view.dart';
import 'package:PiliPlus/utils/accounts.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:PiliPlus/utils/app_scheme.dart';
import 'package:PiliPlus/utils/purification.dart';
import 'package:PiliPlus/utils/wbi_sign.dart';
import 'package:dio/dio.dart';
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:get/get.dart';

/// JS Bridge 后端入口 —— 所有 Bilibili 功能通过 [call] 分派
abstract final class BiliApi {
  // ---------------------------------------------------------------------------
  // 公共入口
  // ---------------------------------------------------------------------------

  /// JS 前端唯一调用入口：根据 [params]['action'] 分派
  static Future<Map<String, dynamic>> call(Map<String, dynamic> params) async {
    try {
      // 确保 Dio 单例已初始化（首次调用时触发工厂构造）
      Request();
      final action = params['action'] as String? ?? '';
      final Map<String, dynamic> p = params['params'] is Map
          ? (params['params'] as Map<String, dynamic>)
          : <String, dynamic>{};

      switch (action) {
        case 'proxy':
          return await _proxy(p);
        case 'whoami':
          return await _whoami();
        case 'logout':
          return await _logout();
        case 'loginQr':
          return await _loginQr();
        case 'loginPoll':
          return await _loginPoll(p);
        case 'deviceInset':
          return await _deviceInset();
        case 'home':
          return await _home(p);
        case 'follow':
          return await _follow(p);
        case 'regionList':
          return await _regionList();
        case 'region':
          return await _region(p);
        case 'searchHot':
          return await _searchHot();
        case 'search':
          return await _search(p);
        case 'video':
          return await _video(p);
        case 'videoRelated':
          return await _videoRelated(p);
        case 'comments':
          return await _comments(p);
        case 'upInfo':
          return await _upInfo(p);
        case 'upVideos':
          return await _upVideos(p);
        case 'history':
          return await _history(p);
        case 'favFolders':
          return await _favFolders(p);
        case 'favVideos':
          return await _favVideos(p);
        case 'triple':
          return await _triple(p);
        case 'userInfo':
          return await _userInfo();
        case 'loginStatus':
          return await _loginStatus();
        case 'openPlayer':
          return await _openPlayer(p);
        case 'openLogin':
          return await _openLogin();
        case 'toast':
          return await _toast(p);
        default:
          return {
            'code': -2,
            'message': '未知 action: $action',
          };
      }
    } catch (e) {
      return {
        'code': -1,
        'message': e.toString(),
      };
    }
  }

  // ---------------------------------------------------------------------------
  // 底层网络工具
  // ---------------------------------------------------------------------------

  /// 把各种形态的响应体统一成 Map<String, dynamic>
  static Map<String, dynamic> _normalize(dynamic data) {
    if (data is Map) {
      return data.map((k, v) => MapEntry(k.toString(), v));
    }
    if (data is String && data.isNotEmpty) {
      try {
        final decoded = jsonDecode(data);
        if (decoded is Map) {
          return decoded.map((k, v) => MapEntry(k.toString(), v));
        }
      } catch (_) {}
    }
    return {'code': -1, 'message': 'unexpected response'};
  }

  /// 统一 GET：返回 Map（解析后的 JSON）
  /// 复用 [Request] 单例，自动携带 cookie / buvid 拦截器链
  static Future<Map<String, dynamic>> _get(
    String url, {
    Map<String, dynamic>? queryParameters,
    bool wbi = false,
  }) async {
    try {
      Map<String, dynamic>? params = queryParameters;
      if (wbi && params != null) {
        params = await WbiSign.makSign(
          params.map((k, v) => MapEntry(k, v as Object)),
        );
      }
      final res = await Request().get(url, queryParameters: params);
      return _normalize(res.data);
    } catch (e) {
      return {'code': -1, 'message': e.toString()};
    }
  }

  /// 统一 POST：返回 Map
  static Future<Map<String, dynamic>> _post(
    String url,
    Map<String, dynamic> data, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final res = await Request().post(
        url,
        data: data,
        queryParameters: queryParameters,
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      return _normalize(res.data);
    } catch (e) {
      return {'code': -1, 'message': e.toString()};
    }
  }

  // ---------------------------------------------------------------------------
  // 净化过滤
  // ---------------------------------------------------------------------------

  /// 从 item 中尝试提取 title / upName / duration 用于净化
  static _VidMeta? _extractMeta(dynamic item) {
    if (item is! Map) return null;
    final m = item as Map<String, dynamic>;

    String? title;
    // 常见 title 字段
    if (m['title'] is String) title = m['title'] as String;
    if (title == null && m['bvid'] != null) {
      // 某些列表 title 存储在 archive 子对象
      final archive = m['archive'];
      if (archive is Map && archive['title'] is String) {
        title = archive['title'] as String;
      }
    }
    if (title == null || title.isEmpty) return null; // 没有标题就不参与净化

    // upName
    String? upName;
    final author = m['author'];
    if (author is Map && author['name'] is String) {
      upName = author['name'] as String;
    } else if (m['up'] is Map && (m['up'] as Map)['name'] is String) {
      upName = (m['up'] as Map)['name'] as String;
    } else if (m['owner'] is Map && (m['owner'] as Map)['name'] is String) {
      upName = (m['owner'] as Map)['name'] as String;
    } else if (m['up_name'] is String) {
      upName = m['up_name'] as String;
    } else if (m['uname'] is String) {
      upName = m['uname'] as String;
    } else if (m['upper'] is Map && (m['upper'] as Map)['name'] is String) {
      upName = (m['upper'] as Map)['name'] as String;
    }

    // duration：可能是秒数 (int/double/String) 或 "MM:SS" 字符串
    int duration = 0;
    if (m['duration'] != null) {
      final d = m['duration'];
      if (d is int) {
        duration = d;
      } else if (d is double) {
        duration = d.toInt();
      } else if (d is String) {
        duration = _parseDurationString(d);
      }
    }
    if (duration == 0 && m['length'] != null) {
      final d = m['length'];
      if (d is int) {
        duration = d;
      } else if (d is double) {
        duration = d.toInt();
      } else if (d is String) {
        duration = _parseDurationString(d);
      }
    }
    // history 中 duration_seconds
    if (duration == 0 && m['duration_seconds'] != null) {
      final d = m['duration_seconds'];
      if (d is int) duration = d;
      if (d is double) duration = d.toInt();
    }

    return _VidMeta(title: title, upName: upName, duration: duration);
  }

  /// 把 "MM:SS" / "HH:MM:SS" 转成秒
  static int _parseDurationString(String s) {
    try {
      final parts = s.split(':');
      if (parts.length == 2) {
        final m = int.tryParse(parts[0]) ?? 0;
        final sec = int.tryParse(parts[1]) ?? 0;
        return m * 60 + sec;
      } else if (parts.length == 3) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        final sec = int.tryParse(parts[2]) ?? 0;
        return h * 3600 + m * 60 + sec;
      }
    } catch (_) {}
    return 0;
  }

  /// 在 response 里递归找到视频列表并逐个净化。直接修改传入的 map。
  static void _purifyInPlace(Map<String, dynamic> resp) {
    if (!Purification.anyEnabled) return;
    final List<dynamic> candidates = [];

    if (resp['result'] is List) candidates.add(resp['result']);
    final data = resp['data'];
    if (data is Map) {
      if (data['list'] is List) candidates.add(data['list']);
      if (data['vlist'] is List) candidates.add(data['vlist']);
      if (data['archives'] is List) candidates.add(data['archives']);
      if (data['items'] is List) candidates.add(data['items']);
      if (data['records'] is List) candidates.add(data['records']);
      if (data['folders'] is List) candidates.add(data['folders']);
      if (data['has_more'] != null && data['cursor'] != null) {
        // 动态流结构（follow 等）— 常见 item 层级
        // 某些动态：data.items 本身就是列表
      }
    }

    for (final list in candidates) {
      _filterList(list);
    }
  }

  static void _filterList(List<dynamic> list) {
    // 从后往前删，方便
    for (int i = list.length - 1; i >= 0; i--) {
      final item = list[i];
      final meta = _extractMeta(item);
      if (meta == null) continue; // 没有视频标题则不处理（非视频项）
      final hit = Purification.evaluate(
        title: meta.title,
        upName: meta.upName,
        duration: meta.duration,
      );
      if (hit != null) {
        Purification.record(hit, title: meta.title);
        list.removeAt(i);
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 具体 action 实现
  // ---------------------------------------------------------------------------

  /// demo 前端所有发往 api.bilibili.com 的 fetch/XHR 都转发到这里，
  /// 复用 PiliPlus 的原生网络栈（cookie / buvid / 签名）取真实数据。
  static Future<Map<String, dynamic>> _proxy(Map<String, dynamic> p) async {
    final raw = (p['url'] as String? ?? '').trim();
    if (raw.isEmpty) return {'code': -1, 'message': '缺少 url'};

    Uri uri;
    try {
      uri = Uri.parse(raw);
    } catch (_) {
      return {'code': -1, 'message': 'invalid url: $raw'};
    }
    final path = uri.path.isEmpty ? '/' : uri.path;
    final qp = <String, dynamic>{};
    uri.queryParameters.forEach((k, v) => qp[k] = v);

    final method = (p['method'] as String? ?? 'GET').toUpperCase();
    Map<String, dynamic> resp;
    if (method == 'POST') {
      final data = <String, dynamic>{};
      final body = p['body'] as String?;
      if (body != null && body.isNotEmpty) {
        try {
          Uri.splitQueryString(body).forEach((k, v) => data[k] = v);
        } catch (_) {}
      }
      resp = await _post(path, data, queryParameters: qp.isEmpty ? null : qp);
    } else {
      resp = await _get(
        path,
        queryParameters: qp.isEmpty ? null : qp,
        wbi: _needWbi(path),
      );
    }
    // 净化过滤交由 demo 前端自带的引擎完成（其看板 / 拦截日志 / 规则设置
    // 都基于未过滤的原始列表），此层只负责取真实数据，避免双重过滤。
    return resp;
  }

  /// 需要 wbi 签名的接口（demo 直接裸调，由原生补上签名）
  static bool _needWbi(String path) {
    if (path.contains('/wbi/')) return true;
    const wbiPaths = {
      '/x/web-interface/search/type',
      '/x/web-interface/search/all/v2',
      '/x/web-interface/view',
      '/x/space/arc/search',
      '/x/space/acc/info',
      '/x/v2/reply/wbi/main',
    };
    return wbiPaths.contains(path);
  }

  /// 当前登录用户信息（供 demo 账号层使用）
  static Future<Map<String, dynamic>> _whoami() async {
    final acc = Accounts.main;
    if (!acc.isLogin) return {'isLogin': false};

    final resp = await _get('/x/web-interface/nav');
    var name = '';
    var face = '';
    var level = 0;
    var vip = false;
    num coin = 0;
    final data = resp['data'];
    if (data is Map) {
      if (data['uname'] is String) name = data['uname'] as String;
      if (data['face'] is String) face = data['face'] as String;
      final li = data['level_info'];
      if (li is Map && li['current_level'] is num) {
        level = (li['current_level'] as num).toInt();
      }
      vip = data['vipStatus'] == 1;
      if (data['money'] is num) coin = data['money'] as num;
    }
    return {
      'isLogin': true,
      'name': name,
      'username': name,
      'mid': acc.mid,
      'face': face,
      'level': level,
      'vip': vip,
      'coin': coin,
    };
  }

  /// 登出当前主账号
  static Future<Map<String, dynamic>> _logout() async {
    try {
      final main = Accounts.main;
      if (main is LoginAccount) {
        try {
          await LoginHttp.logout(main);
        } catch (_) {}
      }
      await Accounts.deleteAll({Accounts.main});
    } catch (e) {
      return {'ok': false, 'message': e.toString()};
    }
    return {'ok': true};
  }

  /// 生成扫码登录二维码（返回二维码内容与轮询用 authCode）
  static Future<Map<String, dynamic>> _loginQr() async {
    final res = await LoginHttp.getHDcode();
    if (res case Success(:final response)) {
      return {'url': response.url, 'authCode': response.authCode};
    }
    return {'code': -1, 'message': '二维码获取失败'};
  }

  /// 轮询扫码状态；成功时把账号写入原生并切为主账号
  static Future<Map<String, dynamic>> _loginPoll(Map<String, dynamic> p) async {
    final authCode = p['authCode'] as String? ?? '';
    if (authCode.isEmpty) return {'code': -1, 'message': '缺少 authCode'};

    final r = await LoginHttp.codePoll(authCode);
    if (r['status'] == true) {
      try {
        final data = r['data'];
        if (data is Map) {
          final cookieInfo = data['cookie_info'];
          final cookies = cookieInfo is Map ? cookieInfo['cookies'] : null;
          if (cookies is List) {
            final account = LoginAccount(
              BiliCookieJar.fromList(cookies),
              data['access_token'] as String?,
              data['refresh_token'] as String?,
            );
            // 设为主账号：内部会同步 WebView cookie 并拉取用户信息
            await Accounts.set(AccountType.main, account);
          }
        }
      } catch (_) {}
    }
    return {'status': r['status'] == true, 'code': r['code'], 'msg': r['msg']};
  }

  /// 刘海/安全区：正文已由 Flutter 层整体下移，WebView 内无需再补，
  /// 返回 0 防止与 demo 自带的 env(safe-area-inset-*) 重复叠加。
  static Future<Map<String, dynamic>> _deviceInset() async {
    return {'top': 0, 'bottom': 0};
  }

  static Future<Map<String, dynamic>> _home(Map<String, dynamic> p) async {
    final pn = (p['pn'] as num?)?.toInt() ?? 1;
    final resp = await _get(
      '/x/web-interface/popular',
      queryParameters: {'ps': 20, 'pn': pn},
    );
    _purifyInPlace(resp);
    return resp;
  }

  static Future<Map<String, dynamic>> _follow(Map<String, dynamic> p) async {
    // 主关注动态流，host_mid=0 表示当前登录用户
    final resp = await _get(
      '/x/polymer/web-dynamic/v1/feed/space',
      queryParameters: {'host_mid': 0},
    );
    // follow 动态的数据结构比较特殊：data.items 里嵌套 modules.module_dynamic
    if (Purification.anyEnabled) {
      final data = resp['data'];
      if (data is Map && data['items'] is List) {
        final items = data['items'] as List;
        for (int i = items.length - 1; i >= 0; i--) {
          final dyn = items[i];
          final title = _dynTitle(dyn);
          final upName = _dynUpName(dyn);
          if (title == null || title.isEmpty) continue;
          final hit = Purification.evaluate(
            title: title,
            upName: upName,
            duration: 0,
          );
          if (hit != null) {
            Purification.record(hit, title: title);
            items.removeAt(i);
          }
        }
      }
    }
    return resp;
  }

  static String? _dynTitle(dynamic dyn) {
    if (dyn is! Map) return null;
    final modules = dyn['modules'];
    if (modules is Map) {
      final md = modules['module_dynamic'];
      if (md is Map) {
        final major = md['major'];
        if (major is Map) {
          final archive = major['archive'];
          if (archive is Map && archive['title'] is String) {
            return archive['title'] as String;
          }
          final draw = major['draw'];
          if (draw is Map) {
            final items = draw['items'];
            if (items is List && items.isNotEmpty) return '（动态图文）';
          }
          final article = major['article'];
          if (article is Map && article['title'] is String) {
            return article['title'] as String;
          }
        }
        final desc = md['desc'];
        if (desc is Map && desc['text'] is String) {
          return desc['text'] as String;
        }
      }
    }
    return null;
  }

  static String? _dynUpName(dynamic dyn) {
    if (dyn is! Map) return null;
    final modules = dyn['modules'];
    if (modules is Map) {
      final mi = modules['module_info'];
      if (mi is Map && mi['name'] is String) {
        return mi['name'] as String;
      }
    }
    return null;
  }

  static Future<Map<String, dynamic>> _regionList() async {
    return await _get('/x/web-interface/region');
  }

  static Future<Map<String, dynamic>> _region(Map<String, dynamic> p) async {
    final rid = (p['rid'] as num?)?.toInt();
    final pn = (p['pn'] as num?)?.toInt() ?? 1;
    if (rid == null) {
      return {'code': -1, 'message': '缺少 rid'};
    }
    final resp = await _get(
      '/x/web-interface/dynamic/region',
      queryParameters: {'rid': rid, 'ps': 20, 'pn': pn},
    );
    _purifyInPlace(resp);
    return resp;
  }

  static Future<Map<String, dynamic>> _searchHot() async {
    return await _get(
      '/x/web-interface/search/square',
      queryParameters: {'limit': 50},
    );
  }

  static Future<Map<String, dynamic>> _search(Map<String, dynamic> p) async {
    final keyword = p['keyword'] as String? ?? '';
    final pn = (p['pn'] as num?)?.toInt() ?? 1;
    if (keyword.isEmpty) {
      return {'code': -1, 'message': '缺少 keyword'};
    }
    final resp = await _get(
      '/x/web-interface/wbi/search/type',
      queryParameters: {
        'search_type': 'video',
        'keyword': keyword,
        'page': pn,
        'page_size': 20,
      },
      wbi: true,
    );
    _purifyInPlace(resp);
    return resp;
  }

  static Future<Map<String, dynamic>> _video(Map<String, dynamic> p) async {
    final bvid = p['bvid'] as String?;
    final aid = p['aid'];
    Map<String, dynamic> qp = {};
    if (bvid != null) qp['bvid'] = bvid;
    if (aid != null) qp['aid'] = aid;
    if (qp.isEmpty) return {'code': -1, 'message': '缺少 bvid/aid'};
    return await _get('/x/web-interface/wbi/view', queryParameters: qp, wbi: true);
  }

  static Future<Map<String, dynamic>> _videoRelated(
    Map<String, dynamic> p,
  ) async {
    final bvid = p['bvid'] as String?;
    if (bvid == null) return {'code': -1, 'message': '缺少 bvid'};
    final resp = await _get(
      '/x/web-interface/archive/related',
      queryParameters: {'bvid': bvid},
    );
    _purifyInPlace(resp);
    return resp;
  }

  static Future<Map<String, dynamic>> _comments(Map<String, dynamic> p) async {
    final oid = (p['oid'] as num?)?.toInt();
    final pn = (p['pn'] as num?)?.toInt() ?? 1;
    if (oid == null) return {'code': -1, 'message': '缺少 oid'};
    return await _get(
      '/x/v2/reply',
      queryParameters: {'type': 1, 'oid': oid, 'sort': 1, 'ps': 20, 'pn': pn},
    );
  }

  static Future<Map<String, dynamic>> _upInfo(Map<String, dynamic> p) async {
    final mid = (p['mid'] as num?)?.toInt();
    if (mid == null) return {'code': -1, 'message': '缺少 mid'};
    return await _get(
      '/x/space/wbi/acc/info',
      queryParameters: {'mid': mid},
      wbi: true,
    );
  }

  static Future<Map<String, dynamic>> _upVideos(Map<String, dynamic> p) async {
    final mid = (p['mid'] as num?)?.toInt();
    final pn = (p['pn'] as num?)?.toInt() ?? 1;
    if (mid == null) return {'code': -1, 'message': '缺少 mid'};
    final resp = await _get(
      '/x/space/wbi/arc/search',
      queryParameters: {
        'mid': mid,
        'ps': 20,
        'pn': pn,
        'order': 'pubdate',
      },
      wbi: true,
    );
    _purifyInPlace(resp);
    return resp;
  }

  static Future<Map<String, dynamic>> _history(Map<String, dynamic> p) async {
    final pn = (p['pn'] as num?)?.toInt() ?? 1;
    final ps = (p['ps'] as num?)?.toInt() ?? 20;
    return await _get(
      '/x/v2/history',
      queryParameters: {'ps': ps, 'pn': pn},
    );
  }

  static Future<Map<String, dynamic>> _favFolders(Map<String, dynamic> p) async {
    final mid = (p['mid'] as num?)?.toInt() ?? Accounts.main.mid;
    return await _get(
      '/x/v3/fav/folder/created/list-all',
      queryParameters: {'up_mid': mid},
    );
  }

  static Future<Map<String, dynamic>> _favVideos(Map<String, dynamic> p) async {
    final mediaId = (p['mediaId'] as num?)?.toInt();
    final pn = (p['pn'] as num?)?.toInt() ?? 1;
    if (mediaId == null) return {'code': -1, 'message': '缺少 mediaId'};
    final resp = await _get(
      '/x/v3/fav/resource/list',
      queryParameters: {
        'media_id': mediaId,
        'pn': pn,
        'ps': 20,
      },
    );
    _purifyInPlace(resp);
    return resp;
  }

  static Future<Map<String, dynamic>> _triple(Map<String, dynamic> p) async {
    final bvid = p['bvid'] as String?;
    final aid = p['aid'];
    if (bvid == null && aid == null) {
      return {'code': -1, 'message': '缺少 bvid/aid'};
    }
    return await _post(
      '/x/web-interface/archive/like/triple',
      {
        if (bvid != null) 'bvid': bvid,
        if (aid != null) 'aid': aid,
        'coin_type': 2,
        'multisel': true,
        'csrf': Accounts.main.csrf,
      },
    );
  }

  static Future<Map<String, dynamic>> _userInfo() async {
    return await _get('/x/web-interface/nav');
  }

  static Future<Map<String, dynamic>> _loginStatus() async {
    try {
      final isLogin = Accounts.main.isLogin;
      final mid = Accounts.main.mid;
      String name = '';
      String face = '';
      // 尝试从缓存读用户信息
      final resp = await _userInfo();
      if (resp['code'] == 0 && resp['data'] is Map) {
        final d = resp['data'] as Map;
        final uname = d['uname'];
        final f = d['face'];
        if (uname is String) name = uname;
        if (f is String) face = f;
      }
      return {
        'code': 0,
        'message': 'ok',
        'data': {
          'isLogin': isLogin,
          'name': name,
          'mid': mid,
          'face': face,
        },
      };
    } catch (e) {
      return {
        'code': 0,
        'message': 'ok',
        'data': {
          'isLogin': Accounts.main.isLogin,
          'name': '',
          'mid': Accounts.main.mid,
          'face': '',
        },
      };
    }
  }

  static Future<Map<String, dynamic>> _openPlayer(Map<String, dynamic> p) async {
    final aid = p['aid'] != null ? (p['aid'] as num).toInt() : null;
    final bvid = p['bvid'] as String?;
    PiliScheme.videoPush(aid, bvid);
    return {'ok': true};
  }

  static Future<Map<String, dynamic>> _openLogin() async {
    try {
      Get.to(() => const LoginPage());
      return {'ok': true};
    } catch (e) {
      return {'ok': false, 'message': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> _toast(Map<String, dynamic> p) async {
    final msg = p['msg']?.toString() ?? '';
    if (msg.isNotEmpty) SmartDialog.showToast(msg);
    return {'ok': true};
  }
}

class _VidMeta {
  final String title;
  final String? upName;
  final int duration;
  _VidMeta({required this.title, this.upName, required this.duration});
}
