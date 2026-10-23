/* f_chat — NUI logic.
   Runs unchanged in a browser (for the preview) and inside FiveM. */

const IN_GAME = typeof window.invokeNative !== 'undefined';
const RES = IN_GAME ? (window.GetParentResourceName ? GetParentResourceName() : 'f_chat') : 'f_chat';

function post(name, data) {
  if (!IN_GAME) return Promise.resolve({});
  return fetch(`https://${RES}/${name}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(data || {})
  }).catch(() => ({}));
}

const $ = (id) => document.getElementById(id);
const chat = $('chat');

const ICONS = {
  speech:    '<path d="M21 12a8 8 0 0 1-8 8H7l-4 3 1.2-4.2A8 8 0 1 1 21 12z"/>',
  globe:     '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3a15 15 0 0 1 0 18 15 15 0 0 1 0-18z"/>',
  hand:      '<path d="M8 13V5.5a1.5 1.5 0 0 1 3 0V12m0-1V4.5a1.5 1.5 0 0 1 3 0V12m0-1.5a1.5 1.5 0 0 1 3 0V16a5 5 0 0 1-5 5h-1a6 6 0 0 1-6-6v-3.5a1.5 1.5 0 0 1 3 0"/>',
  eye:       '<path d="M2 12s3.6-6 10-6 10 6 10 6-3.6 6-10 6-10-6-10-6z"/><circle cx="12" cy="12" r="2.6"/>',
  dice:      '<rect x="4" y="4" width="16" height="16" rx="3"/><circle cx="9" cy="9" r=".9" fill="currentColor"/><circle cx="15" cy="15" r=".9" fill="currentColor"/><circle cx="12" cy="12" r=".9" fill="currentColor"/>',
  radio:     '<circle cx="12" cy="13" r="3"/><path d="M6.5 7.5a8 8 0 0 0 0 11M17.5 7.5a8 8 0 0 1 0 11M4 5a12 12 0 0 0 0 16M20 5a12 12 0 0 1 0 16"/>',
  shield:    '<path d="M12 3l8 3v6c0 5-3.4 8.2-8 9-4.6-.8-8-4-8-9V6z"/>',
  megaphone: '<path d="M4 10v4a1 1 0 0 0 1 1h3l7 4V5L8 9H5a1 1 0 0 0-1 1zM19 9a4 4 0 0 1 0 6"/>',
  flag:      '<path d="M5 21V4m0 0h11l-2 4 2 4H5"/>',
  info:      '<circle cx="12" cy="12" r="9"/><path d="M12 11v5M12 7.6v.1"/>'
};
const icon = (name, cls = '') =>
  `<svg class="${cls}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">${ICONS[name] || ICONS.speech}</svg>`;

const EMOJI = ['😀','😂','🙂','😉','😅','😐','🙄','😴','🥲','😎','😤','😭','😡','🤔','🫡','🤝','👍','👎','👏','🙏','💪','🔥','⚡','💀','🚑','🚓','🔫','💊','💸','🍺','☕','🚬','🚗','🛠️','📻','📍','⏰','❗','❓','✅','❌','⭐','❤️','💤','🎯','🎲'];

const state = {
  channels: [],
  channel: null,
  messages: [],
  suggestions: [],
  staff: false,
  serverId: 0,
  myName: '',
  maxLength: 220,
  fadeAfter: 5,
  history: [],
  historyIndex: -1,
  tab: 'global',            // tab terakhir dipakai -> dibuka lagi saat T
  jobFilter: null,          // channel job terpilih di tab Job, 'all' = Semua
  unread: { announce: 0, global: 0, job: 0 },
  announceFade: 12,         // detik pengumuman bertahan di feed saat chat tertutup
  idleUntil: 0,
  typers: new Map(),
  reactions: new Map(),
  sugIndex: 0,
  settings: {
    preset: 'dispatch', accent: '#E0A458', corners: 'soft', density: 'cosy',
    size: 100, position: 'left', timestamps: true, sound: true, font: 'Inter'
  },
  themes: [],
  fonts: ['Inter', 'Barlow Semi Condensed', 'Rubik', 'Source Sans 3', 'System UI'],
  idleTimer: null
};

/* ---------- settings ------------------------------------- */

function applySettings() {
  const s = state.settings;
  chat.dataset.corners = s.corners;
  chat.dataset.density = s.density;
  chat.dataset.position = s.position;
  chat.style.fontSize = (14 * (s.size / 100)).toFixed(1) + 'px';
  chat.style.setProperty('--accent', s.accent);
  chat.style.setProperty('--accent-rgb', rgbOf(s.accent, '224, 164, 88'));

  const theme = state.themes.find((t) => t.id === s.preset);
  chat.dataset.light = String(!!(theme && theme.light));
  if (theme) {
    chat.style.setProperty('--ink', theme.bg);
    chat.style.setProperty('--ink-rgb', rgbOf(theme.bg, '16, 20, 28'));
  }
  chat.style.setProperty('--sans', s.font === 'System UI'
    ? 'system-ui, "Segoe UI", sans-serif'
    : `"${s.font}", "NX Sans", "Segoe UI", system-ui, sans-serif`);

  document.querySelectorAll('.choices').forEach((group) => {
    const key = group.dataset.setting;
    group.querySelectorAll('.choice').forEach((b) => {
      b.dataset.active = String(b.dataset.value === String(s[key]));
    });
  });
  document.querySelectorAll('.toggle').forEach((t) => {
    t.dataset.on = String(s[t.dataset.setting] !== false);
  });
  document.querySelectorAll('.swatch').forEach((sw) => {
    sw.dataset.active = String(sw.dataset.theme === s.preset);
  });
  $('accent-picker').value = s.accent;
  $('accent-hex').textContent = s.accent.toUpperCase();
  $('size-range').value = s.size;
  $('size-value').textContent = s.size + '%';
  render();
}

function saveSettings(patch) {
  Object.assign(state.settings, patch);
  applySettings();
  post('settings', patch);
}

/* ---------- rendering ------------------------------------ */

/* '#RRGGBB' / '#RGB' -> 'r, g, b' for rgba(var(--x), .5) in the stylesheet */
function rgbOf(hex, fallback = '166, 176, 197') {
  let h = String(hex || '').trim().replace(/^#/, '');
  if (h.length === 3) h = h.split('').map((c) => c + c).join('');
  if (!/^[0-9a-fA-F]{6}$/.test(h)) return fallback;
  return [0, 2, 4].map((i) => parseInt(h.slice(i, i + 2), 16)).join(', ');
}

const escapeHtml = (str) => String(str ?? '').replace(/[&<>"']/g, (c) =>
  ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

function decorate(text) {
  let html = escapeHtml(text);
  if (state.myName) {
    const first = state.myName.split(' ')[0];
    const re = new RegExp(`@(${first}|${state.myName.replace(/\s/g, '\\s')})\\b`, 'gi');
    html = html.replace(re, '<mark>@$1</mark>');
  }
  return html.replace(/(^|\s)(@[\w-]+)/g, '$1<mark>$2</mark>');
}

function mentionsMe(text) {
  if (!state.myName) return false;
  const first = state.myName.split(' ')[0].toLowerCase();
  return text.toLowerCase().includes('@' + first);
}

function messageNode(msg) {
  const el = document.createElement('div');
  el.className = 'msg';
  el.dataset.id = msg.id;
  el.dataset.italic = String(!!msg.italic);
  el.dataset.system = String(!!msg.system);
  el.dataset.mention = String(!!msg.mention);
  el.dataset.tab = tabOf(msg);
  el.style.setProperty('--chan', msg.color || '#8D97AB');
  el.style.setProperty('--chan-rgb', rgbOf(msg.color, '141, 151, 171'));

  const reactions = state.reactions.get(msg.id);
  const badge = msg.badge
    ? `<span class="badge" style="--badge-rgb:${rgbOf(msg.badge.color, '224, 164, 88')}">${escapeHtml(msg.badge.label)}</span>` : '';
  const time = state.settings.timestamps && msg.time ? `<span class="time">${escapeHtml(msg.time)}</span>` : '';
  const edited = msg.edited ? '<span class="edited">edited</span>' : '';
  const reactionRow = reactions && reactions.size
    ? `<div class="reactions">${[...reactions.entries()].map(([emoji, people]) =>
        `<button data-emoji="${emoji}" data-mine="${people.has(state.serverId)}">${emoji} ${people.size}</button>`).join('')}</div>`
    : '';

  el.innerHTML = `
    <div class="spine"></div>
    <div class="content">
      <div class="head">
        <span class="tag">${escapeHtml(msg.tag || '')}</span>
        <span class="who">${escapeHtml(msg.name || '')}</span>
        ${badge}
        ${time}
      </div>
      <div class="body">${decorate(msg.text)}${edited}</div>
      ${reactionRow}
      ${msg.system ? '' : `<div class="tools">
        <button data-act="react" title="Reaksi">${icon('hand')}</button>
        ${state.staff ? `<button data-act="delete" class="danger" title="Hapus">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8"><path d="M4 7h16M10 11v6M14 11v6M6 7l1 13h10l1-13M9 7V4h6v3"/></svg>
        </button>` : ''}
      </div>`}
    </div>`;

  el.querySelectorAll('.tools button').forEach((btn) => {
    btn.addEventListener('click', () => handleTool(btn.dataset.act, msg));
  });
  el.querySelectorAll('.reactions button').forEach((btn) => {
    btn.addEventListener('click', () => react(msg.id, btn.dataset.emoji));
  });
  return el;
}

function updateFade() {
  const log = $('log');
  log.dataset.scroll = String(log.scrollHeight > log.clientHeight + 1);
}

/* tab tujuan pesan: dari server (channel.tab); notice/legacy/sistem -> Global */
function tabOf(msg) {
  return msg.tab === 'announce' || msg.tab === 'job' ? msg.tab : 'global';
}

function isOpen() { return chat.dataset.open === 'true'; }

/* chat terbuka: hanya pesan tab aktif (tab Job: ikut pilihan channel) */
function inTab(msg, tab) {
  if (tabOf(msg) !== tab) return false;
  if (tab === 'job' && state.jobFilter && state.jobFilter !== 'all') return msg.channel === state.jobFilter;
  return true;
}

/* chat tertutup: feed campuran semua tab, urut waktu datang. Pengumuman yang masih
   baru tetap ikut walau sudah terdorong keluar oleh chat lain. */
const FEED_MAX = 8;
function feedList() {
  const n = state.messages.length;
  const start = Math.max(0, n - FEED_MAX);
  const now = Date.now();
  return state.messages.filter((m, i) =>
    i >= start || (tabOf(m) === 'announce' && now - (m._at || 0) < state.announceFade * 1000));
}

function render() {
  const log = $('log');
  const stick = log.scrollTop + log.clientHeight >= log.scrollHeight - 40;
  log.innerHTML = '';
  const list = isOpen() ? state.messages.filter((m) => inTab(m, state.tab)).slice(-120) : feedList();
  list.forEach((msg) => log.appendChild(messageNode(msg)));
  if (stick || !isOpen()) log.scrollTop = log.scrollHeight;
  updateFade();
}

function addMessage(msg) {
  msg.mention = !msg.system && mentionsMe(msg.text || '');
  msg._at = Date.now();
  if (msg.notice && !msg.tab) msg.tab = state.tab; // notice f_chat (mis. "tidak punya akses") -> tab yang sedang dibuka
  state.messages.push(msg);
  if (state.messages.length > 200) state.messages.shift();
  const tab = tabOf(msg);
  wake(tab === 'announce' ? state.announceFade : 0);

  if (!isOpen()) {
    if (tab !== state.tab) bumpUnread(tab);
    render(); // feed campuran (maks. FEED_MAX baris, murah)
    return;
  }
  if (!inTab(msg, state.tab)) {
    if (tab !== state.tab) bumpUnread(tab);
    return;
  }
  const log = $('log');
  const stick = log.scrollTop + log.clientHeight >= log.scrollHeight - 60;
  log.appendChild(messageNode(msg));
  while (log.children.length > 120) log.removeChild(log.firstChild);
  if (stick) log.scrollTop = log.scrollHeight;
  updateFade();
}

/* ---------- unread ---------------------------------------- */

function bumpUnread(tab) {
  state.unread[tab] = (state.unread[tab] || 0) + 1;
  renderTabs();
}

function renderTabs() {
  const hasJob = jobChannels().length > 0;
  document.querySelectorAll('.tab-btn').forEach((b) => {
    const tab = b.dataset.tab;
    b.dataset.active = String(tab === state.tab);
    if (tab === 'job') b.dataset.hidden = String(!hasJob);
    const n = state.unread[tab] || 0;
    b.querySelector('.unread').textContent = n > 0 ? (n > 99 ? '99+' : String(n)) : '';
  });
}

/* ---------- idle fade ------------------------------------ */

/* holdSec: berapa lama minimal tetap terlihat (pengumuman lebih lama). Pesan biasa
   yang datang belakangan tidak memperpendek waktu tampil pengumuman. */
function wake(holdSec) {
  chat.dataset.idle = 'false';
  clearTimeout(state.idleTimer);
  if (isOpen()) { state.idleUntil = 0; return; }
  if (!(state.fadeAfter > 0)) return; // 0 = never fade
  const hold = Math.max(state.fadeAfter, holdSec || 0) * 1000;
  state.idleUntil = Math.max(state.idleUntil, Date.now() + hold);
  state.idleTimer = setTimeout(() => { chat.dataset.idle = 'true'; }, state.idleUntil - Date.now());
}

/* ---------- channels ------------------------------------- */

function jobChannels() {
  return state.channels.filter((c) => c.tab === 'job');
}

/* channel tujuan ketikan biasa (tanpa '/'); null = tidak bisa kirim langsung */
function setChannel(channel, placeholder) {
  state.channel = channel || null;
  $('composer').style.setProperty('--chan-rgb', rgbOf(channel ? channel.color : null, '224, 164, 88'));
  $('input').placeholder = placeholder || (channel
    ? (channel.radius ? `${channel.label} — terdengar dalam ${Math.round(channel.radius)} m` : `${channel.label} — ketik sesuatu…`)
    : 'Ketik sesuatu…');
}

/* pilihan channel di tab Job: hanya tampil kalau ada lebih dari satu (mis. Polisi + Dispatch, atau staf) */
function renderChips() {
  const list = jobChannels();
  const box = $('chips');
  const show = state.tab === 'job' && list.length > 1;
  box.dataset.on = String(show);
  if (!show) { box.innerHTML = ''; return; }
  const items = [{ id: 'all', label: 'Semua' }, ...list];
  box.innerHTML = items.map((c) =>
    `<button class="chip" data-id="${escapeHtml(c.id)}" data-active="${c.id === state.jobFilter}"` +
    (c.color ? ` style="--chip-rgb:${rgbOf(c.color)}"` : '') + `>${escapeHtml(c.label)}</button>`).join('');
}

function applyJobTarget() {
  const list = jobChannels();
  if (!list.find((c) => c.id === state.jobFilter) && state.jobFilter !== 'all') state.jobFilter = list[0] ? list[0].id : null;
  if (state.jobFilter === 'all' && list.length < 2) state.jobFilter = list[0] ? list[0].id : null;
  if (state.jobFilter === 'all') setChannel(null, 'Pilih job di atas untuk mengirim pesan');
  else setChannel(list.find((c) => c.id === state.jobFilter));
}

/* Pengumuman = /announce saja, Global = obrolan + OOC, Job = chat internal job aktif.
   Pindah tab juga mengganti ke mana ketikan biasa (tanpa '/') dikirim. */
function setTab(tab) {
  if (tab === 'job' && !jobChannels().length) tab = 'global';
  state.tab = tab === 'announce' || tab === 'job' ? tab : 'global';
  state.unread[state.tab] = 0;
  if (state.tab === 'announce') {
    setChannel(null, 'Hanya /announce [pesan] (khusus instansi)');
  } else if (state.tab === 'job') {
    applyJobTarget();
  } else {
    setChannel(state.channels.find((c) => c.default) || state.channels.find((c) => c.tab === 'global'));
  }
  renderTabs();
  renderChips();
  render();
}

$('chips').addEventListener('click', (e) => {
  const btn = e.target.closest('.chip');
  if (!btn) return;
  state.jobFilter = btn.dataset.id;
  applyJobTarget();
  renderChips();
  render();
  $('input').focus();
});

/* ---------- popovers ------------------------------------- */

function closePops(except) {
  ['suggest-pop', 'emoji-pop', 'settings'].forEach((id) => {
    if (id !== except) $(id).dataset.on = 'false';
  });
}
function togglePop(id) {
  const on = $(id).dataset.on === 'true';
  closePops();
  $(id).dataset.on = String(!on);
}

/* ---------- suggestions ---------------------------------- */

function updateSuggestions() {
  const value = $('input').value;
  if (!value.startsWith('/')) { $('suggest-pop').dataset.on = 'false'; return; }
  const term = value.slice(1).split(' ')[0].toLowerCase();
  const matches = state.suggestions
    .filter((s) => s.name.slice(1).toLowerCase().startsWith(term))
    .slice(0, 8);
  if (!matches.length) { $('suggest-pop').dataset.on = 'false'; return; }

  state.sugIndex = Math.min(state.sugIndex, matches.length - 1);
  state.sugMatches = matches;
  $('suggest-list').innerHTML = matches.map((s, i) => `
    <button class="sug-row" data-i="${i}" data-active="${i === state.sugIndex}">
      <span class="cmd">${escapeHtml(s.name)}</span>
      <span class="help">${escapeHtml(s.help || '')}</span>
    </button>`).join('');
  $('suggest-list').querySelectorAll('.sug-row').forEach((row) => {
    row.addEventListener('click', () => acceptSuggestion(matches[row.dataset.i]));
  });
  closePops('suggest-pop');
  $('suggest-pop').dataset.on = 'true';
}

function acceptSuggestion(s) {
  if (!s) return;
  $('input').value = s.name + ' ';
  $('suggest-pop').dataset.on = 'false';
  $('input').focus();
}

/* ---------- sending -------------------------------------- */

function sendMessage() {
  const input = $('input');
  const text = input.value.trim();
  if (!text) return;
  // tanpa '/' dan tidak ada channel tujuan: tab Pengumuman (pengumuman wajib lewat /announce,
  // supaya tidak terkirim tak sengaja hanya karena lupa pindah tab) atau Job -> "Semua"
  if (!text.startsWith('/') && !state.channel) {
    addMessage({ id: -1, channel: 'system', tab: state.tab, tag: 'INFO', color: '#E0A458', icon: 'info', name: '', system: true,
      text: state.tab === 'announce' ? 'Gunakan /announce [pesan] untuk membuat pengumuman.' : 'Pilih job di atas dulu untuk mengirim pesan.' });
    return;
  }
  state.history.push(text);
  state.historyIndex = state.history.length;
  post('send', { channel: state.channel && state.channel.id, text });
  if (!IN_GAME && window.NXDEMO) window.NXDEMO.onSend(text, state.channel);
  input.value = '';
  updateCount();
  closePops();
  post('typing', { channel: state.channel && state.channel.id, state: false });
}

function handleTool(action, msg) {
  if (action === 'delete') {
    post('moderate', { action: 'delete', id: msg.id });
    if (!IN_GAME) deleteMessage(msg.id);
  } else if (action === 'react') {
    state.reactTarget = msg.id;
    togglePop('emoji-pop');
  }
}

function react(id, emoji) {
  post('react', { id, emoji });
  /* in game the server echoes this back to everyone, including us — applying it
     locally too would toggle it twice and instantly cancel our own reaction */
  if (!IN_GAME) applyReaction(id, emoji, state.serverId);
}

function applyReaction(id, emoji, from) {
  if (!state.reactions.has(id)) state.reactions.set(id, new Map());
  const map = state.reactions.get(id);
  if (!map.has(emoji)) map.set(emoji, new Set());
  const people = map.get(emoji);
  if (people.has(from)) people.delete(from); else people.add(from);
  if (!people.size) map.delete(emoji);
  render();
}

function deleteMessage(id) {
  const msg = state.messages.find((m) => m.id === id);
  if (!msg) return;
  msg.text = 'Pesan dihapus oleh staf.';
  msg.deleted = true;
  msg.italic = true;
  render();
}

function addSuggestion(s) {
  state.suggestions = state.suggestions.filter((x) => x.name !== s.name);
  state.suggestions.push(s);
}

function updateCount() {
  const left = state.maxLength - $('input').value.length;
  $('count').textContent = left < 40 ? left : '';
  $('count').dataset.warn = String(left < 15);
}

/* ---------- typing indicator ----------------------------- */

let typingSent = 0;
function pingTyping() {
  const now = Date.now();
  if (now - typingSent < 2200) return;
  typingSent = now;
  post('typing', { channel: state.channel && state.channel.id, state: true });
}

function renderTyping() {
  const now = Date.now();
  for (const [id, entry] of state.typers) if (entry.until < now) state.typers.delete(id);
  const names = [...state.typers.values()].map((t) => t.name);
  $('typing').innerHTML = names.length
    ? (names.length === 1
        ? `<span>${escapeHtml(names[0])}</span> sedang mengetik…`
        : `<span>${names.length}</span> orang sedang mengetik…`)
    : '';
}
setInterval(renderTyping, 700);

/* ---------- focus ---------------------------------------- */

/* buka: tab terakhir dipakai (tab-tab terpisah). tutup: kembali ke feed campuran. */
function setOpen(open) {
  chat.dataset.open = String(open);
  if (open) {
    wake();
    setTab(state.tab);
    $('input').focus();
    $('log').scrollTop = $('log').scrollHeight;
  } else {
    $('input').blur();
    $('input').value = '';
    closePops();
    updateCount();
    render();
    wake();
  }
}

/* ---------- wiring --------------------------------------- */

function buildSettingsPanel() {
  $('theme-swatches').innerHTML = state.themes.map((t) =>
    `<button class="swatch" data-theme="${t.id}" title="${escapeHtml(t.label)}" style="--c:${t.accent}"></button>`).join('');
  $('theme-swatches').querySelectorAll('.swatch').forEach((sw) => {
    sw.addEventListener('click', () => {
      const theme = state.themes.find((t) => t.id === sw.dataset.theme);
      saveSettings({ preset: theme.id, accent: theme.accent });
    });
  });

  $('font-choices').innerHTML = state.fonts.map((f) =>
    `<button class="choice" data-value="${escapeHtml(f)}">${escapeHtml(f)}</button>`).join('');

  document.querySelectorAll('.choices').forEach((group) => {
    group.addEventListener('click', (e) => {
      const btn = e.target.closest('.choice');
      if (!btn) return;
      saveSettings({ [group.dataset.setting]: btn.dataset.value });
    });
  });
  document.querySelectorAll('.toggle').forEach((t) => {
    t.addEventListener('click', () => saveSettings({ [t.dataset.setting]: t.dataset.on !== 'true' }));
  });
  $('accent-picker').addEventListener('input', (e) => saveSettings({ accent: e.target.value }));
  $('size-range').addEventListener('input', (e) => saveSettings({ size: Number(e.target.value) }));
}

$('emoji-btn').addEventListener('click', () => { state.reactTarget = null; togglePop('emoji-pop'); });
$('settings-btn').addEventListener('click', () => togglePop('settings'));
$('send').addEventListener('click', sendMessage);

document.querySelectorAll('.tab-btn').forEach((btn) => {
  btn.addEventListener('click', () => setTab(btn.dataset.tab));
});

$('emoji-grid').innerHTML = EMOJI.map((e) => `<button>${e}</button>`).join('');
$('emoji-grid').addEventListener('click', (e) => {
  const btn = e.target.closest('button');
  if (!btn) return;
  if (state.reactTarget) {
    react(state.reactTarget, btn.textContent);
    state.reactTarget = null;
    closePops();
  } else {
    $('input').value += btn.textContent;
    $('input').focus();
    updateCount();
  }
});

$('input').addEventListener('input', () => {
  updateCount();
  updateSuggestions();
  if ($('input').value.length > 1) pingTyping();
});

$('input').addEventListener('keydown', (e) => {
  const sugOpen = $('suggest-pop').dataset.on === 'true';

  if (e.key === 'Enter') {
    e.preventDefault();
    if (sugOpen && state.sugMatches && $('input').value.split(' ').length === 1) {
      acceptSuggestion(state.sugMatches[state.sugIndex]);
      return;
    }
    sendMessage();
  } else if (e.key === 'Tab') {
    e.preventDefault();
    if (sugOpen && state.sugMatches) acceptSuggestion(state.sugMatches[state.sugIndex]);
  } else if (e.key === 'ArrowUp') {
    if (sugOpen) { e.preventDefault(); state.sugIndex = Math.max(0, state.sugIndex - 1); updateSuggestions(); return; }
    if (state.historyIndex > 0) {
      e.preventDefault();
      state.historyIndex -= 1;
      $('input').value = state.history[state.historyIndex];
      updateCount();
    }
  } else if (e.key === 'ArrowDown') {
    if (sugOpen) { e.preventDefault(); state.sugIndex = Math.min((state.sugMatches || []).length - 1, state.sugIndex + 1); updateSuggestions(); return; }
    if (state.historyIndex < state.history.length - 1) {
      e.preventDefault();
      state.historyIndex += 1;
      $('input').value = state.history[state.historyIndex];
    } else {
      state.historyIndex = state.history.length;
      $('input').value = '';
    }
    updateCount();
  }
});

document.addEventListener('mousedown', (e) => {
  if (!e.target.closest('#stack')) closePops();
});

document.addEventListener('keydown', (e) => {
  if (e.key !== 'Escape') return;
  if (chat.dataset.open !== 'true') return;
  e.preventDefault();
  if (document.querySelector('.pop[data-on="true"]')) { closePops(); return; }
  setOpen(false);
  post('close', {});
});

/* ---------- inbound from the game ------------------------ */

window.addEventListener('message', (event) => {
  const { action, data } = event.data || {};
  if (!action) return;

  if (action === 'init') {
    state.channels = data.channels || [];
    state.themes = data.themes || state.themes;
    state.fonts = data.fonts || state.fonts;
    state.staff = !!data.staff;
    state.serverId = data.serverId || 0;
    state.maxLength = data.maxLength || 220;
    if (typeof data.fadeAfter === 'number') state.fadeAfter = data.fadeAfter;
    if (typeof data.announceFadeAfter === 'number') state.announceFade = data.announceFadeAfter;
    /* merge rather than overwrite: other resources' /commands can arrive
       via chat:addSuggestion(s) before or after this init payload lands */
    (data.suggestions || []).forEach(addSuggestion);
    Object.assign(state.settings, data.defaults || {}, data.settings || {});
    $('input').maxLength = state.maxLength;
    buildSettingsPanel();
    applySettings();
    setTab(state.tab);
    wake();
  } else if (action === 'channels') {
    // ganti job / karakter dimuat: tab Job & pilihan channel ikut job aktif yang baru
    state.channels = data.channels || [];
    state.staff = !!data.staff;
    state.jobFilter = null;
    setTab(state.tab);
  } else if (action === 'message') {
    addMessage(data);
  } else if (action === 'focus') {
    setOpen(data.open);
  } else if (action === 'delete') {
    deleteMessage(data.id);
  } else if (action === 'edit') {
    const msg = state.messages.find((m) => m.id === data.id);
    if (msg) { msg.text = data.text; msg.edited = true; render(); }
  } else if (action === 'react') {
    applyReaction(data.id, data.emoji, data.from);
  } else if (action === 'typing') {
    if (data.state) state.typers.set(data.id, { name: data.name, until: Date.now() + 4000 });
    else state.typers.delete(data.id);
    renderTyping();
  } else if (action === 'suggestion') {
    addSuggestion(data);
  } else if (action === 'removeSuggestion') {
    state.suggestions = state.suggestions.filter((s) => s.name !== data.name);
  } else if (action === 'clear') {
    // /clearchat -> tab yang sedang dibuka; chat:clear / exports clear dari script lain -> semua tab
    const tab = data && data.current ? state.tab : null;
    state.messages = tab ? state.messages.filter((m) => tabOf(m) !== tab) : [];
    if (tab) state.unread[tab] = 0;
    else state.unread = { announce: 0, global: 0, job: 0 };
    renderTabs();
    render();
  }
});

/* preview harness hook — ignored in game */
window.NXSTATE = state;
window.NXAPI = { addMessage, setOpen, setChannel, applySettings, buildSettingsPanel, applyReaction, render };

/* beri tahu Lua halaman sudah siap -> init lokal dikirim tanpa menunggu server */
post('loaded', {});
