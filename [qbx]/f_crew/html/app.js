// Gang Wars NUI: menu /peranggang (map, wilayah, perang, riwayat, leaderboard, reward, editor admin)
// + HUD (hitung mundur top-center, scoreboard kanan tengah). Semua data dari server; NUI hanya
// menampilkan. Hitung mundur dihitung di sini dari sisa detik yang dikirim server.
'use strict';

const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'f_crew';
const $ = s => document.querySelector(s);
const $$ = s => document.querySelectorAll(s);
const MIN = 60000;

function post(name, data) {
    return fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data ?? {}) })
        .then(r => r.json()).catch(() => ({ ok: false, err: 'NUI tidak merespons.' }));
}
const call = (name, payload) => post('turfCall', { name, payload });

const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const arr = v => Array.isArray(v) ? v : [];
const color = c => /^#[0-9a-f]{6}$/i.test(c || '') ? c : '#9ca3af';
const gdot = c => `<span class="dot" style="background:${color(c)}"></span>`;
const mmss = ms => { const s = Math.max(0, Math.ceil(ms / 1000)); return `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`; };
const hm = sec => { const m = Math.max(1, Math.ceil(sec / 60)); const h = Math.floor(m / 60); return h ? `${h} jam ${m % 60} menit` : `${m} menit`; };
const fmtItems = items => arr(items).map(([n, q]) => `${q}x ${n}`).join(', ') || '—';
const fmtSec = sec => { const s = Math.max(0, Math.floor(sec || 0)); return `${Math.floor(s / 60)}:${String(s % 60).padStart(2, '0')}`; };
const fmtDate = t => { const d = new Date(t * 1000); const p = n => String(n).padStart(2, '0'); return `${p(d.getDate())}/${p(d.getMonth() + 1)} ${p(d.getHours())}:${p(d.getMinutes())}`; };

// Kalibrasi peta: html/map.jpg 2048x2048 mencakup batas dunia ini (sama dengan app Maps f_phone).
const WORLD = { xMin: -5355, xMax: 6167, yMin: -3833, yMax: 7688 };
const SX = 2048 / (WORLD.xMax - WORLD.xMin), SY = 2048 / (WORLD.yMax - WORLD.yMin);
const toImg = ([x, y]) => [(x - WORLD.xMin) * SX, (WORLD.yMax - y) * SY];
const toGame = (px, py) => [Math.round((px / SX + WORLD.xMin) * 100) / 100, Math.round((WORLD.yMax - py / SY) * 100) / 100];

// ------------------------------------------------------------------ state menu
let D = null;          // data terakhir dari server
const POINTS = {};     // id wilayah -> titik (hanya dikirim saat full)
let gotAt = 0;         // Date.now() saat data diterima (dasar hitung mundur)
let myPos = null;
let isOpen = false;
let tab = 'map';
let selected = null;
let draft = null;      // { id?, label, min, items: [[name, qty]], pts: [[x, y]], mode: 'points'|'flag', flag: [x, y, z?]?, pickFlag }
let zoneFilter = 'all', histFilter = 'all';
let historyRows = null, rewardRows = null, flagRows = null;
let pollTimer = null;

const endsAt = left => gotAt + left * 1000;
const zoneOf = id => D && D.zones.find(z => z.id === id);

function toast(text, kind = '') {
    const t = $('#toast');
    t.textContent = text; t.className = 'toast ' + kind;
    clearTimeout(t._t); t._t = setTimeout(() => t.classList.add('hidden'), 2800);
}

function applyData(data) {
    // tabel Lua kosong bisa datang sebagai {} -> paksa jadi array
    data.zones = arr(data.zones); data.wars = arr(data.wars); data.board = arr(data.board);
    for (const z of data.zones) z.reward = arr(z.reward);
    for (const w of data.wars) w.parts = arr(w.parts);
    D = data; gotAt = Date.now();
    if (data.pos) myPos = data.pos;
    for (const z of data.zones) if (z.points) POINTS[z.id] = z.points;
    for (const id of Object.keys(POINTS)) if (!zoneOf(id)) delete POINTS[id];
    if (selected && !zoneOf(selected)) selected = null;
}

async function refresh(full) {
    const res = await call('data', !!full);
    if (!res.ok) { toast(res.err, 'err'); return; }
    applyData(res.data);
    renderAll();
}

function open(data, pos) {
    applyData(data); if (pos) myPos = pos;
    isOpen = true;
    const img = $('#map-img'); if (!img.src) img.src = 'map.jpg';
    $('#panel').classList.remove('hidden');
    historyRows = null; rewardRows = null;
    if ((!D.me && tab === 'reward') || (!D.admin && tab === 'flags')) tab = 'map';
    switchTab(tab);
    if (!view.init) { centerOn(myPos || [150, -900], 1.4); view.init = true; }
    clearInterval(pollTimer);
    pollTimer = setInterval(() => isOpen && refresh(false), 15000);
}

function close() {
    if (!isOpen) return;
    isOpen = false;
    clearInterval(pollTimer);
    $('#panel').classList.add('hidden');
    $('#modal').classList.add('hidden');
    post('close');
}
$('#close').onclick = close;
document.addEventListener('keydown', e => {
    if (e.key !== 'Escape' || !isOpen) return;
    if (!$('#modal').classList.contains('hidden')) return $('#modal').classList.add('hidden');
    close();
});

// ------------------------------------------------------------------ status wilayah
function zoneState(z) {
    if (z.phase) {
        const e = endsAt(z.left);
        return { key: z.phase, cls: 'st-' + z.phase, ends: e, pre: z.phase === 'prep' ? 'Persiapan ' : 'Perang ', text: (z.phase === 'prep' ? 'Persiapan ' : 'Perang ') + mmss(e - Date.now()) };
    }
    const cdLeft = z.cd - (Date.now() - gotAt) / 1000;
    if (cdLeft > 0) return { key: 'cd', cls: 'st-cd', text: 'Cooldown ' + hm(cdLeft) };
    return z.owner ? { key: 'owned', cls: 'st-owned', text: 'Dikuasai' } : { key: 'free', cls: 'st-free', text: 'Bebas' };
}

function actionButton(z) {
    const a = z.act;
    if (!a) return '';
    return `<div><button class="btn war full" data-act="${esc(z.id)}" ${a.ok ? '' : 'disabled'}>${esc(a.label)}</button>${a.ok ? '' : `<div class="reason">⚠ ${esc(a.reason)}</div>`}</div>`;
}
function bindActs(root) {
    root.querySelectorAll('[data-act]').forEach(b => b.onclick = () => openRules(zoneOf(b.dataset.act), 'start'));
}

// ------------------------------------------------------------------ MAP
const map = $('#map'), inner = $('#map-inner'), svg = $('#svg');
const view = { s: 1.4, x: 0, y: 0, init: false };

