const $ = (id) => document.getElementById(id);
const panel = $('panel');
let D = null;            // menu payload from the server
let busy = false;
let draft = {};          // persen bagian yang sedang diketik ketua (tidak di-reset saat data baru datang)

const rupiah = (n) => 'Rp ' + Math.floor(n || 0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const icon = (id) => `<svg class="ic"><use href="#${id}"/></svg>`;
const row = (label, value) => `<div class="row"><span class="t">${esc(label)}</span><span class="d">${esc(value)}</span></div>`;

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

function renderCrew(crew, isLeader) {
    const members = crew ? crew.members : [{ id: D.me, name: 'Kamu', share: 100 }];
    const editShares = isLeader && members.length > 1;
    $('crew-count').textContent = `(${members.length}/${D.maxCrew})`;
    // don't rebuild the list while the leader is typing a percentage
    if ($('crew').contains(document.activeElement)) return;
    $('crew').innerHTML = members.map((m) => {
        const lead = crew ? m.id === crew.leader : true;
        const pct = draft[m.id] ?? m.share;
        const right = editShares
            ? `<span class="pct"><input type="number" min="0" max="100" step="1" data-share="${m.id}" value="${esc(pct)}">%</span>`
            : `<span class="d">${esc(m.share)}%</span>`;
        return `<div class="row"><span class="sq" style="--c:${lead ? '#f3b354' : '#5e5ce6'}">${icon(lead ? 'i-crown' : 'i-user')}</span>
            <span class="t">${esc(m.name)}${m.id === D.me ? ' <span class="chip">Kamu</span>' : ''}<small>${lead ? 'Ketua' : 'Anggota'}</small></span>
            ${right}</div>`;
    }).join('');
    $('save-shares').classList.toggle('hidden', !editShares);
    $('share-f').classList.toggle('hidden', members.length < 2);
}

function render() {
    const crew = D.crew;
    const isLeader = !crew || crew.leader === D.me;
    const started = crew && crew.phase === 'work';
    const editable = isLeader && !started;

    const b = D.bonusTable || {};
    $('info').innerHTML = row('1 pohon', `${D.perTrunk} potong kayu`)
        + row('1 potong kayu', `${D.perPiece} papan`)
        + row('Bak truk', `Solo ${D.capSolo} potong · Kru ${D.capCrew} batang besar`)
        + row('Harga di koperasi', `${rupiah(D.price)} / papan`)
        + row('Bonus kru', `2 org +${b[2] || 0}% · 3 org +${b[3] || 0}% · 4 org +${b[4] || 0}%`)
        + (crew && crew.cargo + crew.output > 0 ? row('Papan belum dibongkar', `${crew.cargo + crew.output} papan`) : '');

    renderCrew(crew, isLeader);

    $('near-wrap').classList.toggle('hidden', !editable);
    const full = crew && crew.members.length >= D.maxCrew;
    $('near').innerHTML = (D.nearby || []).map((p) => `<div class="row"><span class="sq">${icon('i-user')}</span>
        <span class="t">${esc(p.name)}<small>ID ${p.id}</small></span>
        ${p.invited ? '<span class="chip info">Diajak</span>' : `<button class="cap tint" data-invite="${p.id}" ${full ? 'disabled' : ''}>${icon('i-plus')}Ajak</button>`}</div>`).join('');

    let status = '';
    if (started) status = `Sedang bekerja · bak ${crew.bed}/${crew.cap} potong`;
    else if (crew && !isLeader) status = 'Menunggu ketua memulai kerja.';
    $('status').textContent = status;
    $('status').classList.toggle('hidden', !status);

    $('start').classList.toggle('hidden', !editable);
    $('start').disabled = busy;
    $('start').textContent = busy ? 'Memulai...' : crew && crew.members.length > 1 ? `Mulai Kerja (${crew.members.length} orang)` : 'Mulai Kerja';

    $('leave').classList.toggle('hidden', !crew);
    $('leave').textContent = !isLeader ? 'Keluar Kru' : started ? 'Batalkan Kerja' : 'Bubarkan';
    $('leave').style.flex = editable ? '' : '1';
}

function load(data) {
    D = data;
    // forget drafts of members who left
    const ids = new Set((D.crew ? D.crew.members : []).map((m) => m.id));
    Object.keys(draft).forEach((k) => { if (!ids.has(Number(k))) delete draft[k]; });
    render();
}

$('crew').addEventListener('input', (e) => {
    const input = e.target.closest('[data-share]');
    if (input) draft[input.dataset.share] = input.value;
});

$('save-shares').addEventListener('click', async () => {
    if (busy || !D.crew) return;
    const shares = {};
    D.crew.members.forEach((m) => { shares[m.id] = Number(draft[m.id] ?? m.share); });
    busy = true;
    const res = await post('shares', { shares });
    busy = false;
    if (res && res.ok && res.data) {
        draft = {};
        document.activeElement && document.activeElement.blur();
        showMsg('Bagian disimpan.', true);
        load(res.data);
    } else {
        showMsg((res && res.msg) || 'Gagal menyimpan bagian.');
    }
});

$('near').addEventListener('click', async (e) => {
    const btn = e.target.closest('[data-invite]');
    if (!btn || btn.disabled || busy) return;
    busy = true;
    btn.disabled = true;
    const res = await post('invite', { id: Number(btn.dataset.invite) });
    busy = false;
    if (res && res.ok && res.data) {
        showMsg('Ajakan terkirim.', true);
        load(res.data);
    } else {
        showMsg((res && res.msg) || 'Gagal mengajak pemain.');
        render();
    }
});

$('refresh').addEventListener('click', async () => {
    const data = await post('refresh');
    if (data && data.maxCrew) load(data);
});

$('start').addEventListener('click', async () => {
    if (busy || $('start').disabled) return;
    busy = true;
    render();
    const res = await post('start');
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
    draft = {};
    if (data && data.maxCrew) load(data);
});

const close = () => post('close');
$('close').addEventListener('click', close);

/* ---------------- Gudang Kayu ---------------- */
let G = null;
let gBusy = false;

function gMsg(text, ok) {
    $('g-msg').textContent = text || '';
    $('g-msg').classList.toggle('ok', !!ok);
    $('g-msg').classList.toggle('hidden', !text);
}

function renderGudang() {
    $('g-rows').innerHTML = row('Stok papan', `${G.stock} papan`)
        + row('Muat di tasmu', `${G.fits} papan`)
        + row('Nilai di koperasi', rupiah(G.stock * G.price));
    const max = Math.max(0, Math.min(G.stock, G.fits));
    const input = $('g-amount');
    input.max = max || 1;
    if (Number(input.value) > max) input.value = Math.max(1, max);
    $('g-take').disabled = gBusy || max < 1;
    $('g-take').textContent = gBusy ? 'Mengambil...' : G.stock < 1 ? 'Gudang kosong' : max < 1 ? 'Tas penuh' : 'Ambil Papan';
}

$('g-max').addEventListener('click', () => {
    if (!G) return;
    $('g-amount').value = Math.max(1, Math.min(G.stock, G.fits));
});

$('g-take').addEventListener('click', async () => {
    if (gBusy || !G || $('g-take').disabled) return;
    const amount = Math.floor(Number($('g-amount').value));
    if (!amount || amount < 1) return gMsg('Isi jumlah papan.');
    gBusy = true;
    renderGudang();
    const res = await post('takeGudang', { amount });
    gBusy = false;
    if (res && res.ok && res.data) {
        G = res.data;
        gMsg(res.msg, true);
    } else {
        gMsg((res && res.msg) || 'Gagal mengambil papan.');
    }
    renderGudang();
});

$('g-close').addEventListener('click', close);

/* ---------------- konfirmasi ---------------- */
function openConfirm(c) {
    $('c-title').textContent = c.title;
    $('c-rows').innerHTML = (c.rows || []).map((r) => row(r[0], r[1])).join('');
    $('c-note').textContent = c.note || '';
    $('c-ok').textContent = c.confirm || 'OK';
    $('confirm').classList.remove('hidden');
}

function answer(ok) {
    if ($('confirm').classList.contains('hidden')) return;
    $('confirm').classList.add('hidden');
    post('confirm', { ok });
}
$('c-ok').addEventListener('click', () => answer(true));
$('c-cancel').addEventListener('click', () => answer(false));

document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    if (!$('confirm').classList.contains('hidden')) answer(false);
    else close();
});

