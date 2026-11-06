(() => {
  const root = document.getElementById('root');
  const cards = new Map(); // id -> entry
  let cfg = {
    locale: { copy: 'Salin ID', copied: 'Tersalin', noDiscord: 'Tidak terhubung' },
    tag: '4PLAY', key: 'E', drawDistance: 30, scale: 0.7,
  };
  let uiScale = window.innerHeight / 1080;
  window.addEventListener('resize', () => { uiScale = window.innerHeight / 1080; });

  const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : '4play-combatlog';
  fetch(`https://${resource}/ready`, { method: 'POST', body: '{}' })
    .then(r => r.json())
    .then(c => { if (c) cfg = Object.assign(cfg, c); })
    .catch(() => {});

  // Ikon statis (bukan data pemain), aman dipasang sebagai markup
  const ICON_WARN = '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="#F3B354" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.3 3.9 1.8 18a2 2 0 0 0 1.7 3h17a2 2 0 0 0 1.7-3L13.7 3.9a2 2 0 0 0-3.4 0z"/><path d="M12 9v4"/><path d="M12 17h.01"/></svg>';
  const ICON_CHAT = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#A5AEFF" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12a8 8 0 0 1-11.8 7L4 20l1-4.6A8 8 0 1 1 21 12z"/></svg>';
  const ICON_CHAT_OFF = '<svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="#9AA1B2" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M21 12a8 8 0 0 1-11.8 7L4 20l1-4.6A8 8 0 1 1 21 12z"/><path d="M4 4l16 16"/></svg>';
  const ICON_CHECK = '<svg class="cl-check" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M20 6 9 17l-5-5"/></svg>';

  const el = (tag, cls, text) => {
    const e = document.createElement(tag);
    if (cls) e.className = cls;
    if (text !== undefined) e.textContent = text; // textContent: nama pemain tidak bisa menyuntik HTML
    return e;
  };

  const fmtAgo = (s) => {
    if (s < 60) return `${s}s ago`;
    const m = Math.floor(s / 60), r = s % 60;
    return r ? `${m}m ${r}s ago` : `${m}m ago`;
  };

  function add(d) {
    if (cards.has(d.id)) return;
    const wrap = el('div', 'cl');
    const line = el('div', 'cl-line');
    const dot = el('div', 'cl-dot');
    const card = el('div', 'cl-card');

    // Header
    const head = el('div', 'cl-head');
    const icon = el('div', 'cl-icon'); icon.innerHTML = ICON_WARN;
    const who = el('div', 'cl-who');
    const nameRow = el('div', 'cl-nameRow');
    nameRow.append(el('span', 'cl-name', d.name), el('span', 'cl-sid', `#${d.serverId}`));
    const meta = el('span', 'cl-meta');
    who.append(nameRow, meta);
    const tag = el('div', 'cl-tag');
    tag.append(el('b', null, cfg.tag), el('span', null, 'COMBAT LOG'));
    head.append(icon, who, tag);

    // Discord
    const disc = el('div', 'cl-disc' + (d.discord ? '' : ' none'));
    const dicon = el('div', 'cl-dicon'); dicon.innerHTML = d.discord ? ICON_CHAT : ICON_CHAT_OFF;
    const dtext = el('div', 'cl-dtext');
    dtext.append(el('span', 'cl-dlabel', 'Discord ID'), el('span', 'cl-did', d.discord || cfg.locale.noDiscord));
    disc.append(dicon, dtext);
    let btnLabel = null;
    {
      const btn = el('div', 'cl-btn');
      btn.innerHTML = ICON_CHECK;
      btn.prepend(el('kbd', null, cfg.key));
      btnLabel = el('span', null, cfg.locale.copy);
      btn.append(btnLabel);
      disc.append(btn);
    }

    // Timer
    const bar = el('div', 'cl-bar');
    const fill = el('i');
    bar.append(fill);

    card.append(head, el('div', 'cl-sep'), disc, bar);
    wrap.append(line, dot, card);
    root.append(wrap);

    const totalMs = d.duration * 1000;
    const remainingMs = Math.max(0, totalMs - d.age * 1000);
    fill.style.transform = `scaleX(${remainingMs / totalMs})`;
    // Satu transisi CSS untuk seluruh durasi — tidak ada update per-frame
    requestAnimationFrame(() => requestAnimationFrame(() => {
      fill.style.transition = `transform ${remainingMs}ms linear`;
      fill.style.transform = 'scaleX(0)';
    }));

    const entry = {
      wrap, line, dot, card, meta, btnLabel,
      reason: d.reason,
      createdAt: Date.now() - d.age * 1000,
      expiresAt: Date.now() + remainingMs,
      dist: 0, visible: false, copyTimer: null,
    };
    cards.set(d.id, entry);
    updateMeta(entry);
  }

  function updateMeta(e) {
    const age = Math.floor((Date.now() - e.createdAt) / 1000);
    e.meta.textContent = `${e.reason} · ${e.dist} m away · ${fmtAgo(age)}`;
    e.wrap.classList.toggle('fading', e.expiresAt - Date.now() < 10000);
  }

  function remove(id) {
    const e = cards.get(id);
    if (!e) return;
    clearTimeout(e.copyTimer);
    e.wrap.remove();
    cards.delete(id);
  }

  function update({ items, active }) {
    const W = window.innerWidth, H = window.innerHeight;
    const seen = new Set();

    for (const it of items) {
      const e = cards.get(it.id);
      if (!e) continue;
      seen.add(it.id);

      const gx = it.gx / 1000 * W, gy = it.gy / 1000 * H;
      const tx = it.tx / 1000 * W, ty = it.ty / 1000 * H;
      const dx = gx - tx, dy = gy - ty;
      const len = Math.hypot(dx, dy);
      const ang = Math.atan2(-dx, dy);
      const s = uiScale * cfg.scale * Math.max(0.65, 1 - (it.dist / cfg.drawDistance) * 0.35);

      e.line.style.height = `${len}px`;
      e.line.style.transform = `translate3d(${tx}px,${ty}px,0) rotate(${ang}rad)`;
      e.dot.style.transform = `translate3d(${gx}px,${gy}px,0)`;
      e.card.style.transform = `translate3d(${tx}px,${ty - 6}px,0) translate(-50%,-100%) scale(${s})`;

      if (e.dist !== it.dist) { e.dist = it.dist; updateMeta(e); }
      e.wrap.classList.toggle('ready', it.id === active);
      if (!e.visible) { e.visible = true; e.wrap.classList.add('show'); updateMeta(e); }
    }

    for (const [id, e] of cards) {
      if (!seen.has(id) && e.visible) { e.visible = false; e.wrap.classList.remove('show'); }
    }
  }

  function hideAll() {
    for (const e of cards.values()) { e.visible = false; e.wrap.classList.remove('show'); }
  }

  function copied(id) {
    const e = cards.get(id);
    if (!e || !e.btnLabel) return;
    e.wrap.classList.add('copied');
    e.btnLabel.textContent = cfg.locale.copied;
    clearTimeout(e.copyTimer);
    e.copyTimer = setTimeout(() => {
      e.wrap.classList.remove('copied');
      e.btnLabel.textContent = cfg.locale.copy;
    }, 2000);
  }

  // Satu timer untuk semua kartu, hanya menyentuh kartu yang sedang terlihat
  setInterval(() => {
    for (const e of cards.values()) if (e.visible) updateMeta(e);
  }, 1000);

  window.addEventListener('message', ({ data: msg }) => {
    if (!msg || !msg.action) return;
    switch (msg.action) {
      case 'add': add(msg.data); break;
      case 'remove': remove(msg.data); break;
      case 'update': update(msg.data); break;
      case 'hideAll': hideAll(); break;
      case 'copied': copied(msg.data); break;
    }
  });
})();