function applyView() { inner.style.transform = `translate(${view.x}px,${view.y}px) scale(${view.s})`; }
function centerOn(p, s) {
    const [px, py] = toImg(p); if (s) view.s = s;
    view.x = map.clientWidth / 2 - px * view.s; view.y = map.clientHeight / 2 - py * view.s; applyView();
}
function zoomAt(f, cx, cy) {
    const ns = Math.min(6, Math.max(0.35, view.s * f));
    view.x = cx - (cx - view.x) * ns / view.s; view.y = cy - (cy - view.y) * ns / view.s; view.s = ns; applyView();
}
function evImg(e) { const r = map.getBoundingClientRect(); return [(e.clientX - r.left - view.x) / view.s, (e.clientY - r.top - view.y) / view.s]; }

function renderMap() {
    if (!D) return;
    let h = '';
    for (const z of D.zones) {
        const pts = POINTS[z.id];
        if (!pts) continue;
        const st = zoneState(z);
        const cls = ['zone', z.owner ? 'owned' : 'free', st.key === 'war' ? 'war' : '', st.key === 'prep' ? 'prep' : '', selected === z.id ? 'sel' : ''].join(' ');
        const fill = z.owner ? `fill="${color(z.color)}" stroke="${color(z.color)}"` : '';
        h += `<polygon class="${cls}" data-id="${esc(z.id)}" points="${pts.map(p => toImg(p).join(',')).join(' ')}" ${fill}/>`;
        let cx = 0, cy = 0;
        for (const p of pts) { cx += p[0] / pts.length; cy += p[1] / pts.length; }
        const [lx, ly] = toImg([cx, cy]);
        h += `<text class="zlabel" x="${lx}" y="${ly}">${esc(z.label)}</text>`;
        if (z.mode === 'flag' && z.fpt && !(draft && draft.id === z.id)) {
            const [fx, fy] = toImg(z.fpt);
            h += `<text class="fpin" x="${fx}" y="${fy - 10 / view.s}" style="font-size:${18 / view.s + 6}px">${z.flag ? '🚩' : '🏳️'}</text>`;
        }
    }
    if (draft && draft.mode === 'flag' && draft.flag) {
        const [fx, fy] = toImg(draft.flag);
        h += `<text class="fpin" x="${fx}" y="${fy - 10 / view.s}" style="font-size:${18 / view.s + 8}px">🚩</text>`;
    }
    if (draft && draft.pts.length) {
        const pts = draft.pts.map(p => toImg(p).join(',')).join(' ');
        h += draft.pts.length > 2 ? `<polygon class="draft" points="${pts}"/>` : `<polyline class="draft" fill="none" points="${pts}"/>`;
        draft.pts.forEach((p, i) => { const [x, y] = toImg(p); h += `<circle class="vtx ${i ? '' : 'first'}" data-i="${i}" cx="${x}" cy="${y}" r="${5 / view.s + 2}"/>`; });
    }
    if (myPos) { const [mx, my] = toImg(myPos); h += `<circle class="me" cx="${mx}" cy="${my}" r="${4 / view.s + 2}"/>`; }
    svg.innerHTML = h;
    map.classList.toggle('drawing', !!draft);
    $('#draw-hint').classList.toggle('hidden', !draft);
    $('#draw-hint').textContent = draft && draft.pickFlag ? 'Klik di dalam wilayah untuk menaruh titik bendera'
        : 'Klik kiri = tambah titik · Drag titik = geser · Klik kanan titik = hapus · Scroll = zoom';
}

let drag = null;
map.addEventListener('mousedown', e => {
    if (e.button !== 0) return;
    const v = e.target.closest('.vtx');
    drag = v ? { vtx: +v.dataset.i } : { sx: e.clientX, sy: e.clientY, vx: view.x, vy: view.y, moved: false };
});
window.addEventListener('mousemove', e => {
    if (!isOpen) return;
    if (drag && drag.vtx !== undefined && draft) { const [px, py] = evImg(e); draft.pts[drag.vtx] = toGame(px, py); renderMap(); return; }
    if (drag) {
        const dx = e.clientX - drag.sx, dy = e.clientY - drag.sy;
        if (Math.abs(dx) + Math.abs(dy) > 4) drag.moved = true;
        if (drag.moved) { view.x = drag.vx + dx; view.y = drag.vy + dy; applyView(); }
    }
    const pg = e.target.closest && e.target.closest('polygon.zone');
    const tip = $('#tip');
    if (pg && !drag && !draft) {
        const z = zoneOf(pg.dataset.id);
        if (!z) return;
        const st = zoneState(z), r = map.getBoundingClientRect();
        tip.innerHTML = `<b>${esc(z.label)}</b>${z.owner ? esc(z.owner) : 'Belum dikuasai'}<br><span class="status ${st.cls}" style="margin-top:5px">${esc(st.text)}</span>`;
        tip.style.left = (e.clientX - r.left + 14) + 'px'; tip.style.top = (e.clientY - r.top + 14) + 'px';
        tip.classList.remove('hidden');
    } else tip.classList.add('hidden');
});
window.addEventListener('mouseup', e => {
    if (!drag) return;
    const d = drag; drag = null;
    if (d.vtx !== undefined) { renderSide(); return; }
    if (d.moved || !map.contains(e.target)) return;
    if (draft && draft.pickFlag) {
        const [px, py] = evImg(e); draft.flag = toGame(px, py); draft.pickFlag = false; renderMap(); renderSide(); return;
    }
    if (draft) {
        if (draft.pts.length >= 80) return toast('Maksimal 80 titik', 'err');
        const [px, py] = evImg(e); draft.pts.push(toGame(px, py)); renderMap(); renderSide(); return;
    }
    const pg = e.target.closest('polygon.zone');
    selected = pg ? pg.dataset.id : null; renderMap(); renderSide();
});
map.addEventListener('contextmenu', e => {
    e.preventDefault();
    const v = e.target.closest('.vtx');
    if (v && draft) { draft.pts.splice(+v.dataset.i, 1); renderMap(); renderSide(); }
});
map.addEventListener('wheel', e => {
    e.preventDefault();
    const r = map.getBoundingClientRect();
    zoomAt(e.deltaY < 0 ? 1.15 : 1 / 1.15, e.clientX - r.left, e.clientY - r.top); renderMap();
}, { passive: false });
$('#zoom-in').onclick = () => { zoomAt(1.3, map.clientWidth / 2, map.clientHeight / 2); renderMap(); };
$('#zoom-out').onclick = () => { zoomAt(1 / 1.3, map.clientWidth / 2, map.clientHeight / 2); renderMap(); };
$('#zoom-me').onclick = () => { if (myPos) { centerOn(myPos, 2.5); renderMap(); } };

