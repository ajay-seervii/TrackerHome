/* Shared auth, data and UI helpers for every Pivot Tracker page. */
(function () {
  'use strict';

  // Public client values only; never put the service-role key in this file.
  const CONFIG = {
    supabaseUrl: 'https://uxoijaioqqnoncdmuefi.supabase.co',
    supabaseKey: 'sb_publishable_5hEwXzT2Xc5e_HrEnE6E9A_Dg5Uez9q',
    storageKey: 'pivot-tracker-auth',
  };

  const ICON_PATHS = {
    home: '<path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/>',
    'log-in': '<path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/><polyline points="10 17 15 12 10 7"/><line x1="15" x2="3" y1="12" y2="12"/>',
    'log-out': '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><polyline points="16 17 21 12 16 7"/><line x1="21" x2="9" y1="12" y2="12"/>',
    settings: '<path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"/><circle cx="12" cy="12" r="3"/>',
    x: '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>',
    download: '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="7 10 12 15 17 10"/><line x1="12" x2="12" y1="15" y2="3"/>',
    upload: '<path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4"/><polyline points="17 8 12 3 7 8"/><line x1="12" x2="12" y1="3" y2="15"/>',
    'rotate-ccw': '<path d="M3 12a9 9 0 1 0 9-9 9.75 9.75 0 0 0-6.74 2.74L3 8"/><path d="M3 3v5h5"/>',
    check: '<path d="M20 6 9 17l-5-5"/>',
    'check-circle': '<circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/>',
    'chevron-down': '<path d="m6 9 6 6 6-6"/>',
    'arrow-right': '<path d="M5 12h14"/><path d="m12 5 7 7-7 7"/>',
    star: '<polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"/>',
    trophy: '<path d="M6 9H4.5a2.5 2.5 0 0 1 0-5H6"/><path d="M18 9h1.5a2.5 2.5 0 0 0 0-5H18"/><path d="M4 22h16"/><path d="M10 14.66V17c0 .55-.47.98-.97 1.21C7.85 18.75 7 20.24 7 22"/><path d="M14 14.66V17c0 .55.47.98.97 1.21C16.15 18.75 17 20.24 17 22"/><path d="M18 2H6v7a6 6 0 0 0 12 0V2Z"/>',
    flame: '<path d="M8.5 14.5A2.5 2.5 0 0 0 11 12c0-1.38-.5-2-1-3-1.07-2.14-.22-4.05 2-6 .5 2.5 2 4.9 4 6.5 2 1.6 3 3.5 3 5.5a7 7 0 1 1-14 0c0-1.15.43-2.29 1-3a2.5 2.5 0 0 0 2.5 2.5z"/>',
    gamepad: '<line x1="6" x2="10" y1="12" y2="12"/><line x1="8" x2="8" y1="10" y2="14"/><line x1="15" x2="15.01" y1="13" y2="13"/><line x1="18" x2="18.01" y1="11" y2="11"/><rect width="20" height="12" x="2" y="6" rx="2"/>',
    briefcase: '<rect width="20" height="14" x="2" y="7" rx="2" ry="2"/><path d="M16 21V5a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16"/>',
    target: '<circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="6"/><circle cx="12" cy="12" r="2"/>',
    book: '<path d="M4 19.5v-15A2.5 2.5 0 0 1 6.5 2H20v20H6.5a2.5 2.5 0 0 1 0-5H20"/>',
    heart: '<path d="M19 14c1.49-1.46 3-3.21 3-5.5A5.5 5.5 0 0 0 16.5 3c-1.76 0-3 .5-4.5 2-1.5-1.5-2.74-2-4.5-2A5.5 5.5 0 0 0 2 8.5c0 2.3 1.5 4.05 3 5.5l7 7Z"/>',
    code: '<polyline points="16 18 22 12 16 6"/><polyline points="8 6 2 12 8 18"/>',
    zap: '<polygon points="13 2 3 14 12 14 11 22 21 10 12 10 13 2"/>',
    users: '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/>',
    clock: '<circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/>',
    plus: '<path d="M5 12h14"/><path d="M12 5v14"/>',
    archive: '<rect width="20" height="5" x="2" y="3" rx="1"/><path d="M4 8v11a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8"/><path d="M10 12h4"/>',
    pencil: '<path d="M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z"/>',
    'external-link': '<path d="M15 3h6v6"/><path d="M10 14 21 3"/><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/>',
    shield: '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10"/><path d="m9 12 2 2 4-4"/>',
    alert: '<circle cx="12" cy="12" r="10"/><line x1="12" x2="12" y1="8" y2="12"/><line x1="12" x2="12.01" y1="16" y2="16"/>',
    'wifi-off': '<path d="M12 20h.01"/><path d="M8.5 16.43a5 5 0 0 1 7 0"/><path d="M2 8.82a15 15 0 0 1 4.17-2.65"/><path d="M10.66 5c4.01-.36 8.14.9 11.34 3.76"/><path d="M16.85 11.25a10 10 0 0 1 2.22 1.68"/><path d="M5 13a10 10 0 0 1 5.24-2.76"/><path d="m2 2 20 20"/>',
  };

  const TRACKER_ICONS = ['target', 'gamepad', 'briefcase', 'book', 'star', 'heart', 'code', 'trophy', 'zap', 'users'];

  function icon(name, cls) {
    const body = ICON_PATHS[name] || ICON_PATHS.target;
    return `<svg class="pt-icon${cls ? ' ' + cls : ''}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true" focusable="false">${body}</svg>`;
  }

  function iconEl(name, cls) {
    const wrap = document.createElement('span');
    wrap.innerHTML = icon(name, cls);
    return wrap.firstChild;
  }

  // Replaces <span data-icon="name"></span> placeholders with inline SVG.
  function hydrateIcons(root) {
    (root || document).querySelectorAll('[data-icon]').forEach(el => {
      el.replaceWith(iconEl(el.dataset.icon, el.className));
    });
  }

  function esc(value) {
    return String(value ?? '').replace(/[&<>"']/g, ch => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[ch]));
  }

  function safeUrl(url) {
    try {
      const parsed = new URL(url);
      return parsed.protocol === 'https:' || parsed.protocol === 'http:' ? parsed.href : null;
    } catch {
      return null;
    }
  }

  // Life Level: XP needed to go from level N to N+1 is round(100 * N^1.5).
  function xpForNextLevel(level) {
    return Math.round(100 * Math.pow(level, 1.5));
  }

  function lifeLevel(totalXp) {
    let remaining = Math.max(0, Number(totalXp) || 0);
    let level = 1;
    let need = xpForNextLevel(level);
    while (remaining >= need && level < 999) {
      remaining -= need;
      level += 1;
      need = xpForNextLevel(level);
    }
    return { level, into: remaining, needed: need, pct: Math.min(100, (remaining / need) * 100) };
  }

  if (location.protocol === 'file:') {
    document.addEventListener('DOMContentLoaded', () => showGate('Open this site through a web server, not as a file. Run "python -m http.server 8000" in the project folder and open http://localhost:8000/index.html', true));
    return;
  }

  if (!window.supabase || !window.supabase.createClient) {
    document.addEventListener('DOMContentLoaded', () => showGate('Could not load the sign-in library. Check your connection and reload.', true));
    return;
  }

  const client = window.supabase.createClient(CONFIG.supabaseUrl, CONFIG.supabaseKey, {
    auth: { storageKey: CONFIG.storageKey, persistSession: true, autoRefreshToken: true, detectSessionInUrl: true, flowType: 'pkce' },
  });

  const SAFE_NEXT = /^[a-z0-9_]+\.html(\?[a-z0-9=&_-]{0,80})?$/i;

  function safeNext(value) {
    return value && SAFE_NEXT.test(value) ? value : null;
  }

  function currentPage() {
    const file = location.pathname.split('/').pop() || 'index.html';
    return file + location.search;
  }

  function homeUrl(next) {
    const url = new URL('index.html', location.href);
    const target = safeNext(next);
    if (target && !target.startsWith('index.html')) url.searchParams.set('next', target);
    return url.href;
  }

  async function signIn(next) {
    const { error } = await client.auth.signInWithOAuth({
      provider: 'google',
      options: { redirectTo: homeUrl(next) },
    });
    if (error) throw error;
  }

  async function signOut() {
    try {
      await client.auth.signOut();
    } finally {
      location.replace(new URL('index.html', location.href).href);
    }
  }

  function friendlyError(error) {
    const message = (error && (error.message || error.error_description)) || String(error || 'Something went wrong');
    if (!navigator.onLine) return 'You are offline. Changes are saved online only.';
    if (/JWT|session/i.test(message)) return 'Your session expired. Please sign in again.';
    return message.replace(/^.*?ERROR:\s*/, '');
  }

  async function rpc(name, args) {
    if (!navigator.onLine) throw new Error('You are offline. Changes are saved online only.');
    const { data, error } = await client.rpc(name, args || {});
    if (error) throw new Error(friendlyError(error));
    return data;
  }

  /* ---------- Gate overlay shown until access is confirmed ---------- */

  function showGate(message, isError, actions) {
    let gate = document.getElementById('pt-gate');
    if (!gate) {
      gate = document.createElement('div');
      gate.id = 'pt-gate';
      gate.className = 'pt-gate';
      gate.setAttribute('role', 'status');
      document.body.appendChild(gate);
    }
    gate.innerHTML = `<div class="pt-gate-box">${isError ? icon('alert') : '<span class="pt-spinner" aria-hidden="true"></span>'}<p>${esc(message)}</p><div class="pt-gate-actions"></div></div>`;
    const bar = gate.querySelector('.pt-gate-actions');
    (actions || []).forEach(a => bar.appendChild(a));
    gate.hidden = false;
  }

  function hideGate() {
    const gate = document.getElementById('pt-gate');
    if (gate) gate.hidden = true;
    document.documentElement.classList.remove('pt-locked');
  }

  function button(label, iconName, onClick, cls) {
    const b = document.createElement('button');
    b.type = 'button';
    b.className = 'pt-btn' + (cls ? ' ' + cls : '');
    b.innerHTML = (iconName ? icon(iconName) : '') + `<span>${esc(label)}</span>`;
    b.addEventListener('click', onClick);
    return b;
  }

  function link(label, iconName, href, cls) {
    const a = document.createElement('a');
    a.className = 'pt-btn' + (cls ? ' ' + cls : '');
    a.href = href;
    a.innerHTML = (iconName ? icon(iconName) : '') + `<span>${esc(label)}</span>`;
    return a;
  }

  /* ---------- Session ---------- */

  let me = null;

  async function loadMe() {
    const { data } = await client.auth.getSession();
    if (!data.session) return null;
    me = await rpc('pt_me');
    return me;
  }

  // Pages other than home call this; it redirects to home when signed out.
  async function requireAuth() {
    document.documentElement.classList.add('pt-locked');
    showGate('Checking your sign-in...');
    let profile;
    try {
      profile = await loadMe();
    } catch (error) {
      showGate(friendlyError(error), true, [button('Try again', 'rotate-ccw', () => location.reload()), link('Home', 'home', 'index.html')]);
      throw error;
    }
    if (!profile) {
      location.replace(homeUrl(currentPage()));
      return new Promise(() => {});
    }
    if (!profile.approved) {
      showGate('Your account is waiting for approval.', true, [link('Home', 'home', 'index.html'), button('Sign out', 'log-out', signOut)]);
      return new Promise(() => {});
    }
    watchSignOut();
    return profile;
  }

  let watching = false;
  function watchSignOut() {
    if (watching) return;
    watching = true;
    client.auth.onAuthStateChange(event => {
      if (event === 'SIGNED_OUT') location.replace(new URL('index.html', location.href).href);
    });
    window.addEventListener('storage', event => {
      if (event.key === CONFIG.storageKey && !event.newValue) {
        location.replace(new URL('index.html', location.href).href);
      }
    });
  }

  /* ---------- Shared navigation bar ---------- */

  function mountNav(target, options) {
    const opts = options || {};
    const nav = document.createElement('nav');
    nav.className = 'pt-nav';
    nav.setAttribute('aria-label', 'Account');
    const name = me && (me.display_name || me.email);
    nav.innerHTML = `
      ${opts.brand ? `<span class="pt-nav-brand">${icon('trophy')}<span>${esc(opts.brand)}</span></span>` : `<a class="pt-nav-link" href="index.html">${icon('home')}<span>Home</span></a>`}
      <span class="pt-nav-spacer"></span>
      ${opts.admin ? `<a class="pt-nav-link" href="${esc(opts.admin)}">${icon('pencil')}<span>Manage tasks</span></a>` : ''}
      <span class="pt-nav-user" title="${esc(me && me.email)}">${esc(name || '')}</span>
      <span class="pt-nav-offline" hidden>${icon('wifi-off')}<span>Offline</span></span>`;
    const out = button('Sign out', 'log-out', signOut, 'pt-nav-link');
    nav.appendChild(out);
    (typeof target === 'string' ? document.querySelector(target) : target).prepend(nav);
    const offline = nav.querySelector('.pt-nav-offline');
    const sync = () => {
      offline.hidden = navigator.onLine;
      document.documentElement.classList.toggle('pt-offline', !navigator.onLine);
    };
    window.addEventListener('online', sync);
    window.addEventListener('offline', sync);
    sync();
    return nav;
  }

  /* ---------- Toasts ---------- */

  function toast(message, kind) {
    let host = document.getElementById('pt-toasts');
    if (!host) {
      host = document.createElement('div');
      host.id = 'pt-toasts';
      host.className = 'pt-toasts';
      host.setAttribute('aria-live', 'polite');
      document.body.appendChild(host);
    }
    const el = document.createElement('div');
    el.className = 'pt-toast' + (kind ? ' pt-toast--' + kind : '');
    el.innerHTML = icon(kind === 'error' ? 'alert' : 'check-circle') + `<span>${esc(message)}</span>`;
    host.appendChild(el);
    setTimeout(() => el.remove(), kind === 'error' ? 5000 : 2500);
  }

  /* ---------- Tracker data ---------- */

  async function loadTracker(slug) {
    const { data: tracker, error } = await client.from('trackers')
      .select('id, slug, name, description, icon, ruleset, allow_uncheck, requires_approval, page, created_by')
      .eq('slug', slug).maybeSingle();
    if (error) throw new Error(friendlyError(error));
    if (!tracker) throw new Error('This tracker was not found, or you do not have access to it.');

    const [roleRes, tasksRes, progressRes, aggRes] = await Promise.all([
      client.rpc('pt_tracker_role', { p_tracker: tracker.id }),
      client.from('tasks')
        .select('id, parent_id, kind, title, description, xp, difficulty, week_number, month_number, time_estimate, sort_order, legacy_key, archived_at, task_resources(id, title, url, sort_order)')
        .eq('tracker_id', tracker.id).is('archived_at', null)
        .order('sort_order').order('created_at'),
      client.from('task_progress').select('id, task_id, status, awarded_xp, completed_at')
        .eq('tracker_id', tracker.id).eq('user_id', me.id),
      client.from('progress').select('level, current_xp, total_xp, unlocked_achievements, unlocked_skills')
        .eq('tracker_id', tracker.id).eq('user_id', me.id).maybeSingle(),
    ]);
    for (const res of [roleRes, tasksRes, progressRes, aggRes]) {
      if (res.error) throw new Error(friendlyError(res.error));
    }

    const nodes = tasksRes.data.map(n => ({
      ...n,
      task_resources: (n.task_resources || []).slice().sort((a, b) => a.sort_order - b.sort_order),
      children: [],
    }));
    const byId = new Map(nodes.map(n => [n.id, n]));
    // Items inside an archived group are hidden along with it.
    const visible = n => {
      for (let cur = n, depth = 0; cur && depth < 25; depth++) {
        if (!cur.parent_id) return true;
        cur = byId.get(cur.parent_id);
      }
      return false;
    };
    const shown = nodes.filter(visible);
    const roots = [];
    shown.forEach(n => {
      const parent = n.parent_id && byId.get(n.parent_id);
      (parent ? parent.children : roots).push(n);
    });
    const progress = new Map(progressRes.data.map(p => [p.task_id, p]));
    const xp = (await client.from('xp_events').select('amount').eq('tracker_id', tracker.id).eq('user_id', me.id));
    if (xp.error) throw new Error(friendlyError(xp.error));

    return {
      tracker,
      role: roleRes.data,
      canEdit: roleRes.data === 'owner' || roleRes.data === 'member',
      isCreator: tracker.created_by === me.id,
      roots,
      byId,
      tasks: shown.filter(n => n.kind === 'task'),
      progress,
      aggregate: aggRes.data,
      trackerXp: xp.data.reduce((sum, e) => sum + e.amount, 0),
    };
  }

  function completeTask(taskId) {
    return rpc('pt_complete_task', { p_task: taskId });
  }

  function uncompleteTask(taskId) {
    return rpc('pt_uncomplete_task', { p_task: taskId });
  }

  function resetTracker(trackerId) {
    return rpc('pt_reset_tracker', { p_tracker: trackerId });
  }

  function importCompletions(trackerId, keys) {
    return rpc('pt_import_completions', { p_tracker: trackerId, p_keys: keys.map(String).slice(0, 1000) });
  }

  function download(filename, data) {
    const blob = new Blob([JSON.stringify(data, null, 2)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    a.click();
    URL.revokeObjectURL(url);
  }

  window.PT = {
    client,
    icon,
    iconEl,
    hydrateIcons,
    esc,
    safeUrl,
    TRACKER_ICONS,
    xpForNextLevel,
    lifeLevel,
    safeNext,
    signIn,
    signOut,
    loadMe,
    requireAuth,
    watchSignOut,
    mountNav,
    showGate,
    hideGate,
    button,
    link,
    toast,
    rpc,
    friendlyError,
    loadTracker,
    completeTask,
    uncompleteTask,
    resetTracker,
    importCompletions,
    download,
    get me() { return me; },
  };
})();
