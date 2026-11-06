const $ = (id) => document.getElementById(id);
const panel = $('panel');
let D = null;            // menu payload from the server
let diff = 'easy';
let busy = false;

const rupiah = (n) => 'Rp ' + Math.floor(n || 0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const icon = (id) => `<svg class="ic"><use href="#${id}"/></svg>`;
const PHASE = { lobby: 'Menunggu dimulai', depot: 'Menuju depot', load: 'Memuat paket', route: 'Mengantar paket', return: 'Kembali ke depot' };

function post(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data),
    }).then((r) => r.json()).catch(() => ({ ok: false, msg: 'Server tidak merespons.' }));
}

function showMsg(text, ok) {
    $('msg').textContent = text || '';
    $('msg').classList.toggle('ok', !!ok);
    $('msg').classList.toggle('hidden', !text);
}

function render() {
    const crew = D.crew;
    const isLeader = !crew || crew.leader === D.me;
    const started = crew && crew.phase !== 'lobby';
    const editable = isLeader && !started;
    const atDepot = crew && crew.atDepot && !started;

    $('sub').textContent = atDepot ? 'Depot GoPostal · lanjut kerja' : 'GoPostal';

    // route
    $('diffs').innerHTML = D.difficulties.map((d) => `<button data-diff="${esc(d.key)}" class="${d.key === diff ? 'active' : ''}" ${editable ? '' : 'disabled'}>${esc(d.label)}</button>`).join('');
    const d = D.difficulties.find((x) => x.key === (started ? crew.difficulty : diff)) || D.difficulties[0];
    const mult = 1 + (d.bonus || 0) / 100;
    $('d-desc').textContent = d.desc;
    $('d-stops').textContent = `${d.stops} titik`;
    $('d-pay').textContent = rupiah(D.worth.package * mult) + (d.bonus ? ` (+${d.bonus}%)` : '') + ' · besar 2x';
    $('d-km').textContent = rupiah(D.worth.km * mult);

    // crew
    const members = crew ? crew.members : [{ id: D.me, name: 'Kamu' }];
    $('crew-count').textContent = `(${members.length}/${D.maxCrew})`;
    $('crew').innerHTML = members.map((m) => {
        const lead = crew ? m.id === crew.leader : true;
        const extra = started ? `${m.delivered || 0} paket` : `ID ${m.id}`;
        const kick = editable && crew && !lead
            ? `<button class="b b-sm b-red-tint" data-kick="${m.id}">Keluarkan</button>`
            : `<span class="d">${esc(extra)}</span>`;
        return `<div class="row"><span class="sq" style="--c:${lead ? '#f3b354' : '#5e5ce6'}">${icon(lead ? 'i-crown' : 'i-user')}</span>
            <span class="t">${esc(m.name)}${m.id === D.me ? ' <span class="chip">Kamu</span>' : ''}<small>${lead ? 'Ketua' : 'Anggota'}</small></span>
            ${kick}</div>`;
    }).join('');

    // nearby players
    $('near-wrap').classList.toggle('hidden', !editable);
    const full = crew && crew.members.length >= D.maxCrew;
    $('near').innerHTML = (D.nearby || []).map((p) => `<div class="row"><span class="sq">${icon('i-user')}</span>
        <span class="t">${esc(p.name)}<small>ID ${p.id}</small></span>
        ${p.invited ? '<span class="chip info">Diajak</span>' : `<button class="cap tint" data-invite="${p.id}" ${full ? 'disabled' : ''}>${icon('i-plus')}Ajak</button>`}</div>`).join('');

    // status + buttons
    let status = '';
    if (started) status = `${PHASE[crew.phase] || ''}${crew.phase === 'route' ? ` · titik ${crew.stopNum}/${crew.totalStops}` : ''}`;
    else if (atDepot) status = isLeader ? 'Rute selesai! Pilih rute berikutnya, atau selesai kerja.' : 'Rute selesai. Menunggu ketua memilih rute berikutnya.';
    else if (crew && !isLeader) status = 'Menunggu ketua memulai kerja.';
    $('status').textContent = status;
    $('status').classList.toggle('hidden', !status);

    $('start').classList.toggle('hidden', !editable);
    $('start').disabled = busy;
    const label = atDepot ? 'Lanjut Rute' : 'Mulai Kerja';
    $('start').textContent = busy ? 'Memulai...' : crew && crew.members.length > 1 ? `${label} (${crew.members.length} orang)` : label;

    $('leave').classList.toggle('hidden', !crew);
    $('leave').textContent = !isLeader ? 'Keluar Kru' : started ? 'Batalkan Kerja' : atDepot ? 'Selesai Kerja' : 'Bubarkan';
    $('leave').style.flex = editable ? '' : '1';
}