// ------------------------------------------------------------------ panel kanan (detail / editor)
function renderSide() {
    const side = $('#side');
    if (!D) return;
    if (draft) return renderEditor(side);

    const z = selected && zoneOf(selected);
    if (!z) {
        const mine = D.me ? D.zones.filter(x => x.mine).length : 0;
        side.innerHTML = `
        <div class="side-body scroll">
            <h3>Ringkasan</h3>
            <div class="kv"><span>Total wilayah</span><b>${D.zones.length}</b></div>
            ${D.me ? `<div class="kv"><span>Dikuasai ${esc(D.me.label)}</span><b>${mine}</b></div>` : ''}
            <div class="kv"><span>Wilayah bebas</span><b>${D.zones.filter(x => !x.owner).length}</b></div>
            <div class="kv"><span>Perang berjalan</span><b>${D.running}/${D.cfg.maxWars}</b></div>
            <small style="margin-top:6px">Klik wilayah di peta untuk detail. Scroll untuk zoom, drag untuk geser.</small>
        </div>
        ${D.admin ? `<div class="side-foot"><button class="btn primary" id="add-zone">＋ Tambah Wilayah (Admin)</button></div>` : ''}`;
        if (D.admin) $('#add-zone').onclick = () => {
            draft = { label: '', min: D.cfg.defaultMin, items: [['money', 25000]], pts: [], mode: 'points', flag: null };
            selected = null; renderMap(); renderSide();
        };
        return;
    }

    const st = zoneState(z);
    side.innerHTML = `
    <div class="side-body scroll">
        <div style="display:flex;justify-content:space-between;align-items:center;gap:8px"><h3>${esc(z.label)}</h3><button class="icon-btn" id="side-close" style="width:30px;height:30px">✕</button></div>
        <div><span class="status ${st.cls}">${esc(st.text)}</span></div>
        <div class="kv"><span>Dikuasai</span>${z.owner ? `<span class="gang">${gdot(z.color)}${esc(z.owner)}</span>` : '<span class="sub">— Belum ada</span>'}</div>
        <div class="kv"><span>Min. peserta online</span><b>${z.min} / gang</b></div>
        <div class="kv"><span>Mode perang</span><b>${z.mode === 'flag' ? '🚩 Rebut Bendera' : '🎯 Poin'}</b></div>
        ${z.mode === 'flag' ? `<div class="kv"><span>Bendera berdiri</span>${z.flag ? `<span class="gang">${gdot(z.fcolor)}${esc(z.flag)}</span>` : '<span class="sub">— Kosong</span>'}</div>` : ''}
        <div class="section-t" style="margin-top:6px">Reward jika menang</div>
        <ul class="rlist">${(z.reward || []).map(([n, q]) => `<li>${esc(n)}<span>${q}x</span></li>`).join('') || '<li class="sub">Tidak ada reward</li>'}</ul>
    </div>
    <div class="side-foot">
        ${actionButton(z)}
        ${D.admin ? `<div class="row2"><button class="btn" id="z-edit">✏️ Edit</button><button class="btn danger" id="z-del">🗑 Hapus</button></div>` : ''}
    </div>`;
    $('#side-close').onclick = () => { selected = null; renderMap(); renderSide(); };
    bindActs(side);
    if (D.admin) {
        $('#z-edit').onclick = () => {
            if (z.phase) return toast('Wilayah sedang diperebutkan, tunggu sampai selesai', 'err');
            draft = { id: z.id, label: z.label, min: z.min, items: (z.reward || []).map(r => [...r]), pts: (POINTS[z.id] || []).map(p => [...p]),
                mode: z.mode === 'flag' ? 'flag' : 'points', flag: z.fpt ? [...z.fpt] : null };
            renderMap(); renderSide();
        };
        $('#z-del').onclick = async () => {
            if ($('#z-del').dataset.sure !== '1') { $('#z-del').dataset.sure = '1'; $('#z-del').textContent = 'Yakin hapus?'; return; }
            const res = await call('deleteZone', z.id);
            if (!res.ok) return toast(res.err, 'err');
            toast('Wilayah dihapus', 'ok'); selected = null; refresh(true);
        };
    }
}