/* ---------------- HUD progres ---------------- */
const hudRow = (label, value, cls) => `<div class="hud-row"><span>${esc(label)}</span><b class="${cls || ''}">${esc(value)}</b></div>`;

function renderHud(h) {
    if (!h) return $('hud').classList.add('hidden');
    $('h-title').textContent = h.title;
    $('h-sub').textContent = h.sub || '';
    let rows = hudRow('Bak truk', `${h.bed}/${h.cap} potong`, h.bed >= h.cap ? 'ok' : '');
    rows += `<div class="bar"><i style="--v:${h.cap ? Math.round(h.bed / h.cap * 100) : 0}%"></i></div>`;
    rows += hudRow('Kayu belum dimuat', `${h.ground}/${h.groundLimit} potong`, h.ground >= h.groundLimit ? 'warn' : '');
    if (h.output > 0) rows += hudRow('Papan di sawmill', `${h.output} papan`, 'warn');
    if (h.cargo > 0) rows += hudRow('Papan di truk', `${h.cargo} papan`, 'ok');
    if (h.size > 1 && h.bonus) rows += hudRow('Bonus kru', `+${h.bonus}%`);
    $('h-rows').innerHTML = rows;
    $('h-share-l').textContent = h.size > 1 ? `Papanmu nanti (${h.share}%)` : 'Papanmu nanti';
    $('h-mine').textContent = `${h.mine} papan`;
    $('hud').classList.remove('hidden');
}

/* ---------------- suara ---------------- */
function playSound(name, volume) {
    const a = new Audio(`sfx/${name}.mp3`);
    a.volume = Math.max(0, Math.min(1, volume));
    a.play().catch(() => {});
}

window.addEventListener('message', ({ data }) => {
    if (data.action === 'hud') return renderHud(data.data);
    if (data.action === 'sound') return playSound(data.name, data.volume);
    if (data.action === 'confirm') return openConfirm(data.data);
    if (data.action === 'gudang') {
        G = data.data;
        gMsg('');
        $('g-amount').value = Math.max(1, Math.min(G.stock, G.fits));
        renderGudang();
        return $('gudang').classList.remove('hidden');
    }
    if (data.action === 'open') {
        showMsg('');
        draft = {};
        load(data.data);
        panel.classList.remove('hidden');
    } else if (data.action === 'update') {
        load(data.data);
    } else if (data.action === 'close') {
        panel.classList.add('hidden');
        $('gudang').classList.add('hidden');
    }
});
