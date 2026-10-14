/* ========================================================
 * PiliPlus Webapp —— 原生 JS 前端
 * 所有 Bilibili 调用通过 window.flutter_inappwebview.callHandler('biliApi', ...)
 * 桥接到 lib/utils/bili_api.dart
 * ======================================================== */
(function () {
  'use strict';

  // ---------- 调试模式（无桥接时用 mock 数据方便浏览器调试）----------
  const DEBUG = false;

  // ---------- JS Bridge 封装 ----------
  function bridgeCall(action, params) {
    if (DEBUG) return mockCall(action, params);
    // flutter_inappwebview
    const bridge = window.flutter_inappwebview;
    if (!bridge || typeof bridge.callHandler !== 'function') {
      return Promise.reject(new Error('JS Bridge 未就绪'));
    }
    return bridge.callHandler('biliApi', { action, params: params || {} });
  }

  // ---------- DOM 工具 ----------
  const $ = (sel, root = document) => root.querySelector(sel);
  function el(tag, attrs = {}, children = []) {
    const n = document.createElement(tag);
    for (const [k, v] of Object.entries(attrs)) {
      if (k === 'class') n.className = v;
      else if (k === 'style') Object.assign(n.style, v);
      else if (k.startsWith('on') && typeof v === 'function') {
        n.addEventListener(k.slice(2).toLowerCase(), v);
      } else if (k === 'dataset') {
        for (const [dk, dv] of Object.entries(v)) n.dataset[dk] = dv;
      } else if (v !== false && v != null) n.setAttribute(k, v);
    }
    for (const c of [].concat(children)) {
      if (c == null || c === false) continue;
      n.appendChild(typeof c === 'string' ? document.createTextNode(c) : c);
    }
    return n;
  }

  // ---------- 全局状态 ----------
  const state = {
    pn: {},           // 各 tab 当前页码
    lists: {},        // 已缓存的列表
    loginStatus: null,
    currentRoute: null,
    regionActive: 1,
  };

  // ---------- 路由 ----------
  const routes = {
    '/home': renderHome,
    '/follow': renderFollow,
    '/region': renderRegion,
    '/search': renderSearch,
    '/mine': renderMine,
    '/video': renderVideo,       // #/video?bvid=...&aid=...
    '/up': renderUp,             // #/up?mid=...
    '/fav': renderFav,           // #/fav (先列收藏夹) / #/fav?mediaId=...
    '/history': renderHistory,
  };

  function parseHash() {
    const raw = (location.hash || '#/home').replace(/^#/, '');
    const [path, qs] = raw.split('?');
    const query = {};
    if (qs) qs.split('&').forEach(kv => {
      const [k, v] = kv.split('=');
      query[decodeURIComponent(k)] = decodeURIComponent(v || '');
    });
    return { path: path || '/home', query };
  }

  function navigate(hash) {
    location.hash = hash;
  }

  function onHashChange() {
    const { path, query } = parseHash();
    state.currentRoute = { path, query };
    // 更新底导航 active
    document.querySelectorAll('.nav-item').forEach(a => {
      a.classList.toggle('active', a.dataset.tab === path.slice(1));
    });
    // Hero 标题/子标题
    const titleMap = {
      '/home': { title: 'PiliPlus', sub: '热门推荐', showSearch: false },
      '/follow': { title: '动态', sub: '我关注的人', showSearch: false },
      '/region': { title: '分区', sub: '选择频道', showSearch: false },
      '/search': { title: '搜索', sub: '', showSearch: true },
      '/mine': { title: '我的', sub: '', showSearch: false },
      '/video': { title: '', sub: '', showSearch: false },
      '/up': { title: 'UP主', sub: '', showSearch: false },
      '/fav': { title: '收藏', sub: '', showSearch: false },
      '/history': { title: '历史记录', sub: '', showSearch: false },
    };
    const conf = titleMap[path] || { title: '', sub: '', showSearch: false };
    $('#hero-title').textContent = conf.title;
    $('#hero-sub').textContent = conf.sub;
    $('#hero-search').classList.toggle('hidden', !conf.showSearch);

    const page = $('#page');
    page.innerHTML = '';
    const fn = routes[path] || renderHome;
    Promise.resolve(fn(query)).catch(err => {
      showError(page, err.message || String(err));
    });
  }

  // ---------- Loading / Error ----------
  function showLoading(page) {
    const div = el('div', { class: 'loading' }, '加载中...');
    page.innerHTML = ''; page.appendChild(div);
  }
  function showError(page, msg) {
    page.innerHTML = '';
    page.appendChild(el('div', { class: 'error' }, msg));
  }
  function showBridgeError(page) {
    page.innerHTML = '';
    page.appendChild(el('div', { class: 'error' },
      ['无法与原生后端通信。请在 PiliPlus 内嵌 WebView 中运行。']));
  }

  // ---------- 卡片渲染 ----------
  function fmtDuration(sec) {
    sec = parseInt(sec, 10); if (!sec || sec <= 0) return '';
    const m = Math.floor(sec / 60), s = sec % 60;
    if (m >= 60) {
      const h = Math.floor(m / 60), mm = m % 60;
      return `${h}:${String(mm).padStart(2,'0')}:${String(s).padStart(2,'0')}`;
    }
    return `${m}:${String(s).padStart(2,'0')}`;
  }

  // 从 item 中统一抽取通用字段
  function pickVid(item) {
    if (!item || typeof item !== 'object') return null;
    const bvid = item.bvid || (item.archive && item.archive.bvid) || '';
    const aid = item.aid || (item.archive && item.archive.aid) || (item.id && item.id !== bvid ? item.id : null);
    const title = item.title || (item.archive && item.archive.title) || '';
    const upName = (item.owner && item.owner.name) ||
      (item.author && item.author.name) ||
      (item.up && item.up.name) ||
      item.up_name || item.uname || '';
    const pic = item.pic || item.cover || (item.archive && item.archive.cover) || '';
    let duration = item.duration || item.duration_seconds || 0;
    if (typeof duration === 'string' && !/^\d+$/.test(duration)) {
      duration = 0; // "MM:SS" 不做简单转换（后端已处理过，前端可再尝试但先留空）
    }
    return { bvid, aid, title, upName, pic, duration };
  }

  function renderVideoCard(item, size = 'grid') {
    const v = pickVid(item);
    if (!v || !v.bvid && !v.aid) return null;
    const card = el('a', {
      class: 'card',
      href: `#/video?bvid=${encodeURIComponent(v.bvid || '')}&aid=${encodeURIComponent(v.aid || '')}`,
    });
    const thumb = el('div', { class: 'card-thumb' });
    if (v.pic) {
      const img = el('img', { src: v.pic, alt: '', loading: 'lazy' });
      img.addEventListener('error', () => { img.style.visibility = 'hidden'; });
      thumb.appendChild(img);
    }
    if (v.duration) thumb.appendChild(el('div', { class: 'card-duration' }, fmtDuration(v.duration)));
    card.appendChild(thumb);
    const body = el('div', { class: 'card-body' }, [
      el('div', { class: 'card-title' }, v.title || '(无标题)'),
      v.upName ? el('div', { class: 'card-up' }, v.upName) : null,
    ].filter(Boolean));
    card.appendChild(body);
    return card;
  }

  function renderGrid(items, page, action, paramsForMore) {
    page.innerHTML = '';
    if (!items || !items.length) {
      page.appendChild(el('div', { class: 'error' }, '暂无数据'));
      return;
    }
    const grid = el('div', { class: 'grid' });
    items.forEach(it => {
      const c = renderVideoCard(it);
      if (c) grid.appendChild(c);
    });
    page.appendChild(grid);
    // 上拉加载更多（按钮）
    page.appendChild(el('div', { class: 'load-more' }, [
      el('button', { onclick: () => loadMore(action, paramsForMore, items.length) }, '加载更多'),
    ]));
  }

  async function loadMore(action, baseParams, offset) {
    if (!state.pn[action]) state.pn[action] = 1;
    state.pn[action] = (state.pn[action] || 1) + 1;
    const params = Object.assign({}, baseParams || {}, { pn: state.pn[action] });
    // 不同 action 下 pn 含义不同，这里简单复用 action
    const key = `${action}__${JSON.stringify(baseParams || {})}`;
    const resp = await bridgeCall(action, params);
    const list = extractList(resp);
    if (list && list.length) {
      state.lists[key] = (state.lists[key] || []).concat(list);
      // 重新渲染当前路由
      onHashChange();
    } else {
      const page = $('#page');
      const more = page.querySelector('.load-more');
      if (more) more.textContent = '没有更多了';
    }
  }

  function extractList(resp) {
    if (!resp) return null;
    if (resp.code !== 0) return null;
    const d = resp.data;
    if (!d) return null;
    // 常见层级
    if (Array.isArray(d)) return d;
    if (Array.isArray(d.list)) return d.list;
    if (Array.isArray(d.vlist)) return d.vlist;
    if (Array.isArray(d.archives)) return d.archives;
    if (Array.isArray(d.records)) return d.records;
    if (Array.isArray(d.items)) return d.items;
    if (Array.isArray(d.result)) return d.result;
    return null;
  }

  // ---------- 首页 ----------
  async function renderHome() {
    const page = $('#page');
    showLoading(page);
    const resp = await bridgeCall('home', { pn: state.pn.home || 1 });
    if (resp.code !== 0) return showError(page, resp.message || '请求失败');
    state.pn.home = (state.pn.home || 1) + 1;
    const list = extractList(resp) || [];
    renderGrid(list, page, 'home', {});
  }

  // ---------- 关注动态 ----------
  async function renderFollow() {
    const page = $('#page');
    showLoading(page);
    const resp = await bridgeCall('follow', {});
    if (resp.code !== 0) return showError(page, resp.message || '请求失败');
    const items = (resp.data && Array.isArray(resp.data.items)) ? resp.data.items : [];
    page.innerHTML = '';
    if (!items.length) {
      page.appendChild(el('div', { class: 'error' }, '暂无动态'));
      return;
    }
    const wrap = el('div', { class: 'dyn-list' });
    items.forEach(d => {
      const card = renderDyn(d);
      if (card) wrap.appendChild(card);
    });
    page.appendChild(wrap);
  }

  function renderDyn(d) {
    if (!d || !d.modules) return null;
    const mi = d.modules.module_info || {};
    const md = d.modules.module_dynamic || {};
    const major = md.major || {};

    const card = el('div', { class: 'dyn-card' });
    const head = el('div', { class: 'dyn-head' }, [
      el('img', { class: 'face', src: mi.face || '//', alt: '' }),
      el('span', { class: 'name' }, mi.name || ''),
      el('span', { class: 'time' }, mi.time_text || ''),
    ]);
    card.appendChild(head);

    // 文本
    const text = md.desc && md.desc.text ? md.desc.text : '';
    if (text) card.appendChild(el('div', { class: 'dyn-text' }, text));

    // 视频
    const archive = major.archive;
    if (archive && archive.bvid) {
      const a = el('a', {
        class: 'dyn-archive',
        href: `#/video?bvid=${encodeURIComponent(archive.bvid)}&aid=${archive.aid || ''}`,
      });
      a.appendChild(el('div', { class: 'thumb' }, [
        el('img', { src: archive.cover || '', alt: '' }),
      ]));
      a.appendChild(el('div', { class: 'body' }, [
        el('div', { class: 'title' }, archive.title || ''),
        el('div', { class: 'meta' }, [
          (archive.owner_name || '') + ' · ',
          fmtDuration(archive.duration || 0),
        ].join('')),
      ]));
      card.appendChild(a);
    }

    // 专栏
    if (major.article && major.article.title) {
      card.appendChild(el('div', { class: 'dyn-text' }, '📖 ' + major.article.title));
    }
    return card;
  }

  // ---------- 分区 ----------
  async function renderRegion() {
    const page = $('#page');
    page.innerHTML = '';
    // 分区列表
    let regions = [];
    try {
      const r = await bridgeCall('regionList', {});
      if (r.code === 0 && r.data && Array.isArray(r.data)) {
        regions = r.data; // [ {id, name, children: [...]} ]
      } else if (r.code === 0 && r.data && Array.isArray(r.data.data)) {
        regions = r.data.data;
      }
    } catch (e) { /* 用默认分区 */ }
    if (!regions.length) {
      regions = [
        { id: 1, name: '推荐', children: [] },
        { id: 3, name: '音乐', children: [] },
        { id: 4, name: '游戏', children: [] },
        { id: 5, name: '娱乐', children: [] },
        { id: 11, name: '番剧', children: [] },
        { id: 36, name: '知识', children: [] },
      ];
    }

    const regionPanel = el('div', { class: 'panel' }, [
      el('div', { class: 'panel-title' }, '选择分区'),
      el('div', { class: 'region-grid' }),
    ]);
    const grid = regionPanel.querySelector('.region-grid');
    const subPanel = el('div', { class: 'panel', id: 'region-sub-panel' });

    const loadRegion = (rid) => {
      state.regionActive = rid;
      page.querySelectorAll('.region-item').forEach(n =>
        n.classList.toggle('active', parseInt(n.dataset.rid, 10) === rid));
      bridgeCall('region', { rid, pn: 1 }).then(resp => {
        if (resp.code !== 0) { showError(subPanel, resp.message); return; }
        const list = extractList(resp) || [];
        subPanel.innerHTML = '';
        renderGrid(list, subPanel, 'region', { rid });
      }).catch(err => showError(subPanel, err.message));
    };

    const walkRegion = (rs) => {
      rs.forEach(r => {
        const item = el('button', {
          class: 'region-item' + (state.regionActive === r.id ? ' active' : ''),
          dataset: { rid: String(r.id) },
          onclick: () => loadRegion(r.id),
        }, r.name);
        grid.appendChild(item);
        if (Array.isArray(r.children) && r.children.length) walkRegion(r.children);
      });
    };
    walkRegion(regions);

    page.appendChild(regionPanel);
    page.appendChild(subPanel);
    loadRegion(state.regionActive);
  }

  // ---------- 搜索 ----------
  async function renderSearch() {
    const page = $('#page');
    page.innerHTML = '';
    // 搜索框预置
    const input = $('#search-input');
    input.value = '';
    input.focus();

    // 热门搜索
    const panel = el('div', { class: 'panel' }, [
      el('div', { class: 'panel-title' }, '🔥 热门搜索'),
    ]);
    const listWrap = el('div', { class: 'hot-list' });
    panel.appendChild(listWrap);
    page.appendChild(panel);

    let data = null;
    try {
      const resp = await bridgeCall('searchHot', {});
      if (resp.code === 0 && resp.data) data = resp.data;
    } catch (e) {}
    const keywords = (data && data.tags) || data || [];
    (Array.isArray(keywords) ? keywords : []).forEach((k, i) => {
      const kw = typeof k === 'string' ? k : (k.keyword || '');
      if (!kw) return;
      const rank = i + 1;
      listWrap.appendChild(el('button', {
        class: 'hot-item',
        onclick: () => { input.value = kw; doSearch(kw); },
      }, [
        el('span', { class: 'hot-rank' }, String(rank)),
        el('span', { class: 'hot-keyword' }, kw),
        rank <= 3 ? el('span', { class: 'hot-tag' }, '热') : null,
      ].filter(Boolean)));
    });
  }

  let searchCache = null;
  function doSearch(kw) {
    if (!kw) return;
    state.pn.search = 1;
    $('#hero-sub').textContent = '搜索: ' + kw;
    state.searchKw = kw;
    bridgeCall('search', { keyword: kw, pn: 1 }).then(resp => {
      const page = $('#page');
      if (resp.code !== 0) return showError(page, resp.message);
      const list = extractList(resp) || [];
      page.innerHTML = '';
      renderGrid(list, page, 'search', { keyword: kw });
    }).catch(err => showError($('#page'), err.message));
  }

  // ---------- 视频详情 ----------
  async function renderVideo(q) {
    const page = $('#page');
    showLoading(page);
    const resp = await bridgeCall('video', q);
    if (resp.code !== 0) return showError(page, resp.message || '请求失败');
    const d = resp.data || {};
    const aid = d.aid || q.aid;
    const bvid = d.bvid || q.bvid;

    page.innerHTML = '';
    // Hero
    const hero = el('div', { class: 'detail-hero' });
    if (d.pic) hero.appendChild(el('img', { src: d.pic, alt: '' }));
    const body = el('div', { class: 'detail-body' });
    body.appendChild(el('div', { class: 'detail-title' }, d.title || ''));
    body.appendChild(el('div', { class: 'detail-meta' }, [
      d.owner ? null : null,
      (d.owner && d.owner.name) ? `UP: ${d.owner.name}` : '',
      d.pubdate ? new Date(d.pubdate * 1000).toLocaleDateString() : '',
      d.stat ? `${d.stat.view} 播放 · ${d.stat.like} 赞` : '',
    ].filter(Boolean).join('  ·  ')));

    const descPanel = el('div', { class: 'detail-desc' }, d.desc || '');
    body.appendChild(descPanel);

    body.appendChild(el('div', { class: 'btn-row' }, [
      el('button', {
        class: 'btn-primary',
        onclick: () => {
          bridgeCall('openPlayer', { aid, bvid });
        },
      }, '▶ 播放'),
      el('button', {
        class: 'btn-ghost',
        onclick: () => {
          bridgeCall('triple', { aid, bvid }).then(r => {
            bridgeCall('toast', { msg: r.code === 0 ? '三连成功 🎉' : (r.message || '三连失败') });
          });
        },
      }, '三连'),
    ]));

    hero.appendChild(body);
    page.appendChild(hero);

    // 评论
    try {
      const cr = await bridgeCall('comments', { oid: aid, pn: 1 });
      if (cr.code === 0 && cr.data && Array.isArray(cr.data.replies)) {
        const panel = el('div', { class: 'panel' }, [
          el('div', { class: 'panel-title' }, `评论 (${cr.data.page && cr.data.page.count || 0})`),
        ]);
        const wrap = el('div');
        cr.data.replies.forEach(r => {
          const c = el('div', { class: 'reply-item' });
          c.appendChild(el('div', { class: 'reply-head' }, [
            el('img', { class: 'face', src: r.member && r.member.avatar || '' }),
            el('span', { class: 'name' }, r.member && r.member.uname || ''),
            el('span', { class: 'time' }, r.ctime ? new Date(r.ctime * 1000).toLocaleString() : ''),
          ]));
          c.appendChild(el('div', { class: 'reply-content' }, (r.content && r.content.message) || ''));
          wrap.appendChild(c);
        });
        panel.appendChild(wrap);
        page.appendChild(panel);
      }
    } catch (e) {}

    // 相关
    try {
      const rr = await bridgeCall('videoRelated', { bvid });
      if (rr.code === 0) {
        const list = Array.isArray(rr.data) ? rr.data : (rr.data && Array.isArray(rr.data.list) ? rr.data.list : []);
        if (list.length) {
          const panel = el('div', { class: 'panel' }, [
            el('div', { class: 'panel-title' }, '相关视频'),
          ]);
          const wrap = el('div', { class: 'related-list' });
          list.forEach(it => {
            const v = pickVid(it);
            if (!v) return;
            const a = el('a', {
              class: 'related-item',
              href: `#/video?bvid=${encodeURIComponent(v.bvid || '')}&aid=${encodeURIComponent(v.aid || '')}`,
            });
            a.appendChild(el('div', { class: 'thumb' }, [el('img', { src: v.pic, alt: '' })]));
            a.appendChild(el('div', { class: 'body' }, [
              el('div', { class: 'title' }, v.title),
              el('div', { class: 'up' }, v.upName),
            ]));
            wrap.appendChild(a);
          });
          panel.appendChild(wrap);
          page.appendChild(panel);
        }
      }
    } catch (e) {}
  }

  // ---------- UP 主 ----------
  async function renderUp(q) {
    const page = $('#page');
    showLoading(page);
    const resp = await bridgeCall('upInfo', { mid: q.mid });
    if (resp.code !== 0) return showError(page, resp.message);
    const d = resp.data || {};
    page.innerHTML = '';

    const head = el('div', { class: 'mine-header' }, [
      el('img', { class: 'face', src: d.face || '' }),
      el('div', { class: 'info' }, [
        el('div', { class: 'name' }, d.name || ''),
        el('div', { class: 'mid' }, `UID: ${d.mid || ''}`),
      ]),
    ]);
    page.appendChild(head);

    // 作品
    const panel = el('div', { class: 'panel' }, [
      el('div', { class: 'panel-title' }, '最新投稿'),
      el('div', { id: 'up-grid' }, el('div', { class: 'loading' }, '加载中...')),
    ]);
    page.appendChild(panel);

    const ur = await bridgeCall('upVideos', { mid: q.mid, pn: 1 });
    const target = page.querySelector('#up-grid');
    if (ur.code === 0) {
      const list = extractList(ur) || [];
      target.innerHTML = '';
      renderGrid(list, target, 'upVideos', { mid: q.mid });
    } else {
      target.innerHTML = ur.message;
    }
  }

  // ---------- 收藏 ----------
  async function renderFav(q) {
    const page = $('#page');
    showLoading(page);
    // 没 mediaId 先列收藏夹
    if (!q.mediaId) {
      const resp = await bridgeCall('favFolders', {});
      if (resp.code !== 0) return showError(page, resp.message);
      const folders = (resp.data && resp.data.list) || [];
      page.innerHTML = '';
      if (!folders.length) {
        page.appendChild(el('div', { class: 'error' }, '还没有收藏夹'));
        return;
      }
      const wrap = el('div', { class: 'panel' }, [
        el('div', { class: 'panel-title' }, '我的收藏夹'),
      ]);
      folders.forEach(f => {
        wrap.appendChild(el('a', {
          class: 'mine-row',
          href: `#/fav?mediaId=${f.id}`,
        }, [
          el('span', { class: 'icon' }, '📁'),
          el('span', { class: 'label' }, f.title || f.name || ''),
          el('span', { class: 'label', style: { flex: 'none', color: '#888', fontSize: '12px' } },
            `${(f.media_count || 0)} 个视频`),
          el('span', { class: 'chevron' }, '›'),
        ]));
      });
      page.appendChild(wrap);
      return;
    }
    // 有 mediaId —— 列出视频
    const resp = await bridgeCall('favVideos', { mediaId: q.mediaId, pn: 1 });
    if (resp.code !== 0) return showError(page, resp.message);
    const list = extractList(resp) || [];
    page.innerHTML = '';
    renderGrid(list, page, 'favVideos', { mediaId: q.mediaId });
  }

  // ---------- 历史 ----------
  async function renderHistory() {
    const page = $('#page');
    showLoading(page);
    const resp = await bridgeCall('history', { pn: 1 });
    if (resp.code !== 0) return showError(page, resp.message);
    const list = extractList(resp) || [];
    page.innerHTML = '';
    renderGrid(list, page, 'history', {});
  }

  // ---------- 我的 ----------
  async function renderMine() {
    const page = $('#page');
    page.innerHTML = '';
    let status = state.loginStatus;
    if (!status) {
      try {
        const r = await bridgeCall('loginStatus', {});
        if (r.code === 0) status = r.data;
      } catch (e) { status = { isLogin: false }; }
    }

    const head = el('div', { class: 'mine-header' });
    if (status && status.isLogin) {
      head.appendChild(el('img', { class: 'face', src: status.face || '' }));
      head.appendChild(el('div', { class: 'info' }, [
        el('div', { class: 'name' }, status.name || '已登录'),
        el('div', { class: 'mid' }, `UID: ${status.mid || ''}`),
      ]));
    } else {
      head.appendChild(el('img', { class: 'face', src: '//placeholder' }));
      head.appendChild(el('div', { class: 'info' }, [
        el('div', { class: 'name' }, '未登录'),
        el('button', {
          class: 'login-btn',
          style: { marginTop: '8px', display: 'inline-block' },
          onclick: () => bridgeCall('openLogin', {}).catch(() => {}),
        }, '登录'),
      ]));
    }
    page.appendChild(head);

    const rows = [
      { icon: '📚', label: '历史记录', href: '#/history' },
      { icon: '⭐', label: '我的收藏', href: '#/fav' },
    ];
    rows.forEach(r => {
      page.appendChild(el('a', { class: 'mine-row', href: r.href }, [
        el('span', { class: 'icon' }, r.icon),
        el('span', { class: 'label' }, r.label),
        el('span', { class: 'chevron' }, '›'),
      ]));
    });
  }

  // ---------- 搜索事件绑定 ----------
  function bindSearch() {
    const input = $('#search-input');
    const btn = $('#search-btn');
    const doIt = () => {
      const kw = (input.value || '').trim();
      if (!kw) return;
      doSearch(kw);
    };
    btn.addEventListener('click', doIt);
    input.addEventListener('keydown', e => { if (e.key === 'Enter') doIt(); });
  }

  // ---------- 启动 ----------
  function init() {
    // 搜索框
    bindSearch();
    // 路由
    window.addEventListener('hashchange', onHashChange);
    // 首页加载时 fetch login status
    bridgeCall('loginStatus', {}).then(r => {
      if (r.code === 0) state.loginStatus = r.data;
    }).catch(() => {});

    onHashChange();
  }

  document.addEventListener('DOMContentLoaded', init);

  // ---------- Mock（仅 DEBUG 模式下用于浏览器直接打开测试）----------
  function mockCall(action, params) {
    const mock = (code, data, message = 'ok') =>
      Promise.resolve({ code, message, data });
    switch (action) {
      case 'home':
        return mock(0, { result: genMockItems(10) });
      case 'follow':
        return mock(0, { items: genMockDyns(5) });
      case 'regionList':
        return mock(0, [
          { id: 1, name: '推荐', children: [] },
          { id: 3, name: '音乐', children: [] },
          { id: 4, name: '游戏', children: [] },
          { id: 5, name: '娱乐', children: [] },
        ]);
      case 'region':
        return mock(0, { result: genMockItems(8) });
      case 'searchHot':
        return mock(0, { tags: [
          '周杰伦演唱会', '原神5.5', 'iPhone 17', '考研上岸', 'AI编程',
          '三体动画', '原神前瞻', '今日份沙雕', '音乐现场', '健身日常',
        ] });
      case 'search':
        return mock(0, { result: genMockItems(10) });
      case 'video':
        return mock(0, {
          bvid: params.bvid || 'BV1xx411c7mD',
          aid: 12345,
          title: '这是一个示例视频标题用于预览页面效果',
          pic: 'https://i0.hdslb.com/bfs/archive/0b0de9b03b02d7b8b474c66b3d0f1e9547b11d0e.jpg',
          desc: '这是视频简介，用于展示布局。实际数据来自 Bilibili API。',
          owner: { name: 'PiliPlus官方', mid: 1 },
          stat: { view: 123456, like: 9999 },
          pubdate: Math.floor(Date.now() / 1000) - 3600,
        });
      case 'videoRelated':
        return mock(0, genMockItems(6));
      case 'comments':
        return mock(0, {
          page: { count: 123 },
          replies: [
            { member: { avatar: '', uname: '用户A' }, content: { message: '好棒！' }, ctime: Math.floor(Date.now()/1000) - 600 },
            { member: { avatar: '', uname: '用户B' }, content: { message: '笑死我了哈哈哈哈哈哈哈哈哈' }, ctime: Math.floor(Date.now()/1000) - 300 },
          ],
        });
      case 'upInfo':
        return mock(0, { mid: params.mid, name: '测试UP', face: '' });
      case 'upVideos':
        return mock(0, { list: genMockItems(10) });
      case 'history':
        return mock(0, { result: genMockItems(10) });
      case 'favFolders':
        return mock(0, { list: [
          { id: 12345, title: '学习资料', media_count: 42 },
          { id: 12346, title: '沙雕视频', media_count: 99 },
        ] });
      case 'favVideos':
        return mock(0, { list: genMockItems(10) });
      case 'triple':
        return mock(0, {});
      case 'userInfo':
        return mock(0, { face: '', uname: '测试用户', mid: 1 });
      case 'loginStatus':
        return mock(0, {
          isLogin: false, name: '', mid: 0, face: '',
        });
      case 'openPlayer':
        console.log('[mock] openPlayer', params);
        return Promise.resolve({ ok: true });
      case 'openLogin':
        console.log('[mock] openLogin');
        return Promise.resolve({ ok: true });
      case 'toast':
        console.log('[toast]', params.msg);
        return Promise.resolve({ ok: true });
      default:
        return Promise.reject(new Error('unknown action: ' + action));
    }
  }

  function genMockItems(n) {
    const items = [];
    for (let i = 0; i < n; i++) {
      items.push({
        bvid: 'BV1xx411c7mD',
        aid: 12345 + i,
        title: ['这个视频值得一看', '年度最佳短片', '震惊！某某竟然…', '开箱测评', '教程来了系列'][i % 5],
        owner: { name: ['UP_A', 'UP_B', 'UP_C', 'UP_D'][i % 4] },
        pic: 'https://i0.hdslb.com/bfs/archive/0b0de9b03b02d7b8b474c66b3d0f1e9547b11d0e.jpg',
        duration: 60 + i * 30,
      });
    }
    return items;
  }
  function genMockDyns(n) {
    const list = [];
    for (let i = 0; i < n; i++) {
      list.push({
        modules: {
          module_info: { name: 'UP_' + i, face: '', time_text: '刚刚' },
          module_dynamic: {
            desc: { text: '这是一条动态文本内容，用于展示效果。' },
            major: {
              archive: {
                bvid: 'BV1xx411c7mD', aid: 12345 + i,
                title: '动态里的视频', cover: '', owner_name: 'UP_' + i,
                duration: 120,
              },
            },
          },
        },
      });
    }
    return list;
  }
})();