function renderEditor(side) {
    side.innerHTML = `
    <div class="side-body scroll">
        <h3>${draft.id ? 'Edit Wilayah' : 'Tambah Wilayah'}</h3>
        <div class="field"><label>Nama wilayah</label><input id="d-name" maxlength="32" value="${esc(draft.label)}" placeholder="mis. Grove Street"></div>
        <div class="field"><label>Minimal peserta online (tiap gang)</label><input id="d-min" type="number" min="1" max="100" value="${draft.min}"></div>
        <div class="section-t">Mode perang</div>
        <div class="mode-pick">
            <button data-mode="points" class="${draft.mode !== 'flag' ? 'on' : ''}">🎯 Poin<small>kill + hadir di wilayah</small></button>
            <button data-mode="flag" class="${draft.mode === 'flag' ? 'on' : ''}">🚩 Bendera<small>cabut lalu tancap</small></button>
        </div>
        ${draft.mode === 'flag' ? `
        <div class="section-t">Titik bendera</div>
        <div class="flagpt"><b>🚩 Tiang</b><span>${draft.flag ? `x ${Math.round(draft.flag[0])}, y ${Math.round(draft.flag[1])}${draft.flag[2] != null ? `, z ${Math.round(draft.flag[2])}` : ''}` : 'belum ditentukan'}</span></div>
        <div class="row2"><button class="btn ${draft.pickFlag ? 'on' : ''}" id="d-flagmap">🖱️ Klik di peta</button><button class="btn" id="d-flagme">📍 Posisi saya [F]</button></div>
        <div class="note">🚩 Posisi saya: menu ditutup, berdiri di tempat tiang lalu tekan <b>F</b> (tinggi ikut tersimpan, cocok untuk atap). Titik wajib di dalam wilayah. Tekan <b>G</b> untuk kembali.</div>` : ''}
        <div class="section-t">Reward (nama item + jumlah)</div>
        <div class="items">${draft.items.map((it, i) => `
            <div class="item-row"><input data-k="n" data-i="${i}" value="${esc(it[0])}" placeholder="nama item, mis. money"><input data-k="q" data-i="${i}" type="number" min="1" value="${it[1]}"><button data-rm="${i}">✕</button></div>`).join('')}
        </div>
        ${draft.items.length < D.cfg.maxItems ? '<button class="ghost" id="d-add">+ Tambah item</button>' : ''}
        <div class="section-t">Titik (${draft.pts.length}) — min. 3</div>
        <div class="pts">${draft.pts.map((p, i) => `<span>${i + 1}: ${Math.round(p[0])}, ${Math.round(p[1])}</span>`).join('') || '<small>Klik di peta untuk menambah titik</small>'}</div>
        <div class="row2"><button class="btn" id="d-undo">↶ Undo</button><button class="btn" id="d-me">📍 Posisi saya [E]</button></div>
        <div class="note">📍 Posisi saya: menu ditutup, kamu jalan ke sudut wilayah lalu tekan <b>E</b> untuk menambah titik dari posisi asli. Garis wilayah tampil di dunia game. Tekan <b>G</b> untuk kembali ke editor.</div>
    </div>
    <div class="side-foot">
        <button class="btn primary" id="d-save" ${draft.pts.length >= 3 ? '' : 'disabled'}>Simpan Wilayah</button>
        <button class="btn" id="d-cancel">Batal</button>
    </div>`;
    $('#d-name').oninput = e => draft.label = e.target.value;
    $('#d-min').oninput = e => draft.min = +e.target.value;
    side.querySelectorAll('.item-row input').forEach(inp => inp.oninput = e => {
        const i = +e.target.dataset.i;
        if (e.target.dataset.k === 'n') draft.items[i][0] = e.target.value.trim(); else draft.items[i][1] = +e.target.value;
    });
    side.querySelectorAll('[data-rm]').forEach(b => b.onclick = () => { draft.items.splice(+b.dataset.rm, 1); renderSide(); });
    const add = $('#d-add'); if (add) add.onclick = () => { draft.items.push(['', 1]); renderSide(); };
    $('#d-undo').onclick = () => { draft.pts.pop(); renderMap(); renderSide(); };
    const toWorld = () => {
        isOpen = false;
        $('#panel').classList.add('hidden');
        post('draw', { points: draft.pts, flag: draft.mode === 'flag' ? draft.flag : null, flagMode: draft.mode === 'flag' });
    };
    $('#d-me').onclick = toWorld;
    side.querySelectorAll('[data-mode]').forEach(b => b.onclick = () => { draft.mode = b.dataset.mode; draft.pickFlag = false; renderMap(); renderSide(); });
    const fm = $('#d-flagmap'); if (fm) fm.onclick = () => { draft.pickFlag = !draft.pickFlag; renderMap(); renderSide(); };
    const fme = $('#d-flagme'); if (fme) fme.onclick = toWorld;
    $('#d-cancel').onclick = () => { draft = null; renderMap(); renderSide(); };
    $('#d-save').onclick = async e => {
        const btn = e.currentTarget;
        const d = draft;
        if (!d || btn.disabled) return;
        if (!d.label.trim()) return toast('Nama wilayah wajib diisi', 'err');
        btn.disabled = true; btn.textContent = 'Menyimpan…';
        const reward = d.items.filter(i => i[0] && i[1] > 0);
        if (d.mode === 'flag' && !d.flag) { btn.disabled = false; btn.textContent = 'Simpan Wilayah'; return toast('Tentukan titik bendera dulu', 'err'); }
        const res = await call('saveZone', { id: d.id, label: d.label.trim(), min: d.min, reward, points: d.pts, mode: d.mode, flag: d.mode === 'flag' ? d.flag : null });
        if (!res.ok) { btn.disabled = false; btn.textContent = 'Simpan Wilayah'; return toast(res.err, 'err'); }
        toast(d.id ? 'Wilayah diperbarui' : 'Wilayah baru disimpan', 'ok');
        if (draft === d) draft = null;
        renderMap(); renderSide();
        refresh(true);
    };
}

// ------------------------------------------------------------------ WILAYAH
function renderZones() {
    if (!D) return;
    const list = D.zones.filter(z => {
        if (zoneFilter === 'free') return !z.owner;
        if (zoneFilter === 'mine') return z.mine;
        if (zoneFilter === 'open') return z.act && z.act.ok;
        return true;
    });
    $('#zone-list').innerHTML = list.map(z => {
        const st = zoneState(z);
        return `<div class="trow">
            <div><b>${z.mode === 'flag' ? '🚩 ' : ''}${esc(z.label)}</b><div class="sub">🎁 ${esc(fmtItems(z.reward))}</div></div>
            <div>${z.owner ? `<span class="gang">${gdot(z.color)}${esc(z.owner)}</span>` : '<span class="sub">— Belum ada</span>'}</div>
            <div><span class="status ${st.cls}" ${st.ends ? `data-ends="${st.ends}" data-pre="${st.pre}"` : ''}>${esc(st.text)}</span></div>
            <div><b>${z.min}</b> <span class="sub">/ gang</span></div>
            <div>${actionButton(z)}</div>
        </div>`;
    }).join('') || '<div class="empty">Tidak ada wilayah</div>';
    $('#zone-info').innerHTML = `Perang berjalan: <b>${D.running}/${D.cfg.maxWars}</b> · Hanya Boss / Wakil yang bisa Kuasai / Rebut`;
    bindActs($('#zone-list'));
}
$$('#zone-filter button').forEach(b => b.onclick = () => {
    zoneFilter = b.dataset.f; $$('#zone-filter button').forEach(x => x.classList.toggle('active', x === b)); renderZones();
});

