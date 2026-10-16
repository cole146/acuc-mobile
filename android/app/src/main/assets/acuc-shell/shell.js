/*
 * ACUC app shell — ships inside the app and runs at the start of every acuc.jobs screen.
 *
 *  • Instant screens: tapping a link shows that screen's layout at once (header, cards, bottom menu,
 *    drawn from the app itself), and the real content takes its place as soon as it arrives —
 *    the app never sits on a blank or frozen page while the next one loads.
 *  • Offline taps: with no internet a tap does not leave the current screen; a small note says so
 *    and the screen opens by itself as soon as the connection is back.
 *  • The app keeps its own offline copies (see PageLoader.java), so the website's service worker
 *    is not used inside the app.
 */
(function () {
  'use strict';
  if (window.__acucShell) return;
  window.__acucShell = 1;

  var top = true;
  try { top = window.top === window.self; } catch (e) { top = false; }

  /* ---------- 1. no website service worker inside the app ---------- */
  try {
    var swc = navigator.serviceWorker;
    if (swc) {
      try {
        Object.defineProperty(swc, 'register', { configurable: true, value: function () { return Promise.reject(new Error('Not used in the ACUC app')); } });
      } catch (e) {}
      if (top && swc.getRegistrations) {
        swc.getRegistrations().then(function (rs) { rs.forEach(function (r) { try { r.unregister(); } catch (e) {} }); }).catch(function () {});
      }
    }
  } catch (e) {}

  if (!top) return;

  /* ---------- 2. the app's own screen layouts ---------- */
  var IC = {
    home: '<path d="M3 10.5 12 3l9 7.5"/><path d="M5.5 9.5V20h13V9.5"/><path d="M10 20v-5h4v5"/>',
    network: '<path d="M17 21v-2a4 4 0 0 0-4-4H7a4 4 0 0 0-4 4v2"/><circle cx="10" cy="7" r="4"/><path d="M21 21v-2a3.5 3.5 0 0 0-2.6-3.4"/><path d="M15.5 3.2a4 4 0 0 1 0 7.6"/>',
    jobs: '<rect x="3" y="7" width="18" height="13" rx="2.5"/><path d="M8 7V5.5A2.5 2.5 0 0 1 10.5 3h3A2.5 2.5 0 0 1 16 5.5V7"/><path d="M3 12.5h18"/>',
    messages: '<path d="M21 15a2 2 0 0 1-2 2H8l-5 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>',
    alerts: '<path d="M6 8.5a6 6 0 1 1 12 0c0 4.2 1.4 5.7 2 6.3a1 1 0 0 1-.7 1.7H4.7a1 1 0 0 1-.7-1.7c.6-.6 2-2.1 2-6.3Z"/><path d="M9.5 19.5a2.5 2.5 0 0 0 5 0"/>',
    back: '<path d="m15 18-6-6 6-6"/>',
    search: '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>',
    wifi: '<path d="M2 8.8a15 15 0 0 1 20 0"/><path d="M5 12.6a10 10 0 0 1 14 0"/><path d="M8.5 16.3a5 5 0 0 1 7 0"/><path d="M12 20h.01"/><path d="m3 3 18 18"/>',
    compass: '<circle cx="12" cy="12" r="9"/><path d="m15.5 8.5-2 5-5 2 2-5z"/>',
    clock: '<circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>'
  };
  function svg(n, s) {
    return '<svg width="' + (s || 24) + '" height="' + (s || 24) + '" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">' + IC[n] + '</svg>';
  }
  var TABS = [['home', 'Home', '/network/'], ['network', 'Network', '/network/friends/'], ['jobs', 'Jobs', '/network/jobs/'], ['messages', 'Messages', '/network/message/'], ['alerts', 'Alerts', '/network/notifications/']];

  /** Which layout a link opens. */
  function kindOf(u) {
    var p = (u.pathname || '/').toLowerCase(), q = u.search || '';
    if (/^\/(network\/)?message/.test(p) || /[?&]tab=messages/.test(q)) return 'messages';
    if (/^\/network\/notifications/.test(p)) return 'alerts';
    if (/^\/jobview\/|^\/job\/|^\/jobs\/[^/]+\/?$/.test(p)) return 'job';
    if (/^\/network\/jobs|^\/jobs\/?$|^\/job-search|^\/network\/job-history|^\/network\/saved/.test(p)) return 'jobs';
    if (/^\/network\/companies|^\/company-profile\/?$/.test(p) && !/[?&]id=/.test(q)) return 'companies';
    if (/^\/company-profile|[?&]company=/.test(p + q)) return 'company';
    if (/^\/network\/my-workspace|^\/apply-now|^\/cv-builder|^\/ai-apply|^\/network\/career-hub/.test(p)) return 'workspace';
    if (/[?&]candidate=|^\/network\/profile|^\/candidate\//.test(p + q)) return 'profile';
    if (/^\/network\/friends/.test(p)) return 'network';
    if (/^\/network\/?$/.test(p)) return 'home';
    return 'page';
  }
  function tabOf(kind) {
    return { messages: 'messages', alerts: 'alerts', jobs: 'jobs', job: 'jobs', companies: 'jobs', network: 'network', home: 'home' }[kind] || '';
  }

  var CSS = [
    ':host{all:initial}',
    '*{box-sizing:border-box}',
    '.wrap{position:fixed;inset:0;z-index:2147483600;display:flex;flex-direction:column;background:var(--bg,#F5F7FB);font-family:Manrope,"Plus Jakarta Sans",system-ui,-apple-system,"Segoe UI",Roboto,sans-serif;color:#0B1A33;-webkit-tap-highlight-color:transparent;animation:in .14s ease-out both;overflow:hidden}',
    '@keyframes in{from{opacity:0}to{opacity:1}}',
    '.hd{flex:0 0 auto;height:56px;display:flex;align-items:center;gap:10px;padding:0 12px;background:rgba(255,255,255,.94);box-shadow:0 1px 0 rgba(20,33,61,.06),0 6px 18px -14px rgba(20,33,61,.3)}',
    '.hd .bk{width:30px;height:30px;display:grid;place-items:center;color:#14213D}',
    '.hd .logo{width:58px;height:20px;border-radius:6px}',
    '.hd .srch{flex:1;height:38px;border-radius:19px;background:#EEF2F8;display:flex;align-items:center;gap:8px;padding:0 14px;color:#8A97AD;font-size:15px;font-weight:500}',
    '.hd .av{width:38px;height:38px;border-radius:50%;flex:0 0 auto}',
    '.ttl{flex:0 0 auto;display:flex;align-items:center;justify-content:space-between;padding:16px 18px 6px;background:var(--hbg,transparent)}',
    '.ttl b{font-size:28px;font-weight:800;letter-spacing:-.02em;color:#0B1A33}',
    '.ttl .ic{display:flex;gap:8px}.ttl .ic i{width:38px;height:38px;border-radius:50%}',
    '.body{flex:1;overflow:hidden;padding:12px 16px 110px}',
    '.sk{background:linear-gradient(90deg,#E2E8F1 0%,#F1F5FA 40%,#E2E8F1 80%);background-size:300% 100%;animation:sh 1.15s ease-in-out infinite;border-radius:8px}',
    '@keyframes sh{0%{background-position:100% 0}100%{background-position:0 0}}',
    '.card{background:#fff;border-radius:18px;padding:16px;margin-bottom:12px;box-shadow:0 1px 2px rgba(11,26,51,.04),0 8px 24px -18px rgba(11,26,51,.25)}',
    '.row{display:flex;gap:12px;align-items:center}',
    '.col{flex:1;display:flex;flex-direction:column;gap:8px;min-width:0}',
    '.l{height:12px}.l.t{height:16px;width:72%}.l.s{width:46%}.l.m{width:88%}.l.x{width:30%}',
    '.sq{width:52px;height:52px;border-radius:14px;flex:0 0 auto}',
    '.ci{width:50px;height:50px;border-radius:50%;flex:0 0 auto}',
    '.chips{display:flex;gap:8px;margin:12px 0 2px}.chips i{height:28px;width:84px;border-radius:14px}',
    '.pills{display:flex;gap:8px;margin:2px 0 14px}.pills i{height:34px;width:74px;border-radius:17px}',
    '.grid{display:grid;grid-template-columns:1fr 1fr;gap:10px}.grid .card{margin:0;height:120px}',
    '.list .it{display:flex;gap:12px;align-items:center;padding:12px 2px}',
    '.cover{height:120px;border-radius:18px;margin-bottom:-36px}',
    '.big{width:84px;height:84px;border-radius:50%;border:4px solid #fff;margin-left:16px;position:relative}',
    '.tb{position:fixed;left:10px;right:10px;bottom:8px;height:78px;padding:5px;display:flex;gap:2px;border-radius:33px;border:1px solid rgba(255,255,255,.75);background:rgba(255,255,255,.86);-webkit-backdrop-filter:blur(26px) saturate(1.9);backdrop-filter:blur(26px) saturate(1.9);box-shadow:0 14px 34px -14px rgba(11,26,51,.32),0 2px 6px rgba(11,26,51,.06),inset 0 1px 0 rgba(255,255,255,.9),0 0 0 .5px rgba(11,26,51,.08);font-family:"Plus Jakarta Sans",system-ui,-apple-system,"Segoe UI",sans-serif}',
    '.tb a{flex:1 1 0;min-width:0;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:2px;padding:4px 0 3px;border-radius:28px;color:#14213D;text-decoration:none;font-size:11px;font-weight:600}',
    '.tb a.on{background:rgba(11,26,51,.075);color:#0B1F4D;font-weight:700}',
    '.tb .ti{height:28px;display:grid;place-items:center}',
    '.tb .pr .ti{width:44px;height:30px;border-radius:15px;color:#fff;background:linear-gradient(140deg,#1E63E9,#3E86F7);box-shadow:0 6px 14px -6px rgba(30,99,233,.75)}',
    '.tb .pr svg{width:20px;height:20px}',
    '.msg{margin:28px auto 0;max-width:340px;text-align:center;background:#fff;border-radius:22px;padding:28px 22px 22px;box-shadow:0 1px 2px rgba(11,26,51,.04),0 14px 36px -22px rgba(11,26,51,.35)}',
    '.msg .mi{width:60px;height:60px;border-radius:50%;margin:0 auto 14px;display:grid;place-items:center;background:#EAF1FF;color:#1E63E9}',
    '.msg h1{margin:0 0 8px;font-size:20px;font-weight:800;letter-spacing:-.01em;color:#0B1A33;overflow-wrap:anywhere}',
    '.msg p{margin:0 0 20px;font-size:15px;line-height:1.5;color:#5B6B85;overflow-wrap:anywhere}',
    '.msg .bt{display:flex;flex-direction:column;gap:10px}',
    '.msg button{font:inherit;font-size:15.5px;font-weight:700;min-height:48px;border-radius:24px;border:0;padding:0 22px;background:linear-gradient(140deg,#1E63E9,#3E86F7);color:#fff;box-shadow:0 8px 18px -10px rgba(30,99,233,.8)}',
    '.msg button.g{background:#EEF2F8;color:#14213D;box-shadow:none}',
    '.msg .st{font-size:13px;color:#8A97AD;margin-top:14px;min-height:18px}',
    '.toast{position:fixed;left:50%;transform:translateX(-50%);top:14px;z-index:2147483646;max-width:calc(100vw - 32px);background:#0B1A33;color:#fff;font:600 13.5px/1.35 Manrope,system-ui,sans-serif;padding:10px 16px;border-radius:20px;box-shadow:0 10px 26px -10px rgba(0,0,0,.45);text-align:center;animation:in .15s ease-out both}'
  ].join('');

  function L(c) { return '<i class="sk l ' + (c || '') + '"></i>'; }
  function header(kind) {
    if (kind === 'messages' || kind === 'alerts') {
      return '<div class="ttl" style="--hbg:' + (kind === 'messages' ? '#fff' : '#F4F6FA') + '"><b>' + (kind === 'messages' ? 'Messages' : 'Alerts') + '</b><span class="ic"><i class="sk"></i><i class="sk"></i><i class="sk"></i></span></div>';
    }
    return '<div class="hd"><span class="bk">' + svg('back', 22) + '</span><i class="sk logo"></i><span class="srch">' + svg('search', 18) + '<span>' + (kind === 'jobs' || kind === 'job' ? 'Search jobs' : kind === 'companies' || kind === 'company' ? 'Search' : 'I’m looking for…') + '</span></span><i class="sk av"></i></div>';
  }
  function bodyFor(kind) {
    var h = '', i;
    switch (kind) {
      case 'jobs':
        h += '<div class="pills"><i class="sk"></i><i class="sk"></i><i class="sk"></i><i class="sk"></i></div>';
        for (i = 0; i < 4; i++) h += '<div class="card"><div class="row"><i class="sk sq"></i><div class="col">' + L('t') + L('s') + '</div></div><div class="chips"><i class="sk"></i><i class="sk"></i><i class="sk"></i></div></div>';
        break;
      case 'job':
        h += '<div class="card"><div class="row"><i class="sk sq"></i><div class="col">' + L('t') + L('s') + '</div></div><div class="chips"><i class="sk"></i><i class="sk"></i></div><div style="height:14px"></div><i class="sk" style="display:block;height:46px;border-radius:23px"></i></div>';
        h += '<div class="card"><div class="col">' + L('t') + L('m') + L('m') + L('m') + L('s') + '</div></div><div class="card"><div class="col">' + L('t') + L('m') + L('m') + '</div></div>';
        break;
      case 'messages':
        h += '<i class="sk" style="display:block;height:44px;border-radius:22px;margin:4px 0 12px"></i><div class="pills"><i class="sk"></i><i class="sk"></i><i class="sk"></i></div><div class="list">';
        for (i = 0; i < 7; i++) h += '<div class="it"><i class="sk ci"></i><div class="col">' + L('s') + L('m') + '</div></div>';
        h += '</div>';
        break;
      case 'alerts':
        h += '<div class="pills"><i class="sk"></i><i class="sk"></i><i class="sk"></i><i class="sk"></i></div><div class="list">';
        for (i = 0; i < 7; i++) h += '<div class="it"><i class="sk ci" style="width:40px;height:40px"></i><div class="col">' + L('s') + L('m') + '</div></div>';
        h += '</div>';
        break;
      case 'workspace':
        h += '<div class="card"><div class="col">' + L('t') + L('m') + L('s') + '</div></div><div class="grid">';
        for (i = 0; i < 6; i++) h += '<div class="card"><div class="col">' + L('t') + L('m') + L('s') + '</div></div>';
        h += '</div>';
        break;
      case 'profile':
      case 'company':
        h += '<i class="sk cover" style="display:block"></i><i class="sk big" style="display:block' + (kind === 'company' ? ';border-radius:22px' : '') + '"></i><div class="card" style="margin-top:12px"><div class="col">' + L('t') + L('s') + L('m') + '</div><div class="chips"><i class="sk"></i><i class="sk"></i></div></div><div class="card"><div class="col">' + L('t') + L('m') + L('m') + '</div></div>';
        break;
      case 'companies':
        h += '<div class="col" style="margin:6px 0 16px">' + L('x') + '<i class="sk l" style="height:26px;width:80%"></i>' + L('m') + '</div><div class="pills"><i class="sk"></i><i class="sk"></i><i class="sk"></i></div>';
        for (i = 0; i < 3; i++) h += '<div class="card"><div class="row"><i class="sk sq" style="width:64px;height:64px;border-radius:16px"></i><div class="col">' + L('t') + L('s') + '</div></div><div class="chips"><i class="sk"></i></div></div>';
        break;
      case 'network':
        h += '<div class="card"><div class="col">' + L('t') + '</div><div class="pills" style="margin:14px 0 0"><i class="sk" style="height:58px;width:22%;border-radius:12px"></i><i class="sk" style="height:58px;width:22%;border-radius:12px"></i><i class="sk" style="height:58px;width:22%;border-radius:12px"></i><i class="sk" style="height:58px;width:22%;border-radius:12px"></i></div></div>';
        for (i = 0; i < 3; i++) h += '<div class="card"><div class="row"><i class="sk ci"></i><div class="col">' + L('s') + L('m') + '</div></div></div>';
        break;
      default:
        for (i = 0; i < 3; i++) h += '<div class="card"><div class="row"><i class="sk ci"></i><div class="col">' + L('s') + L('x') + '</div></div><div style="height:12px"></div><div class="col">' + L('m') + L('m') + L('s') + '</div></div>';
    }
    return h;
  }
  function tabbar(active) {
    var h = '<nav class="tb">';
    TABS.forEach(function (t) {
      h += '<a href="' + t[2] + '" class="' + (t[0] === 'jobs' ? 'pr ' : '') + (t[0] === active ? 'on' : '') + '"><span class="ti">' + svg(t[0]) + '</span><span>' + t[1] + '</span></a>';
    });
    return h + '</nav>';
  }
  function bgOf(kind) { return { messages: '#fff', alerts: '#F4F6FA', workspace: '#E4EDFB', network: '#E4EDFB', companies: '#F2F5FB' }[kind] || '#F5F7FB'; }

  /** Draws a whole app screen (header + content + bottom menu) in an isolated layer. */
  function screen(kind, inner) {
    var host = document.createElement('acuc-app-screen');
    host.setAttribute('style', 'all:initial;position:fixed;inset:0;z-index:2147483600');
    var root = host.attachShadow ? host.attachShadow({ mode: 'open' }) : host;
    root.innerHTML = '<style>' + CSS + '</style><div class="wrap" style="--bg:' + bgOf(kind) + '">' + header(kind) + '<div class="body">' + (inner || bodyFor(kind)) + '</div>' + tabbar(tabOf(kind)) + '</div>';
    (document.body || document.documentElement).appendChild(host);
    return { host: host, root: root };
  }

  /* ---------- 3. tap → the next screen's layout at once ---------- */
  var cur = null, curT = 0;
  function hide() {
    if (cur) { try { cur.host.remove(); } catch (e) {} cur = null; }
    clearTimeout(curT);
  }
  function showFor(u) {
    hide();
    cur = screen(kindOf(u));
    // Safety: if the page never changes (a download, a cancelled load), step aside.
    curT = setTimeout(hide, 12000);
  }
  window.addEventListener('pageshow', function (e) { if (e.persisted) hide(); });
  document.addEventListener('visibilitychange', function () { if (document.visibilityState === 'visible' && cur && Date.now() - (cur.at || 0) > 12000) hide(); });

  var toastEl = null, toastT = 0;
  function toast(txt, ms) {
    if (!document.body) return;
    if (!toastEl) {
      var h = document.createElement('acuc-app-toast');
      h.setAttribute('style', 'all:initial;position:fixed;z-index:2147483646;top:0;left:0');
      var r = h.attachShadow ? h.attachShadow({ mode: 'open' }) : h;
      r.innerHTML = '<style>' + CSS + '</style><div class="toast"></div>';
      toastEl = { host: h, box: r.querySelector('.toast') };
    }
    toastEl.box.textContent = txt;
    if (!toastEl.host.isConnected) document.body.appendChild(toastEl.host);
    clearTimeout(toastT);
    if (ms) toastT = setTimeout(function () { try { toastEl.host.remove(); } catch (e) {} }, ms);
  }
  var pending = null;
  window.addEventListener('online', function () {
    if (!pending) return;
    var u = pending; pending = null;
    toast('Back online — opening…', 1500);
    showFor(u);
    location.href = u.href;
  });

  function linkOf(e) {
    var t = e.target;
    while (t && t.nodeType !== 1) t = t.parentNode;
    var a = t && t.closest ? t.closest('a[href]') : null;
    if (!a) return null;
    if (a.target && !/^(_self|_top)$/i.test(a.target)) return null;
    if (a.hasAttribute('download') || a.getAttribute('href').charAt(0) === '#') return null;
    var u;
    try { u = new URL(a.href, location.href); } catch (x) { return null; }
    if (u.origin !== location.origin || !/^https?:$/.test(u.protocol)) return null;
    if (u.pathname === location.pathname && u.search === location.search) return null;   // same screen (hash links etc.)
    if (/\.(pdf|docx?|xlsx?|pptx?|zip|csv|ics|png|jpe?g|webp|gif|svg|mp4|mp3|txt)$/i.test(u.pathname)) return null;
    if (/^\/wp-admin\//.test(u.pathname)) return null;
    return u;
  }
  window.addEventListener('click', function (e) {
    if (e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
    var u = linkOf(e);
    if (!u) return;
    if (navigator.onLine === false) {
      e.preventDefault();
      pending = u;
      toast('You’re offline — this will open as soon as you’re back online.', 4000);
      return;
    }
    setTimeout(function () { if (!e.defaultPrevented) { showFor(u); if (cur) cur.at = Date.now(); } }, 0);
  }, false);

  /* ---------- 4. for the app's own offline / error screens ---------- */
  window.ACUCShell = { screen: screen, svg: svg, kindOf: kindOf, toast: toast, hide: hide };
})();
