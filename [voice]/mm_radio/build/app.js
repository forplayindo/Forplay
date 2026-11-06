/* MM Radio UI — desain I · HUD Taktis (vanilla JS).
   Kontrak pesan NUI & callback SAMA dengan MM Radio asli; tidak ada fungsi yang diubah. */
(() => {
  'use strict';
  const RES = window.GetParentResourceName ? window.GetParentResourceName() : 'mm_radio';
  const $ = id => document.getElementById(id);
  const TABS = ['main', 'members', 'channels', 'settings'];
  const WAVE = [3, 8, 14, 6, 18, 11, 5, 15, 9, 3, 12, 20, 7, 13, 4, 10, 16, 6, 9, 3, 11, 7, 14, 5];

  const S = {
    d: null, max: 500, visible: false,
    page: 'main', pad: false, entry: '',
    list: {}, muted: null, drag: false, prevVol: 30,
    volT: 0, msgT: 0, toastT: 0,
  };
  const ovEls = new Map(), memEls = new Map();

  // ---------- util ----------
  const post = (name, data) =>
    fetch(`https://${RES}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify(data === undefined ? {} : data),
    }).then(r => r.json()).catch(() => null);

  const FALLBACK = {
    'ui.header': 'Connected', 'ui.frequency': 'Frequency', 'ui.disconnect': 'Disconnect',
    'ui.notconnected': 'Not connected', 'ui.settings': 'Settings', 'ui.channels': 'Channels',
    'ui.radio': 'Radio', 'ui.members': 'Members', 'ui.favorites': 'Favorites',
    'ui.recommended': 'Recent', 'ui.hide_overlay': 'Hide overlay', 'ui.show_overlay': 'Show overlay',
    'ui.save': 'Save', 'ui.move_radio': 'Move radio', 'ui.allow_move': 'Allow walking',
    'ui.enableClicks': 'Radio sound', 'ui.name': 'Name', 'ui.radio_size': 'Radio size',
    'ui.overlay_size': 'Overlay size', 'ui.overlay': 'Overlay', 'ui.no_signal': 'NO SIGNAL (JAMMED)',
    'ui.enter_freq': 'Enter frequency', 'ui.no_members': 'No one here yet', 'ui.no_channels': 'Empty',
    'ui.tap_change': 'tap to change', 'ui.channel': 'Channel', 'ui.signal': 'Signal',
    'ui.location': 'Location', 'ui.active': 'active', 'ui.signal_good': 'Good',
    'ui.signal_jammed': 'Jammed', 'ui.cancel': 'Cancel', 'ui.join': 'Join', 'ui.back': 'Back',
    'ui.fav': 'Fav', 'ui.tab_settings': 'Setup', 'ui.mute': 'Mute', 'ui.target': 'Target',
  };
  const L = k => (S.d && S.d.locale && S.d.locale[k]) || FALLBACK[k] || k;
  const fmt = ch => Number(ch).toFixed(2);
  const ud = () => (S.d && S.d.userData) || null;
  const el = (tag, cls, text) => {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text != null) e.textContent = text;
    return e;
  };

  function channelName(ch) {
    const map = (S.d && S.d.channelName) || {};
    const n = Number(ch);
    if (!n) return '';
    return map[String(n)] || (!Number.isInteger(n) && map[Math.floor(n) + '.%']) || '';
  }
  function normList(p) {
    const out = {};
    if (!p) return out;
    if (Array.isArray(p)) p.forEach((v, i) => { if (v) out[String(i + 1)] = v; });
    else for (const k in p) if (p[k]) out[k] = p[k];
    return out;
  }
  function isMuted(id) {
    const m = S.muted; if (!m) return false;
    const n = Number(id);
    return Array.isArray(m) ? !!m[n - 1] : !!(m[id] || m[n]);
  }

  // ---------- teks statis ----------
  function renderLabels() {
    const t = $('tabs').children;
    t[0].textContent = L('ui.radio'); t[1].textContent = L('ui.members');
    t[2].textContent = L('ui.channels'); t[3].textContent = L('ui.tab_settings');
    $('fLbl').textContent = L('ui.frequency');
    $('fHint').textContent = L('ui.tap_change');
    $('kCh').textContent = L('ui.channel'); $('kSig').textContent = L('ui.signal');
    $('kLoc').textContent = L('ui.location'); $('kMem').textContent = L('ui.members');
    $('padLbl').textContent = L('ui.enter_freq') + ' · 1–' + S.max;
    $('padCancel').textContent = L('ui.cancel'); $('padOk').textContent = L('ui.join');
    $('memTitle').textContent = L('ui.members');
    $('favTitle').textContent = L('ui.favorites'); $('recTitle').textContent = L('ui.recommended');
    $('sName').textContent = L('ui.name'); $('saveBtn').textContent = L('ui.save');
    $('sRadioSize').textContent = L('ui.radio_size'); $('sOvSize').textContent = L('ui.overlay_size');
    $('sDrag').textContent = L('ui.move_radio'); $('sMove').textContent = L('ui.allow_move');
    $('sClick').textContent = L('ui.enableClicks');
    $('hBack').textContent = L('ui.back'); $('hFav').textContent = L('ui.fav');
    $('hOff').textContent = L('ui.disconnect');
  }

  // ---------- status bar ----------
  function renderStatus() {
    const d = S.d; if (!d) return;
    $('time').textContent = d.time || '--:--';
    const v = Number(d.volume) || 0;
    $('volTx').textContent = v === 0 ? 'VOL MUTE' : 'VOL ' + v;
    $('muteKey').classList.toggle('mut', v === 0);
    const b = Math.max(0, Math.min(100, Number(d.battery ?? 100)));
    $('batTx').textContent = 'BAT ' + b;
    $('batTx').classList.toggle('low', b <= 15);
  }

  // ---------- halaman radio ----------
  function talkingName() {
    for (const id in S.list) if (S.list[id].isTalking) return S.list[id].name || id;
    return '';
  }
  function renderTx() {
    const n = talkingName();
    $('txName').textContent = 'TX · ' + (n || '—');
    $('txRow').classList.toggle('live', !!n);
    $('wave').classList.toggle('live', !!n);
  }
  function renderMain() {
    const d = S.d; if (!d) return;
    const on = !!(d.onRadio && d.channel), jam = !!d.insideJammerZone;
    $('freq').textContent = on ? fmt(d.channel) : '---.--';
    $('fLbl').textContent = on ? L('ui.header') : L('ui.notconnected');
    $('chn').textContent = on ? (channelName(d.channel) || 'CH ' + fmt(d.channel)) : '—';
    $('sig').textContent = jam ? L('ui.signal_jammed') : on ? L('ui.signal_good') : '—';
    $('sig').classList.toggle('bad', jam);
    $('street').textContent = d.street || '—';
    $('memCount').textContent = on ? Object.keys(S.list).length + ' ' + L('ui.active') : '—';
    renderTx();
    if (!S.msgT) {
      $('msg').textContent = jam ? '> ' + L('ui.no_signal') : '';
      $('msg').className = 'msg' + (jam ? ' bad' : '');
    }
    const fav = !!(d.onRadio && (d.favourite || []).some(c => Number(c) === Number(d.channel)));
    $('hFav').classList.toggle('on', fav);
  }

  // ---------- numpad ----------
  function buildKeys() {
    const box = $('keys');
    for (const k of ['1', '2', '3', '4', '5', '6', '7', '8', '9', '.', '0', '⌫']) {
      const b = el('button', '', k);
      b.dataset.n = k === '⌫' ? 'del' : k;
      if (k === '⌫') b.setAttribute('aria-label', 'Hapus');
      box.appendChild(b);
    }
  }
  function renderPad() {
    $('entry').textContent = S.entry || '—';
    const n = S.entry ? channelName(S.entry) : '';
    $('entryName').textContent = S.entry ? (L('ui.target') + ': ' + (n || 'CH ' + S.entry)) : '';
  }

  // ---------- anggota ----------
  function renderMembers() {
    const ul = $('memList'); ul.textContent = ''; memEls.clear();
    const show = !!(ud() && ud().playerlist && ud().playerlist.show);
    $('ovBtn').hidden = !S.d || S.d.overlay === 'never';
    $('ovBtn').textContent = L('ui.overlay');
    $('ovBtn').classList.toggle('on', show);
    $('ovBtn').title = show ? L('ui.hide_overlay') : L('ui.show_overlay');
    const ids = Object.keys(S.list);
    if (!ids.length) { ul.appendChild(el('li', 'empty', L('ui.no_members'))); return; }
    const frag = document.createDocumentFragment();
    for (const id of ids) {
      const p = S.list[id];
      const li = el('li', p.isTalking ? 'talk' : '');
      li.appendChild(el('span', 'dot'));
      li.appendChild(el('span', 'nm', p.name || id));
      const b = el('button', isMuted(id) ? 'on' : '', L('ui.mute'));
      b.dataset.mute = id;
      li.appendChild(b);
      frag.appendChild(li); memEls.set(id, li);
    }
    ul.appendChild(frag);
  }

  // ---------- channel ----------
  function chList(ul, arr) {
    ul.textContent = '';
    const cur = S.d && S.d.onRadio ? Number(S.d.channel) : -1;
    const uniq = [...new Set((arr || []).map(Number))].filter(n => n > 0);
    if (!uniq.length) { ul.appendChild(el('li', 'empty', L('ui.no_channels'))); return; }
    const frag = document.createDocumentFragment();
    for (const c of uniq) {
      const li = el('li', c === cur ? 'cur' : '');
      li.dataset.join = c;
      li.appendChild(el('b', '', fmt(c)));
      li.appendChild(el('span', 'nm', channelName(c)));
      frag.appendChild(li);
    }
    ul.appendChild(frag);
  }
  function renderChannels() {
    if (!S.d) return;
    chList($('favList'), S.d.favourite);
    chList($('recList'), (S.d.recomended || []).slice().reverse());
  }

  // ---------- pengaturan ----------
  function renderSettings() {
    const u = ud(); if (!u) return;
    if (document.activeElement !== $('nameIn')) $('nameIn').value = u.name || '';
    $('radioSize').value = u.radioSizeMultiplier ?? 50;
    $('ovSize').value = u.overlaySizeMultiplier ?? 50;
    $('ovSizeRow').hidden = S.d.overlay === 'never';
    $('moveChk').checked = !!u.allowMovement;
    $('clickChk').checked = !!u.enableClicks;
    $('dragChk').checked = S.drag;
    $('radioSize').disabled = $('ovSize').disabled = S.drag;
  }

  function renderPage() {
    const cur = S.page === 'main' && S.pad ? 'pad' : S.page;
    for (const s of document.querySelectorAll('.pg')) s.hidden = s.dataset.pg !== cur;
    for (const b of $('tabs').children) b.classList.toggle('on', b.dataset.go === S.page);
    if (cur === 'main') renderMain();
    else if (cur === 'pad') renderPad();
    else if (cur === 'members') renderMembers();
    else if (cur === 'channels') renderChannels();
    else renderSettings();
  }
  function renderAll() { renderLabels(); renderStatus(); renderPage(); placeRadio(); renderOverlay(); }

  // ---------- posisi & ukuran ----------
  // Geser dasar ke kiri dari tepi kanan layar (px). Posisi simpanan pemain tetap dihormati.
  const BASE_RIGHT = 48;
  function placeRadio() {
    const u = ud(); if (!u) return;
    const r = $('radio'), c = (u.radio && u.radio.coords) || { x: 10, y: 15 };
    r.style.right = (Number(c.x) + BASE_RIGHT) + 'px';
    r.style.bottom = c.y + 'px';
    r.style.transform = `translateY(${S.ty || 0}px) scale(${(u.radioSizeMultiplier ?? 50) / 50})`;
  }
  // jarak supaya radio benar-benar di bawah layar
  function offscreen() {
    const r = $('radio'), u = ud();
    const sc = ((u && u.radioSizeMultiplier) ?? 50) / 50;
    const b = (u && u.radio && u.radio.coords && Number(u.radio.coords.y)) || 0;
    return Math.ceil(r.offsetHeight * sc + b + 40);
  }
  // animasi sekali jalan (bukan berulang): naik saat buka, turun saat tutup
  let animT = 0;
  function slideIn() {
    const r = $('radio');
    clearTimeout(animT);
    r.classList.remove('anim-in', 'anim-out');
    r.hidden = false;
    S.ty = offscreen(); placeRadio();
    void r.offsetHeight;
    r.classList.add('anim-in');
    S.ty = 0; placeRadio();
    animT = setTimeout(() => r.classList.remove('anim-in'), 400);
  }
  function slideOut() {
    const r = $('radio');
    clearTimeout(animT);
    r.classList.remove('anim-in');
    r.classList.add('anim-out');
    S.ty = offscreen(); placeRadio();
    animT = setTimeout(() => {
      r.classList.remove('anim-out');
      if (!S.visible) r.hidden = true;
      S.ty = 0;
    }, 300);
  }

  // ---------- overlay ----------
  function overlayActive() {
    const d = S.d, u = ud();
    return !!(d && u && d.overlay !== 'never' && d.onRadio && u.playerlist && u.playerlist.show);
  }
  function renderOverlay() {
    const ov = $('ov');
    if (!overlayActive()) { ov.hidden = true; ov.textContent = ''; ovEls.clear(); return; }
    const u = ud(), c = u.playerlist.coords || { x: 15, y: 40 };
    ov.style.right = c.x + 'px';
    ov.style.top = c.y + 'px';
    ov.style.transform = `scale(${(u.overlaySizeMultiplier ?? 50) / 50})`;
    const editing = S.visible && (S.drag || S.page === 'settings');
    ov.classList.toggle('all', S.d.overlay === 'always' || editing);
    ov.classList.toggle('drag', S.visible && S.drag);
    ov.textContent = ''; ovEls.clear();
    const frag = document.createDocumentFragment();
    for (const id in S.list) {
      const div = el('div', S.list[id].isTalking ? 'talk' : '', S.list[id].name || id);
      frag.appendChild(div); ovEls.set(id, div);
    }
    ov.appendChild(frag);
    ov.hidden = false;
  }

  // ---------- notifikasi ----------
  function notify(msg, dur) {
    dur = dur || 5000;
    if (S.visible) {
      const m = $('msg');
      m.textContent = '> ' + msg; m.className = 'msg';
      clearTimeout(S.msgT);
      S.msgT = setTimeout(() => { S.msgT = 0; if (S.page === 'main' && !S.pad) renderMain(); }, dur);
    } else {
      const t = $('toast');
      t.textContent = msg; t.hidden = false;
      clearTimeout(S.toastT);
      S.toastT = setTimeout(() => { t.hidden = true; }, dur);
    }
  }

  // ---------- aksi ----------
  function go(p) {
    S.page = p; S.pad = false; S.entry = '';
    renderPage();
    if (p === 'members') post('getMutedList').then(m => { S.muted = m; if (S.page === 'members') renderMembers(); });
    if (overlayActive()) renderOverlay();
  }
  function step(dir) {
    const i = TABS.indexOf(S.page);
    go(TABS[(i + dir + TABS.length) % TABS.length]);
  }
  function openPad() { S.page = 'main'; S.pad = true; S.entry = ''; renderPage(); }
  function closePad() { S.pad = false; S.entry = ''; renderPage(); }
  function type(ch) {
    if (!S.pad) openPad();
    let e = S.entry;
    if (ch === '.') { if (e.includes('.')) return; if (!e) e = '0'; }
    else if (e.includes('.') && e.split('.')[1].length >= 2) return;
    const next = e + ch;
    if (next.length > 6 || parseFloat(next) > S.max) return;
    S.entry = next; renderPad();
  }
  function del() { if (!S.pad || !S.entry) return; S.entry = S.entry.slice(0, -1); renderPad(); }
  function ok() {
    if (!S.pad || !S.entry) return;
    const v = S.entry; closePad();
    post('join', v);
  }
  function setVolume(v) {
    if (!S.d) return;
    v = Math.max(0, Math.min(100, Math.round(v)));
    if (v === S.d.volume) return;
    S.d.volume = v; renderStatus();
    clearTimeout(S.volT);
    S.volT = setTimeout(() => post('volumeChange', v), 300);
  }
  function toggleMute() {
    if (!S.d) return;
    clearTimeout(S.volT);
    const v = Number(S.d.volume) || 0;
    if (v > 0) { S.prevVol = v; S.d.volume = 0; } else S.d.volume = S.prevVol || 30;
    renderStatus();
    post('toggleMute', S.d.volume);
  }
  function toggleFav() {
    const d = S.d; if (!d || !d.onRadio) return;
    const ch = Number(d.channel);
    d.favourite = d.favourite || [];
    const i = d.favourite.findIndex(c => Number(c) === ch);
    if (i >= 0) { d.favourite.splice(i, 1); post('removeFav', ch); }
    else { d.favourite.push(ch); post('addFav', ch); }
    if (S.page === 'main' && !S.pad) renderMain();
    if (S.page === 'channels') renderChannels();
    $('hFav').classList.toggle('on', i < 0);
  }
  function hide() {
    if (!S.visible) return;
    S.visible = false; S.drag = false; S.pad = false; S.entry = '';
    slideOut();
    $('radio').classList.remove('drag');
    if (document.activeElement) document.activeElement.blur();
    renderOverlay();
  }

  // ---------- drag ----------
  function dragger(node, read, write, save) {
    node.addEventListener('pointerdown', e => {
      if (!S.drag || e.button !== 0) return;
      if (node === $('radio') && e.target.closest('button,input,.bezel,.knob')) return;
      e.preventDefault();
      node.setPointerCapture(e.pointerId);
      let { x, y } = read(), raf = 0;
      const move = ev => {
        x -= ev.movementX; y += write.dy(ev.movementY);
        const r = node.getBoundingClientRect();
        x = Math.max(-BASE_RIGHT, Math.min(x, innerWidth - r.width - BASE_RIGHT));
        y = Math.max(0, Math.min(y, innerHeight - r.height));
        if (!raf) raf = requestAnimationFrame(() => { raf = 0; write.apply(x, y); });
      };
      const up = () => {
        node.removeEventListener('pointermove', move);
        node.removeEventListener('pointerup', up);
        write.apply(x, y); save(x, y);
      };
      node.addEventListener('pointermove', move);
      node.addEventListener('pointerup', up);
    });
  }
  dragger($('radio'),
    () => { const c = ud().radio.coords; return { x: Number(c.x) || 0, y: Number(c.y) || 0 }; },
    { dy: m => -m, apply: (x, y) => { ud().radio.coords = { x, y }; placeRadio(); } },
    (x, y) => post('updateRadioPosition', { x, y }));
  dragger($('ov'),
    () => { const c = ud().playerlist.coords; return { x: Number(c.x) || 0, y: Number(c.y) || 0 }; },
    { dy: m => m, apply: (x, y) => { const o = $('ov'); ud().playerlist.coords = { x, y }; o.style.right = x + 'px'; o.style.top = y + 'px'; } },
    (x, y) => post('updatePlayerListPosition', { x, y }));

  // ---------- event UI ----------
  buildKeys();
  $('freqBtn').addEventListener('click', openPad);
  $('keys').addEventListener('click', e => {
    const b = e.target.closest('button'); if (!b) return;
    b.dataset.n === 'del' ? del() : type(b.dataset.n);
  });
  $('padCancel').addEventListener('click', closePad);
  $('padOk').addEventListener('click', ok);
  $('tabs').addEventListener('click', e => { const b = e.target.closest('button'); if (b) go(b.dataset.go); });
  $('hBack').addEventListener('click', () => { if (S.pad) closePad(); else if (S.page !== 'main') go('main'); });
  $('hFav').addEventListener('click', toggleFav);
  $('hOff').addEventListener('click', () => { closePad(); post('leave'); });
  $('muteKey').addEventListener('click', toggleMute);
  $('vUp').addEventListener('click', () => setVolume((S.d?.volume || 0) + 10));
  $('vDn').addEventListener('click', () => setVolume((S.d?.volume || 0) - 10));
  $('knob').addEventListener('wheel', e => { e.preventDefault(); setVolume((S.d?.volume || 0) + (e.deltaY < 0 ? 5 : -5)); }, { passive: false });

  $('memList').addEventListener('click', e => {
    const b = e.target.closest('[data-mute]'); if (!b) return;
    post('togglemutePlayer', Number(b.dataset.mute)).then(m => { if (m != null) { S.muted = m; renderMembers(); } });
  });
  $('ovBtn').addEventListener('click', () => {
    const u = ud(); if (!u) return;
    u.playerlist.show = !u.playerlist.show;
    post('showPlayerList', u.playerlist.show);
    renderMembers(); renderOverlay();
  });
  const chClick = e => { const li = e.target.closest('[data-join]'); if (li) post('join', li.dataset.join); };
  $('favList').addEventListener('click', chClick);
  $('recList').addEventListener('click', chClick);

  $('saveBtn').addEventListener('click', () => {
    const n = $('nameIn').value.trim(); if (!n || !ud()) return;
    ud().name = n; post('saveData', { name: n, radioId: S.d.radioId }); $('nameIn').blur();
  });
  $('nameIn').addEventListener('keydown', e => { e.stopPropagation(); if (e.key === 'Enter') $('saveBtn').click(); });
  const sizeIn = () => {
    const u = ud(); if (!u) return;
    u.radioSizeMultiplier = Number($('radioSize').value);
    u.overlaySizeMultiplier = Number($('ovSize').value);
    placeRadio(); renderOverlay();
  };
  const sizeSave = () => { const u = ud(); if (u) post('updateRadioSize', { radio: u.radioSizeMultiplier, overlay: u.overlaySizeMultiplier }); };
  for (const id of ['radioSize', 'ovSize']) { $(id).addEventListener('input', sizeIn); $(id).addEventListener('change', sizeSave); }
  $('dragChk').addEventListener('change', e => {
    S.drag = e.target.checked;
    $('radio').classList.toggle('drag', S.drag);
    renderSettings(); renderOverlay();
  });
  $('moveChk').addEventListener('change', e => { if (ud()) ud().allowMovement = e.target.checked; post('allowMovement', e.target.checked); });
  $('clickChk').addEventListener('change', e => { if (ud()) ud().enableClicks = e.target.checked; post('enableClicks', e.target.checked); });

  window.addEventListener('keydown', e => {
    if (!S.visible) return;
    // Tutup radio: Esc, atau tombol yang sama seperti membuka (default "=")
    if (e.key === 'Escape') { post('hideUI'); hide(); return; }
    if (e.target.tagName === 'INPUT' && !/range|checkbox/.test(e.target.type)) return;
    const ck = String((S.d && S.d.closeKey) || '=').toUpperCase();
    if (!e.repeat && e.key.toUpperCase() === ck) { e.preventDefault(); post('hideUI'); hide(); return; }
    if (/^[0-9.]$/.test(e.key)) type(e.key);
    else if (e.key === 'Backspace') del();
    else if (e.key === 'Enter') ok();
    else if (e.key === 'ArrowLeft') step(-1);
    else if (e.key === 'ArrowRight') step(1);
  });

  // ---------- pesan dari Lua ----------
  const H = {
    setRadioVisible(d) {
      S.d = d; if (d.maxChannel) S.max = Number(d.maxChannel);
      if (d.volume > 0) S.prevVol = d.volume;
      S.visible = true; S.pad = false; S.entry = '';
      renderAll();
      slideIn();
    },
    updateRadio(d) {
      S.d = Object.assign(S.d || {}, d);
      if (!d.onRadio) S.list = {};
      if (S.visible) { renderStatus(); renderPage(); placeRadio(); }
      renderOverlay();
    },
    setRadioHide: hide,
    updateTime(t) { if (S.d) { S.d.time = t; if (S.visible) $('time').textContent = t; } },
    insideJammer(v) { if (S.d) { S.d.insideJammerZone = v; if (S.visible && S.page === 'main' && !S.pad) renderMain(); } },
    notify(d) { if (d && d.msg) notify(d.msg, d.duration); },
    updateRadioList(p) {
      S.list = normList(p);
      if (S.visible) {
        if (S.page === 'members') renderMembers();
        else if (S.page === 'main' && !S.pad) renderMain();
      }
      renderOverlay();
    },
    updateRadioTalking(d) {
      const p = S.list[d.radioId]; if (!p) return;
      p.isTalking = !!d.radioTalking;
      ovEls.get(d.radioId)?.classList.toggle('talk', p.isTalking);
      memEls.get(d.radioId)?.classList.toggle('talk', p.isTalking);
      if (S.visible) renderTx();
    },
  };
  H.UpdateTime = H.updateTime;

  // gelombang suara: dibuat sekali, hanya tampil saat ada yang bicara (tanpa animasi)
  const wv = $('wave');
  for (const h of WAVE) { const i = document.createElement('i'); i.style.height = h + 'px'; wv.appendChild(i); }

  window.addEventListener('message', e => {
    const m = e.data; if (!m || !m.action) return;
    const fn = H[m.action]; if (fn) fn(m.data);
  });
})();