// ------------------------------------------------------------------ POPUP ATURAN
function openRules(z, mode) {
    if (!z || !D) return;
    const isJoin = mode === 'join';
    const w = isJoin && D.wars.find(x => x.id === z.id);
    const title = isJoin ? `Join Perang — ${z.label}` : `${z.act.label} ${z.label}`;
    const c = D.cfg;
    const m = $('#modal');
    m.innerHTML = `<div class="modal">
        <div class="modal-head"><h2>⚔️ ${esc(title)}</h2><small>${z.owner ? 'Dikuasai ' + esc(z.owner) : 'Wilayah bebas'} · Reward: ${esc(fmtItems(z.reward))}</small></div>
        <div class="modal-body scroll">
            <div class="section-t">Syarat (dicek server saat setuju)</div>
            <ul class="rules">
                <li>Hanya <b>Boss / Wakil</b>.</li>
                <li>Minimal <b>${z.min} anggota online</b> di gangmu${!isJoin && z.owner ? ` dan di ${esc(z.owner)}` : ''}.</li>
                <li>Gangmu tidak sedang ikut perang lain (1 gang = 1 perang).</li>
                ${isJoin ? `<li>Masih masa persiapan${w ? ` (sisa ${mmss(endsAt(w.left) - Date.now())})` : ''}.</li>` : `<li>Maksimal ${c.maxWars} perang bersamaan di kota.</li>`}
            </ul>
            <div class="section-t">Aturan Perang${z.mode === 'flag' ? ' — 🚩 Rebut Bendera' : ''}</div>
            ${z.mode === 'flag' ? `<ul class="rules">
                <li><b>Persiapan ${c.prep} menit</b> — gang lain bisa Join.</li>
                <li><b>Perang ${c.war} menit</b>. Bendera musuh di tiang harus <b>dicabut</b> dulu (tahan E ${c.pull} detik), lalu gang peserta <b>menancapkan</b> benderanya (pegang item bendera, tahan E ${c.plant} detik).</li>
                <li>Ada musuh hidup dalam ${c.contest} m dari tiang = progres berhenti.</li>
                <li>Bendera yang <b>berdiri saat waktu habis</b> menguasai wilayah. Titik kosong = pemilik lama tetap menang.</li>
                <li>Bendera yang dicabut musuh kembali ke Boss gangnya. Item bendera hanya dari admin / mafia.</li>
                <li>Setelah setuju, perang <b>tetap berjalan</b> walau anggota logout / crash / berkurang.</li>
                <li>Selesai perang: wilayah <b>cooldown ${c.cooldown} jam</b>. Pemenang mendapat reward (diambil Boss / Wakil di tab Reward).</li>
            </ul>` : `<ul class="rules">
                <li><b>Persiapan ${c.prep} menit</b> — gang lain bisa Join. Poin belum dihitung.</li>
                <li><b>Perang ${c.war} menit</b> — kumpulkan poin di dalam wilayah.</li>
                <li>Gang dengan poin terbanyak menguasai wilayah. Seri = pemilik lama menang. Penyerang dengan 0 poin tidak bisa menang.</li>
                <li>Setelah setuju, perang <b>tetap berjalan</b> walau anggota logout / crash / berkurang.</li>
                <li>Selesai perang: wilayah <b>cooldown ${c.cooldown} jam</b>. Pemenang mendapat reward (diambil Boss / Wakil di tab Reward).</li>
            </ul>
            <div class="ptable">
                <span>Hadir hidup di wilayah</span><span>+${c.presence} / menit / anggota</span>
                <span>Bunuh anggota gang peserta lain</span><span>+${c.kill}</span>
                <span>Jual narkoba di pojokan</span><span>+${c.drug}</span>
                <span>Hotwire mobil</span><span>+${c.car}</span>
                <span>Graffiti di wilayah (dibersihkan musuh: −${c.graffiti})</span><span>+${c.graffiti}</span>
            </div>`}
            <label class="agree"><input type="checkbox" id="agree"> Saya mengerti dan setuju dengan aturan perang</label>
        </div>
        <div class="modal-foot"><button class="btn" id="m-cancel">Batal</button><button class="btn war" id="m-ok" disabled>Setuju & ${isJoin ? 'Join' : 'Mulai'}</button></div>
    </div>`;
    m.classList.remove('hidden');
    $('#agree').onchange = e => $('#m-ok').disabled = !e.target.checked;
    $('#m-cancel').onclick = () => m.classList.add('hidden');
    $('#m-ok').onclick = async () => {
        $('#m-ok').disabled = true;
        const res = await call(isJoin ? 'join' : 'start', z.id);
        m.classList.add('hidden');
        if (!res.ok) { toast(res.err, 'err'); return refresh(false); }
        toast(isJoin ? `Gangmu ikut perang ${z.label}` : `Persiapan dimulai: ${z.label}`, 'ok');
        refresh(false);
    };
}

// ------------------------------------------------------------------ PERANG
function renderWars() {
    if (!D) return;
    const wc = $('#war-count'); wc.textContent = D.wars.length; wc.classList.toggle('hidden', !D.wars.length);
    $('#war-list').innerHTML = D.wars.map(w => {
        const ends = endsAt(w.left);
        const joined = w.parts.some(p => p.mine);
        let body;
        if (w.phase === 'war' && w.mode === 'flag') {
            const holder = w.parts.find(p => p.flag);
            body = `<div class="scores">${w.parts.map(p => `
                <div class="score"><span class="gang">${gdot(p.color)}${esc(p.label)}${p.flag ? ' 🚩' : ''}</span><small>${p.flag ? 'benderanya berdiri' : ''}</small><b>${fmtSec(p.pts)}</b></div>`).join('')}</div>
                <small>${holder ? `Bendera ${esc(holder.label)} berdiri` : 'Titik bendera kosong — pemilik lama menang kalau waktu habis'} · waktu = lama bendera berdiri</small>`;
        } else if (w.phase === 'war') {
            const max = Math.max(1, ...w.parts.map(p => p.pts));
            body = `<div class="scores">${w.parts.map(p => `
                <div class="score"><span class="gang">${gdot(p.color)}${esc(p.label)}</span><div class="bar"><i style="width:${p.pts / max * 100}%;background:${color(p.color)}"></i></div><b>${p.pts}</b></div>`).join('')}</div>`;
        } else {
            let btn = '';
            if (joined) btn = '<span class="status st-done">✔ Gangmu ikut</span>';
            else if (w.join) btn = `<div style="text-align:right"><button class="btn war" data-join="${esc(w.id)}" ${w.join.ok ? '' : 'disabled'}>Join Perang</button>${w.join.ok ? '' : `<div class="reason">⚠ ${esc(w.join.reason)}</div>`}</div>`;
            body = `<div style="display:flex;justify-content:space-between;align-items:center;gap:10px"><small>Poin belum dihitung selama persiapan.</small>${btn}</div>`;
        }
        return `<div class="war-card ${w.phase === 'war' ? 'live' : ''}">
            <div class="war-head">
                <div><h3>${w.mode === 'flag' ? '🚩 ' : ''}${esc(w.label)}</h3><span class="status ${w.phase === 'war' ? 'st-war' : 'st-prep'}">${w.phase === 'war' ? '🔥 PERANG BERLANGSUNG' : '⏳ MASA PERSIAPAN'}</span></div>
                <div class="timer"><span data-ends="${ends}">${mmss(ends - Date.now())}</span><small>${w.phase === 'war' ? 'sisa perang' : 'menuju perang'}</small></div>
            </div>
            <div class="parts">${w.parts.map(p => `<span class="part">${gdot(p.color)}${esc(p.label)} <em>${p.role}</em> <small>👤 ${p.n}</small></span>`).join('')}</div>
            ${body}
        </div>`;
    }).join('') || '<div class="empty">Tidak ada perang berjalan</div>';
    $('#war-list').querySelectorAll('[data-join]').forEach(b => b.onclick = () => openRules(zoneOf(b.dataset.join), 'join'));
}

