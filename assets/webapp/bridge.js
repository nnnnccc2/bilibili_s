/* ------------------------------------------------------------------
 * PiliPlus × 参考 demo 前端 的注入桥
 *
 * 目标：保留 demo 的 1:1 界面与它自带的净化引擎（标题党/侮辱词库/时长/
 *       日文过滤 + 看板 + 拦截日志），只把「数据来源」与「账号」换成
 *       PiliPlus 原生能力：
 *   - 网络层：demo 里所有发往 api.bilibili.com 的 fetch 请求，
 *            统一交给原生（复用 PiliPlus 的 Request.dio，自带
 *            登录 cookie / buvid / WBI 签名拦截器链），返回原始 JSON。
 *   - 账号层：登录 / 登出 / 用户信息 / 浏览历史，走原生真实账号。
 *   - 安全区：viewport-fit=cover + env() 兜底。
 *
 * 该脚本必须在业务 bundle 之前执行，因此是同步脚本。
 * ------------------------------------------------------------------ */
(function () {
  'use strict';

  // ==================================================================
  // 0. 与原生通信
  // ==================================================================
  function ppCall(action, params) {
    return new Promise(function (resolve) {
      var tries = 0;
      (function attempt() {
        var bridge = window.flutter_inappwebview;
        if (bridge && typeof bridge.callHandler === 'function') {
          Promise.resolve(
            bridge.callHandler('biliApi', { action: action, params: params || {} })
          )
            .then(function (r) { resolve(r); })
            .catch(function (e) { resolve({ code: -1, message: String(e) }); });
        } else if (++tries < 200) {
          setTimeout(attempt, 25);
        } else {
          resolve({ code: -1, message: 'native bridge unavailable' });
        }
      })();
    });
  }
  window.__ppCall = ppCall;

  // ==================================================================
  // 1. 网络层：B 站 API -> 原生
  // ==================================================================
  var API_RE = /^https?:\/\/api\.bilibili\.com\//i;
  var origFetch = window.fetch ? window.fetch.bind(window) : null;

  function jsonResponse(obj) {
    var text;
    try {
      text = JSON.stringify(obj === undefined ? null : obj);
    } catch (e) {
      text = '{"code":-1,"message":"serialize error"}';
    }
    return new Response(text, {
      status: 200,
      statusText: 'OK',
      headers: { 'Content-Type': 'application/json; charset=utf-8' },
    });
  }

  window.fetch = function (input, init) {
    var url = '';
    try {
      url = typeof input === 'string' ? input : ((input && input.url) || '');
    } catch (e) {}

    if (url && API_RE.test(url)) {
      var method = (init && init.method) || 'GET';
      var body = null;
      try {
        if (init && init.body != null && typeof init.body === 'string') {
          body = init.body;
        }
      } catch (e) {}
      // 故意忽略 init.signal：demo 里带了 2s 超时 Abort，
      // 一旦超时它会退回 mock 数据，这里要保证始终拿到真实数据。
      return ppCall('proxy', { url: url, method: method, body: body }).then(
        jsonResponse,
        function (e) { return jsonResponse({ code: -1, message: String(e) }); }
      );
    }
    if (origFetch) return origFetch(input, init);
    return Promise.reject(new Error('fetch is unavailable'));
  };

  // XMLHttpRequest 兜底（以防某些库走 XHR）
  var OrigXHR = window.XMLHttpRequest;
  if (OrigXHR && OrigXHR.prototype) {
    var open = OrigXHR.prototype.open;
    var send = OrigXHR.prototype.send;
    OrigXHR.prototype.open = function (method, url) {
      this.__ppUrl = url;
      this.__ppMethod = method || 'GET';
      return open.apply(this, arguments);
    };
    OrigXHR.prototype.send = function (body) {
      var url = this.__ppUrl || '';
      if (url && API_RE.test(url)) {
        var xhr = this;
        this.__ppBody = typeof body === 'string' ? body : null;
        var setJson = function (obj) {
          try {
            Object.defineProperty(xhr, 'readyState', { value: 4, configurable: true });
            Object.defineProperty(xhr, 'status', { value: 200, configurable: true });
            Object.defineProperty(xhr, 'responseText', { value: JSON.stringify(obj), configurable: true });
            Object.defineProperty(xhr, 'response', { value: JSON.stringify(obj), configurable: true });
          } catch (e) {}
          if (typeof xhr.onreadystatechange === 'function') xhr.onreadystatechange();
          if (typeof xhr.onload === 'function') xhr.onload();
        };
        ppCall('proxy', { url: url, method: this.__ppMethod, body: this.__ppBody }).then(setJson);
        return;
      }
      return send.apply(this, arguments);
    };
  }

  // ==================================================================
  // 2. 账号层：登录 / 用户 / 历史
  // ==================================================================
  function mapUser(r) {
    if (!r || !r.isLogin) return null;
    var name = r.name || 'bilibili 用户';
    return {
      id: 'u_' + (r.mid || 'anon'),
      username: r.username || name,
      nickname: name,
      avatar: r.face || '',
      level: typeof r.level === 'number' ? r.level : 0,
      isVip: !!r.vip,
      phone: r.phone || '已绑定手机',
      coinCount: typeof r.coin === 'number' ? r.coin : 0,
    };
  }

  window.__pureWhoami = function () {
    return ppCall('whoami').then(mapUser, function () { return null; });
  };

  function fmtDur(sec) {
    sec = parseInt(sec, 10) || 0;
    var h = Math.floor(sec / 3600);
    var m = Math.floor((sec % 3600) / 60);
    var s = sec % 60;
    var mm = (m < 10 ? '0' : '') + m;
    var ss = (s < 10 ? '0' : '') + s;
    return h > 0 ? h + ':' + mm + ':' + ss : mm + ':' + ss;
  }

  window.__pureHistory = function () {
    return ppCall('history', { pn: 1, ps: 50 }).then(
      function (r) {
        var list = (r && r.data && r.data.list) || [];
        return list.map(function (it, i) {
          it = it || {};
          var owner = it.owner || {};
          var dur = it.duration || 0;
          var prog = it.progress || 0;
          var viewAt = it.view_at || 0;
          return {
            id: 'h_' + (it.kid || i),
            videoId: it.bvid || (it.history && it.history.bvid) || '',
            title: it.title || '',
            cover: it.cover || it.pic || '',
            authorName: owner.name || it.author_name || '',
            durationFormatted: fmtDur(dur),
            watchedAt: viewAt ? viewAt * 1000 : Date.now(),
            watchedAtFormatted: viewAt
              ? new Date(viewAt * 1000).toLocaleString('zh-CN', {
                  month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit',
                })
              : '刚刚',
            progressPercent: dur > 0 ? Math.min(100, Math.round((prog / dur) * 100)) : 20,
          };
        });
      },
      function () { return []; }
    );
  };

  window.__pureLogout = function () {
    ppCall('logout');
  };

  // 扫码登录：在页面内浮层完成，不再跳转 Flutter 登录页
  window.__pureLogin = function () {
    return new Promise(function (resolve) {
      if (document.getElementById('__pp_login_mask')) {
        resolve({ success: false, message: '正在登录中…' });
        return;
      }

      var mask = document.createElement('div');
      mask.id = '__pp_login_mask';
      mask.setAttribute(
        'style',
        'position:fixed;inset:0;z-index:2147483647;background:rgba(15,23,42,.55);' +
          'display:flex;align-items:center;justify-content:center;' +
          '-webkit-backdrop-filter:blur(4px);backdrop-filter:blur(4px);'
      );
      mask.innerHTML =
        '<div style="width:290px;box-sizing:border-box;background:#fff;border-radius:20px;' +
        'padding:22px 18px 18px;text-align:center;box-shadow:0 18px 50px rgba(0,0,0,.35);' +
        'font-family:-apple-system,BlinkMacSystemFont,\'PingFang SC\',sans-serif">' +
        '<div style="font-size:17px;font-weight:800;color:#0f172a">扫码登录</div>' +
        '<div style="font-size:11px;color:#64748b;margin:4px 0 14px">请使用「哔哩哔哩」客户端扫一扫</div>' +
        '<div id="__pp_qr" style="width:200px;height:200px;margin:0 auto;display:flex;' +
        'align-items:center;justify-content:center;background:#f8fafc;border-radius:12px;' +
        'color:#94a3b8;font-size:12px">二维码生成中…</div>' +
        '<div id="__pp_qr_status" style="font-size:12px;color:#0ea5e9;margin-top:12px;' +
        'min-height:16px;font-weight:600"></div>' +
        '<div style="margin-top:16px;display:flex;gap:10px;justify-content:center">' +
        '<button id="__pp_qr_refresh" style="border:none;background:#f1f5f9;color:#334155;' +
        'font-size:12px;font-weight:600;padding:9px 16px;border-radius:999px">刷新</button>' +
        '<button id="__pp_qr_close" style="border:none;background:#e2e8f0;color:#334155;' +
        'font-size:12px;font-weight:600;padding:9px 16px;border-radius:999px">取消</button>' +
        '</div></div>';
      document.body.appendChild(mask);

      var finished = false;
      var timer = null;

      function done(result) {
        if (finished) return;
        finished = true;
        if (timer) clearTimeout(timer);
        var el = document.getElementById('__pp_login_mask');
        if (el && el.parentNode) el.parentNode.removeChild(el);
        resolve(result || { success: false, message: '已取消' });
      }

      function status(t) {
        var el = document.getElementById('__pp_qr_status');
        if (el) el.textContent = t;
      }

      function renderQr(url) {
        var box = document.getElementById('__pp_qr');
        try {
          var qr = window.qrcode(0, 'M');
          qr.addData(url);
          qr.make();
          box.innerHTML = qr.createSvgTag({ cellSize: 5, margin: 4, scalable: true });
        } catch (e) {
          box.textContent = '二维码渲染失败';
        }
      }

      function poll(authCode) {
        if (finished) return;
        ppCall('loginPoll', { authCode: authCode }).then(function (r) {
          if (finished) return;
          if (r && r.status) {
            status('登录成功，正在同步…');
            window.__pureWhoami().then(function (u) {
              done({ success: true, user: u });
            });
            return;
          }
          if (r && r.code === 86038) {
            status('二维码已过期，请点击刷新');
            return;
          }
          if (r && r.code === 86090) {
            status('已扫码，请在手机上确认');
          } else {
            status('等待扫码…');
          }
          timer = setTimeout(function () { poll(authCode); }, 1500);
        });
      }

      function start() {
        status('');
        var box = document.getElementById('__pp_qr');
        if (box) box.textContent = '二维码生成中…';
        ppCall('loginQr').then(function (r) {
          if (finished) return;
          if (!r || !r.url) {
            status('二维码获取失败，请重试');
            return;
          }
          renderQr(r.url);
          status('等待扫码…');
          poll(r.authCode);
        });
      }

      document.getElementById('__pp_qr_close').onclick = function () {
        done({ success: false, message: '已取消登录' });
      };
      document.getElementById('__pp_qr_refresh').onclick = start;

      start();
    });
  };

  // ==================================================================
  // 3. 安全区兜底
  //    demo 自身用 useSafeAreaInsets + env(safe-area-inset-*)，配合
  //    viewport-fit=cover 即可正常工作；若个别环境 env() 取不到值，
  //    用原生上报的刘海高度补一个 padding，二者互斥、不会叠加。
  // ==================================================================
  function envTop() {
    try {
      var probe = document.createElement('div');
      probe.setAttribute(
        'style',
        'position:fixed;top:0;left:0;height:0;visibility:hidden;' +
          'padding-top:constant(safe-area-inset-top);padding-top:env(safe-area-inset-top);'
      );
      document.body.appendChild(probe);
      var v = parseFloat(window.getComputedStyle(probe).paddingTop) || 0;
      probe.parentNode.removeChild(probe);
      return v;
    } catch (e) {
      return 0;
    }
  }

  function applySafeAreaFallback() {
    if (envTop() > 0) return; // env() 可用，无需兜底
    ppCall('deviceInset').then(function (r) {
      var top = (r && r.top) || 0;
      if (top > 0 && envTop() === 0) {
        var root = document.getElementById('root');
        if (root) root.style.paddingTop = Math.round(top) + 'px';
      }
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', applySafeAreaFallback);
  } else {
    setTimeout(applySafeAreaFallback, 0);
  }

  // 就绪信号
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', function () {
      ppCall('toast', { msg: '' , silent: true });
    });
  }
})();