function load(data) {
    D = data;
    if (D.crew && D.crew.difficulty) diff = D.crew.difficulty;
    render();
}

$('diffs').addEventListener('click', (e) => {
    const b = e.target.closest('[data-diff]');
    if (!b || b.disabled) return;
    diff = b.dataset.diff;
    render();
});

$('near').addEventListener('click', async (e) => {
    const b = e.target.closest('[data-invite]');
    if (!b || b.disabled || busy) return;
    busy = true;
    b.disabled = true;
    const res = await post('invite', { id: Number(b.dataset.invite) });
    busy = false;
    if (res && res.ok && res.data) {
        showMsg('Ajakan terkirim.', true);
        load(res.data);
    } else {
        showMsg((res && res.msg) || 'Gagal mengajak pemain.');
        render();
    }
});

$('crew').addEventListener('click', async (e) => {
    const b = e.target.closest('[data-kick]');
    if (!b || busy) return;
    busy = true;
    b.disabled = true;
    const data = await post('kick', { id: Number(b.dataset.kick) });
    busy = false;
    if (data && data.difficulties) {
        showMsg('Anggota dikeluarkan.', true);
        load(data);
    } else {
        render();
    }
});

$('refresh').addEventListener('click', async () => {
    const data = await post('refresh');
    if (data && data.difficulties) load(data);
});

$('start').addEventListener('click', async () => {
    if (busy || $('start').disabled) return;
    busy = true;
    render();
    const res = await post('start', { difficulty: diff });
    busy = false;
    if (!res || !res.ok) {
        showMsg((res && res.msg) || 'Gagal memulai kerja.');
        render();
    }
});

$('leave').addEventListener('click', async () => {
    if (busy) return;
    busy = true;
    const data = await post('leave');
    busy = false;
    showMsg('');
    if (data && data.difficulties) load(data);
    else post('close');
});

const close = () => post('close');
$('close').addEventListener('click', close);
document.addEventListener('keydown', (e) => { if (e.key === 'Escape') close(); });

/* ---------------- HUD progres ---------------- */
const hudRow = (label, value, ok) => `<div class="hud-row"><span>${esc(label)}</span><b class="${ok ? 'ok' : ''}">${esc(value)}</b></div>`;

function renderHud(h) {
    if (!h) return $('hud').classList.add('hidden');
    $('h-title').textContent = h.title;
    $('h-sub').textContent = h.sub || '';
    let rows = '';
    if (h.bar) {
        const full = h.bar.done >= h.bar.total;
        rows += hudRow(h.bar.label, `${h.bar.done}/${h.bar.total}`, full);
        rows += `<div class="bar"><i style="--v:${h.bar.total ? Math.round(h.bar.done / h.bar.total * 100) : 0}%"></i></div>`;
    }
    (h.rows || []).forEach(([label, value]) => { rows += hudRow(label, value); });
    (h.crew || []).forEach((m) => { rows += hudRow(m.name, `${m.delivered} paket`); });
    // team pay is split equally; solo players just see their pay
    if (h.size > 1) rows += hudRow('Kas kru', rupiah(h.pool));
    $('h-rows').innerHTML = rows;
    $('h-share-l').textContent = h.size > 1 ? `Bagianmu (÷${h.size})` : 'Gajimu';
    $('h-earned').textContent = rupiah(h.share);
    $('hud').classList.remove('hidden');
}

window.addEventListener('message', ({ data }) => {
    if (data.action === 'hud') return renderHud(data.data);
    if (data.action === 'open') {
        showMsg('');
        load(data.data);
        panel.classList.remove('hidden');
    } else if (data.action === 'update') {
        load(data.data);
    } else if (data.action === 'close') {
        panel.classList.add('hidden');
    }
});