// ------------------------------------------------------------------ RIWAYAT
async function loadHistory() {
    const res = await call('history');
    historyRows = res.ok ? arr(res.data) : [];
    for (const h of historyRows) h.scores = arr(h.scores);
    renderHistory();
}
function renderHistory() {
    if (!historyRows) { $('#hist-list').innerHTML = '<div class="empty">Memuat…</div>'; return; }
    const mine = D && D.me && D.me.gang;
    const list = historyRows.filter(h => histFilter === 'all' || (mine && h.scores.some(s => s.g === mine)));
    $('#hist-list').innerHTML = list.map(h => {
        let res;
        if (!h.winner_label) res = `<span class="result fail">Gagal — ${h.prev_label ? 'tetap milik ' + esc(h.prev_label) : 'tetap bebas'}</span>`;
        else if (h.winner_label === h.prev_label) res = `<span class="result hold">${esc(h.winner_label)} bertahan</span>`;
        else res = `<span class="result win">${esc(h.winner_label)} ${h.prev_label ? 'merebut dari ' + esc(h.prev_label) : 'menguasai'}</span>`;
        return `<div class="hrow"><span class="when">${fmtDate(h.ended_at)}</span><b>${esc(h.zone)}</b>
            <div class="hscores">${h.scores.map(s => `<span>${gdot(s.color)}${esc(s.label)} <b>${s.sec ? '🚩 ' + fmtSec(s.pts) : s.pts}</b></span>`).join('')}</div>${res}</div>`;
    }).join('') || '<div class="empty">Belum ada riwayat</div>';
    $('#hist-info').textContent = `${D ? D.cfg.history : 20} perang terakhir · sisanya dihapus otomatis`;
}
$$('#hist-filter button').forEach(b => b.onclick = () => {
    histFilter = b.dataset.f; $$('#hist-filter button').forEach(x => x.classList.toggle('active', x === b)); renderHistory();
});

// ------------------------------------------------------------------ LEADERBOARD
function renderBoard() {
    if (!D) return;
    const rows = D.board;
    const pod = (r, i) => r ? `<div class="pod ${i === 0 ? 'p1' : ''}"><div class="medal">${['🥇', '🥈', '🥉'][i]}</div>
        <div class="gname">${gdot(r.color)}${esc(r.label)}</div><div class="big">${r.count}</div><small>wilayah</small></div>` : '<div></div>';
    $('#v-board').innerHTML = rows.length ? `
        <div class="podium">${pod(rows[1], 1)}${pod(rows[0], 0)}${pod(rows[2], 2)}</div>
        <div class="list">${rows.map(r => `<div class="lrow ${r.mine ? 'mine' : ''}"><span class="rank">#${r.rank}</span>
            <span class="gang">${gdot(r.color)}${esc(r.label)}${r.mine ? ' <small>(gangmu)</small>' : ''}</span>
            <b>${r.count} / ${D.zones.length}</b><span class="sub">${esc(r.zones)}</span></div>`).join('')}</div>`
        : '<div class="empty">Belum ada gang yang menguasai wilayah</div>';
}

// ------------------------------------------------------------------ REWARD
async function loadRewards() {
    const res = await call('rewards');
    rewardRows = res.ok ? arr(res.data) : [];
    for (const r of rewardRows) r.items = arr(r.items);
    renderReward();
}
function renderReward() {
    const rc = $('#reward-count'); const n = D && D.me ? D.me.rewards : 0;
    rc.textContent = n; rc.classList.toggle('hidden', !n);
    $('#tab-reward').classList.toggle('hidden', !(D && D.me));
    if (!rewardRows) { $('#reward-list').innerHTML = '<div class="empty">Memuat…</div>'; return; }
    const canAct = D && D.me && D.me.canAct;
    $('#reward-list').innerHTML = rewardRows.map(r => `<div class="rcard ${r.claimed_at ? 'taken' : ''}">
        <div style="display:flex;justify-content:space-between;align-items:center;gap:8px"><b style="font-size:15px">🏴 ${esc(r.zone)}</b><small>${fmtDate(r.won_at)}</small></div>
        <ul class="rlist">${(r.items || []).map(([n, q]) => `<li>${esc(n)}<span>${q}x</span></li>`).join('')}</ul>
        ${r.claimed_at ? `<small>Sudah diambil oleh ${esc(r.claimed_by)} · ${fmtDate(r.claimed_at)}</small>`
            : canAct ? `<button class="btn claim" data-claim="${r.id}">Ambil Reward</button>`
            : '<div><button class="btn claim full" disabled>Ambil Reward</button><div class="reason">⚠ Hanya Boss / Wakil</div></div>'}
    </div>`).join('') || '<div class="empty">Belum ada reward</div>';
    $('#reward-list').querySelectorAll('[data-claim]').forEach(b => b.onclick = async () => {
        b.disabled = true;
        const res = await call('claim', +b.dataset.claim);
        if (!res.ok) { toast(res.err, 'err'); b.disabled = false; return; }
        toast('Reward masuk ke inventory', 'ok');
        await refresh(false); loadRewards();
    });
}

// ------------------------------------------------------------------ BENDERA (admin)
async function loadFlags() {
    const res = await call('flags');
    if (!res.ok) { toast(res.err, 'err'); flagRows = { list: [] }; } else flagRows = res.data;
    flagRows.list = arr(flagRows.list);
    for (const f of flagRows.list) f.planted = arr(f.planted);
    renderFlags();
}
function renderFlags() {
    if (!flagRows) { $('#flag-list').innerHTML = '<div class="empty">Memuat…</div>'; return; }
    const F = flagRows;
    $('#flag-info').innerHTML = `Item <b>${esc(F.item)}</b> · hanya dari admin / mafia · dicabut musuh = kembali ke Boss · model kosong = <b>${esc(F.model)}</b> (tancap) / <b>${esc(F.hand)}</b> (tangan)`;
    $('#flag-list').innerHTML = F.list.map(f => `
        <div class="frow">
            <span class="gang">${gdot(f.color)}${esc(f.label)}</span>
            <div><b style="font-size:13px">${esc(f.boss)}</b><div class="${f.online ? 'on-dot' : 'off-dot'}">● ${f.online ? 'online' : 'offline — bendera masuk saat login'}</div></div>
            <div class="mrow"><input data-model="${esc(f.gang)}" value="${esc(f.model)}" maxlength="64" placeholder="${esc(F.model)} (default)"><button class="btn" data-msave="${esc(f.gang)}">Simpan</button></div>
            <div><span class="pill">🎁 ${f.issued} diberikan</span>${f.planted.length ? `<span class="pill up" title="${esc(f.planted.join(', '))}">🚩 ${f.planted.length} tertancap</span>` : ''}${f.pending ? `<span class="pill wait">⏳ ${f.pending} menunggu Boss</span>` : ''}</div>
            <button class="btn primary" data-give="${esc(f.gang)}">＋ Beri ke Boss</button>
        </div>`).join('') || '<div class="empty">Belum ada gang bertag gang</div>';
    $('#flag-list').querySelectorAll('[data-msave]').forEach(b => b.onclick = async () => {
        const inp = $('#flag-list').querySelector(`[data-model="${CSS.escape(b.dataset.msave)}"]`);
        b.disabled = true;
        const res = await call('flagModel', { gang: b.dataset.msave, model: inp ? inp.value : '' });
        b.disabled = false;
        if (!res.ok) return toast(res.err, 'err');
        toast('Model bendera disimpan', 'ok'); loadFlags();
    });
    $('#flag-list').querySelectorAll('[data-give]').forEach(b => b.onclick = async () => {
        b.disabled = true;
        const res = await call('flagGive', b.dataset.give);
        b.disabled = false;
        if (!res.ok) return toast(res.err, 'err');
        toast(res.data ? 'Bendera masuk ke inventory Boss' : 'Boss offline / tas penuh — bendera masuk saat login', 'ok'); loadFlags();
    });
}

// ------------------------------------------------------------------ tabs / render
function switchTab(t) {
    tab = t;
    $$('#tabs button').forEach(x => x.classList.toggle('active', x.dataset.tab === t));
    $$('main > section').forEach(s => s.classList.add('hidden'));
    $('#v-' + t).classList.remove('hidden');
    if (t === 'history') loadHistory();
    if (t === 'reward') loadRewards();
    if (t === 'flags') loadFlags();
    renderAll();
}
$$('#tabs button').forEach(b => b.onclick = () => switchTab(b.dataset.tab));

function renderHeader() {
    const me = D && D.me;
    $('#mygang').innerHTML = me
        ? `${gdot(me.color)}${esc(me.label)} · ${me.canAct ? 'Boss / Wakil' : 'Anggota'} · <span style="color:var(--green)">${me.online} online</span>`
        : (D && D.admin ? '🛡️ Admin' : '');
}

function renderAll() {
    if (!D || !isOpen) return;
    renderHeader();
    // editor tidak di-render ulang oleh polling supaya ketikan / fokus input tidak hilang
    if (tab === 'map') { applyView(); renderMap(); if (!draft) renderSide(); }
    if (tab === 'zones') renderZones();
    $('#tab-flags').classList.toggle('hidden', !D.admin);
    renderWars(); // juga memperbarui badge jumlah perang
    if (tab === 'history') renderHistory();
    if (tab === 'board') renderBoard();
    renderReward();
}

// hitung mundur di menu: hanya mengganti teks elemen yang punya data-ends
setInterval(() => {
    if (!isOpen) return;
    $$('[data-ends]').forEach(el => { el.textContent = (el.dataset.pre || '') + mmss(+el.dataset.ends - Date.now()); });
}, 1000);
// cooldown jam:menit cukup diperbarui 1x per menit
setInterval(() => { if (isOpen && (tab === 'zones' || tab === 'map')) renderAll(); }, MIN);
window.addEventListener('resize', () => isOpen && applyView());

// ================================================================== HUD
const hud = { data: null, ends: 0, total: 1, hidden: false, paused: false, key: 'F7', doneTimer: null, last: {} };

function hudShow(on) { $('#hud').classList.toggle('hidden', !on); }

function renderCountdown() {
    const d = hud.data; if (!d) return;
    const cd = $('#cd');
    const left = hud.ends - Date.now();
    cd.className = 'cd glass in ' + d.phase + (d.phase === 'war' && left <= 60000 ? ' final' : '');
    const flag = d.mode === 'flag';
    $('#cd-icon').textContent = d.phase === 'war' ? '⚔️' : '⏳';
    $('#cd-title').textContent = (d.phase === 'war' ? 'Perang · ' : 'Persiapan · ') + d.zone + (flag ? ' 🚩' : '');
    let desc;
    if (!flag) desc = d.phase === 'war' ? (d.inside ? 'Kamu di wilayah · kumpulkan poin' : 'Masuk ke wilayah untuk dapat poin') : 'Poin belum dihitung';
    else if (d.phase !== 'war') desc = 'Rebut Bendera · siapkan item bendera gangmu';
    else if (d.flag && d.flag.g === d.mine) desc = 'Benderamu berdiri · pertahankan sampai waktu habis';
    else if (d.flag) desc = `Cabut bendera ${d.flag.label}, lalu tancapkan milikmu`;
    else desc = 'Titik kosong · tancapkan benderamu!';
    $('#cd-desc').textContent = desc;
    $('#cd-timer').textContent = mmss(left);
    $('#cd-fill').style.transform = `scaleX(${Math.max(0, Math.min(1, left / (hud.total * 1000)))})`;
}

function renderBoardHud(deltas) {
    const d = hud.data; if (!d) return;
    const max = Math.max(1, ...d.parts.map(p => p.pts));
    $('#sb-zone').textContent = d.zone;
    const ph = $('#sb-phase'); ph.className = 'sb-phase ' + d.phase; ph.textContent = d.phase === 'war' ? 'PERANG' : 'PERSIAPAN';
    const flag = d.mode === 'flag';
    $('.sb-title').textContent = flag ? 'Rebut Bendera' : 'Gang Wars';
    $('#sb-flag').classList.toggle('hidden', !flag);
    if (flag) renderFlagBox(d);
    if (flag) {
        $('#sb-rows').innerHTML = d.parts.map((p, i) => `
        <div class="sb-row ${p.g === d.mine ? 'mine' : ''}">
            <span class="sb-pos">${i + 1}</span>
            <div class="sb-g"><b>${gdot(p.color)}${esc(p.label)}${d.flag && d.flag.g === p.g ? '<span class="flagmark">🚩</span>' : ''}</b><small>${p.role} · 👤 ${p.n} di wilayah</small></div>
            <span class="sb-pts sec">${d.phase === 'prep' ? '—' : fmtSec(p.pts)}</span>
        </div>`).join('');
    } else $('#sb-rows').innerHTML = d.parts.map((p, i) => `
        <div class="sb-row ${p.g === d.mine ? 'mine' : ''}">
            <i class="sb-fill" style="width:${d.phase === 'prep' ? 0 : p.pts / max * 100}%;background:${color(p.color)}"></i>
            <span class="sb-pos">${i + 1}</span>
            <div class="sb-g"><b>${gdot(p.color)}${esc(p.label)}</b><small>${p.role} · 👤 ${p.n} di wilayah</small></div>
            <span class="sb-pts">${d.phase === 'prep' ? '—' : p.pts}</span>
            ${deltas && deltas[p.g] > 0 ? `<span class="sb-delta">+${deltas[p.g]}</span>` : ''}
        </div>`).join('');
    const me = $('#sb-me');
    me.className = d.inside ? 'in-zone' : 'out-zone';
    me.textContent = d.inside ? '● Di dalam wilayah' : '● Di luar wilayah';
    $('#sb-key').textContent = hud.key;
    const top = d.parts[0];
    const myRank = d.parts.findIndex(p => p.g === d.mine) + 1;
    const miniTxt = d.phase === 'prep' ? 'persiapan'
        : flag ? (d.flag ? `🚩 ${esc(d.flag.label)}` : '🏳️ kosong')
        : `${esc(top ? top.label : '-')} ${top ? top.pts : 0} · kamu #${myRank}`;
    $('#sb-mini').innerHTML = `⚔️ ${esc(d.zone)} · ${miniTxt} <span class="key">${esc(hud.key)}</span>`;
    $('#sb').classList.toggle('hidden', hud.hidden);
    $('#sb-mini').classList.toggle('hidden', !hud.hidden);
    requestAnimationFrame(() => $('#sb').classList.add('in'));
}

// kotak status bendera di scoreboard; "berdiri" dihitung dari waktu terima data
function renderFlagBox(d) {
    const box = $('#sb-flag');
    const a = d.action;
    const act = a ? `<div class="act warn">⚠ ${esc(a.label)} sedang ${a.kind === 'pull' ? 'mencabut' : 'menancapkan'}${a.contested ? ' · diperebutkan' : ''}</div>` : '';
    if (d.flag) {
        const since = d.flag.since + (Date.now() - hud.got) / 1000;
        box.className = 'sb-flag';
        box.innerHTML = `<span class="fi" style="background:${color(d.flag.color)}55">🚩</span>
            <div class="ft"><small>Bendera berdiri</small><b>${gdot(d.flag.color)}${esc(d.flag.label)}</b>${act || `<div class="act">berdiri ${fmtSec(since)}${d.flag.g === d.mine ? ' · pertahankan!' : ''}</div>`}</div>`;
    } else {
        box.className = 'sb-flag empty';
        const def = d.parts.find(p => p.role === 'pemilik');
        box.innerHTML = `<span class="fi" style="background:rgba(255,255,255,.12)">🏳️</span>
            <div class="ft"><small>Titik bendera</small><b>Kosong</b>${act || `<div class="act">${def ? `Waktu habis = ${esc(def.label)} (pemilik) menang` : 'Waktu habis = tetap bebas'}</div>`}</div>`;
    }
}

function onHud(data, hidden, key) {
    if (key) hud.key = key;
    if (typeof hidden === 'boolean') hud.hidden = hidden;
    if (!data) { hud.data = null; hudShow(false); return; }
    data.parts = arr(data.parts);
    clearTimeout(hud.doneTimer);
    const deltas = {};
    if (hud.data && hud.data.id === data.id && hud.data.phase === 'war') {
        for (const p of data.parts) { const old = hud.last[p.g]; if (old !== undefined && p.pts > old) deltas[p.g] = p.pts - old; }
    }
    hud.last = {}; for (const p of data.parts) hud.last[p.g] = p.pts;
    hud.data = data; hud.ends = Date.now() + data.left * 1000; hud.total = data.total || 600; hud.got = Date.now();
    hudShow(true);
    renderCountdown(); renderBoardHud(deltas);
}

function onHudDone(text) {
    if (!hud.data) hudShow(true);
    hud.data = null;
    const cd = $('#cd');
    cd.className = 'cd glass in done';
    $('#cd-icon').textContent = '🏆';
    $('#cd-title').textContent = 'Perang Selesai';
    $('#cd-desc').textContent = text;
    const ph = $('#sb-phase'); ph.className = 'sb-phase done'; ph.textContent = 'SELESAI';
    clearTimeout(hud.doneTimer);
    hud.doneTimer = setTimeout(() => { if (!hud.data) hudShow(false); }, 6000);
}

setInterval(() => {
    if (!hud.data) return;
    renderCountdown();
    if (hud.data.mode === 'flag' && hud.data.flag && !hud.data.action) renderFlagBox(hud.data);
}, 1000);

// ================================================================== REBUT BENDERA (prompt, progres, pegang)
function onFlagPrompt(p) {
    const el = $('#fprompt');
    if (!p) return el.classList.add('hidden');
    el.className = 'fprompt glass' + (p.dim ? ' dim' : '');
    el.innerHTML = `${p.key ? `<span class="key">${esc(p.key)}</span>` : ''}${esc(p.text)}${p.sub ? ` <small>· ${esc(p.sub)}</small>` : ''}`;
}
function onFlagHold(d) {
    const el = $('#fhold');
    if (!d) return el.classList.add('hidden');
    $('#fprompt').classList.add('hidden');
    el.className = 'fhold glass' + (d.kind === 'pull' ? ' pull' : '') + (d.contested ? ' contested' : '');
    $('#fh-ic').textContent = d.kind === 'pull' ? '✊' : '🚩';
    $('#fh-t').textContent = d.title || '';
    $('#fh-s').textContent = d.contested ? '⚠ Diperebutkan — ada musuh hidup di dekat tiang, progres berhenti' : 'Tahan E · jangan bergerak';
    $('#fh-n').textContent = `${d.left ?? ''} dtk`;
    $('#fh-bar').style.width = `${Math.max(0, Math.min(1, d.p || 0)) * 100}%`;
}
function onFlagCarry(d) {
    const el = $('#fcarry');
    if (!d) return el.classList.add('hidden');
    el.classList.remove('hidden');
    el.innerHTML = `<span class="fi" style="background:${color(d.color)}73">🚩</span>Memegang bendera <b>${esc(d.label)}</b> <small>· tidak bisa pakai senjata / kendaraan</small> <span class="key">X</span><small>simpan</small>`;
}

// ================================================================== pesan dari client
window.addEventListener('message', e => {
    const m = e.data || {};
    switch (m.action) {
        case 'open': open(m.data, m.pos); break;
        case 'hud': onHud(m.data, m.hidden, m.key); break;
        case 'hudDone': onHudDone(m.text); break;
        case 'hudToggle':
            hud.hidden = !!m.hidden;
            if (hud.data) renderBoardHud();
            break;
        case 'hudPause': $('#hud').classList.toggle('paused', !!m.paused); break;
        case 'flagPrompt': onFlagPrompt(m.data); break;
        case 'flagHold': onFlagHold(m.data); break;
        case 'flagCarry': onFlagCarry(m.data); break;
        case 'drawFlag':
            if (draft) draft.flag = m.point;
            break;
        case 'drawHint':
            $('#world-hint').classList.toggle('hidden', !m.show);
            if (m.show) $('#world-flag').classList.toggle('hidden', !m.flagMode);
            $('#world-count').textContent = draft ? ` ${draft.pts.length} titik` : '';
            break;
        case 'drawPoint':
            if (draft) { draft.pts.push(m.point); $('#world-count').textContent = ` ${draft.pts.length} titik`; }
            break;
        case 'drawReturn':
            if (m.pos) myPos = m.pos;
            isOpen = true;
            $('#panel').classList.remove('hidden');
            if (tab !== 'map') switchTab('map'); else renderAll();
            renderSide();
            break;
    }
});
