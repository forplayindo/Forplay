const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'f_blips';
const $ = (s) => document.querySelector(s);

// Warna blip GTA yang sering dipakai (id asli GTA) untuk pilih cepat; id lain tetap bisa diketik manual.
const PALETTE = [
    [0, '#fefefe'], [1, '#e03232'], [2, '#71cb71'], [3, '#5db6e5'], [5, '#eec64e'], [7, '#9c6eaf'], [8, '#fe7ac3'], [17, '#f0a050'],
    [25, '#3a8a3a'], [26, '#7ac7ff'], [27, '#ab3cc9'], [38, '#2c6db8'], [40, '#555555'], [46, '#ecca2f'], [47, '#ff8a1e'], [59, '#c43535'],
];
const colorHex = (id) => (PALETTE.find((p) => p[0] === id) || [0, '#93a0b8'])[1];

const state = {
    blips: [], categories: [], limits: {}, pending: 0, pos: null,
    tab: 'Semua', search: '', editing: null, busy: false, form: null,
};
let armed = null; // { id, action } untuk konfirmasi klik kedua
let msgTimer, previewTimer;

const post = (name, data) =>
    fetch(`https://${RES}/${name}`, { method: 'POST', body: JSON.stringify(data || {}) }).then((r) => r.json()).catch(() => null);

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const fmt = (c) => `${c.x.toFixed(1)}, ${c.y.toFixed(1)}, ${c.z.toFixed(1)}`;

function distanceTo(c) {
    if (!state.pos) return null;
    const dx = c.x - state.pos.x, dy = c.y - state.pos.y, dz = c.z - state.pos.z;
    return Math.sqrt(dx * dx + dy * dy + dz * dz);
}

function banner(text, error) {
    const el = $('#msg');
    el.textContent = text;
    el.classList.toggle('error', !!error);
    el.classList.remove('hidden');
    clearTimeout(msgTimer);
    msgTimer = setTimeout(() => el.classList.add('hidden'), 4000);
}

function applyResult(res) {
    if (!res) return banner('Tidak ada respon server.', true), false;
    if (res.pos) state.pos = res.pos;
    if (res.blips) state.blips = res.blips;
    if (res.pending != null) state.pending = res.pending;
    banner(res.msg || (res.ok ? 'Berhasil.' : 'Gagal.'), !res.ok);
    renderList();
    return res.ok;
}

// ---------------------------------------------------------------- list
function renderTabs() {
    $('#tabs').innerHTML = ['Semua', ...state.categories]
        .map((t) => `<button data-tab="${esc(t)}" class="${t === state.tab ? 'active' : ''}">${esc(t)}</button>`).join('');
}

function renderList() {
    const q = state.search.trim().toLowerCase();
    const items = state.blips
        .filter((b) => (state.tab === 'Semua' || b.category === state.tab) && (!q || b.label.toLowerCase().includes(q)))
        .sort((a, b) => (distanceTo(a.coords) ?? 0) - (distanceTo(b.coords) ?? 0));

    $('#sub').textContent = `${state.blips.length} blip · ${state.blips.filter((b) => b.active).length} aktif`;

    const p = $('#pending');
    p.classList.toggle('hidden', !state.pending);
    p.textContent = `${state.pending} perubahan tersimpan ke config. Berlaku setelah "ensure f_blips" — lakukan saat maintenance / server sepi pemain.`;

    const list = $('#list');
    if (!items.length) {
        list.innerHTML = '<div class="empty">Belum ada blip di sini.</div>';
        return;
    }

    list.innerHTML = items.map((b) => {
        const d = distanceTo(b.coords);
        const isArmed = (a) => armed && armed.id === b.id && armed.action === a;
        return `
        <div class="card ${b.active ? '' : 'off'}">
            <div class="head">
                <div class="bicon">#${b.sprite}<i style="background:${colorHex(b.color)}"></i></div>
                <div class="info"><b>${esc(b.label)}</b><small>Ikon ${b.sprite} · Warna ${b.color} · Ukuran ${Number(b.scale).toFixed(1)}</small></div>
                <span class="dist">${d == null ? '' : d < 1000 ? `${d.toFixed(0)} m` : `${(d / 1000).toFixed(1)} km`}</span>
            </div>
            <div class="chips">
                <span class="chip cat">${esc(b.category)}</span>
                ${b.active ? '' : '<span class="chip off">Nonaktif</span>'}
                ${b.dirty ? '<span class="chip new">Belum diterapkan</span>' : ''}
            </div>
            <div class="meta">${fmt(b.coords)}</div>
            <div class="actions">
                <button data-act="edit" data-id="${b.id}">Ubah</button>
                <button data-act="move" data-id="${b.id}" class="${isArmed('move') ? 'armed' : ''}">${isArmed('move') ? 'Yakin?' : 'Pindah ke sini'}</button>
                <button data-act="tp" data-id="${b.id}">Teleport</button>
                <button data-act="delete" data-id="${b.id}" class="del ${isArmed('delete') ? 'armed' : ''}">${isArmed('delete') ? 'Yakin?' : 'Hapus'}</button>
            </div>
        </div>`;
    }).join('');
}

$('#list').addEventListener('click', async (e) => {
    const btn = e.target.closest('button[data-act]');
    if (!btn || state.busy) return;
    const b = state.blips.find((x) => x.id === Number(btn.dataset.id));
    if (!b) return;
    const act = btn.dataset.act;

    if (act === 'edit') return openSheet(b);
    if (act === 'tp') return post('teleport', { coords: b.coords });

    if (!armed || armed.id !== b.id || armed.action !== act) {
        armed = { id: b.id, action: act };
        renderList();
        return;
    }
    armed = null;
    state.busy = true;
    applyResult(await post(act, { id: b.id }));
    state.busy = false;
});

$('#tabs').addEventListener('click', (e) => {
    const b = e.target.closest('button[data-tab]');
    if (!b) return;
    state.tab = b.dataset.tab;
    renderTabs();
    renderList();
});

$('#search').addEventListener('input', (e) => {
    state.search = e.target.value;
    renderList();
});

// ---------------------------------------------------------------- form
function readForm() {
    const f = state.form;
    f.label = $('#f-label').value;
    f.category = $('#f-cat').value;
    f.sprite = Number($('#f-sprite').value);
    f.color = Number($('#f-color').value);
    f.scale = Number($('#f-scale').value);
    f.active = $('#f-active').checked;
    return f;
}

function renderForm() {
    const f = state.form;
    $('#f-coords').textContent = fmt(f.coords);
    $('#scale-val').textContent = Number($('#f-scale').value).toFixed(1);
    const color = Number($('#f-color').value);
    $('#f-palette').innerHTML = PALETTE
        .map(([id, hex]) => `<button data-c="${id}" class="${id === color ? 'active' : ''}" style="background:${hex}" title="Warna ${id}"></button>`).join('');
}

// Blip uji di minimap; ditunda sedikit supaya tidak dikirim tiap ketukan tombol.
function schedulePreview() {
    clearTimeout(previewTimer);
    previewTimer = setTimeout(() => post('preview', readForm()), 200);
}

function onFormChange() {
    renderForm();
    schedulePreview();
}

function openSheet(b) {
    state.editing = b ? b.id : null;
    const pos = state.pos || { x: 0, y: 0, z: 0 };
    state.form = b
        ? { ...b, coords: { ...b.coords } }
        : { label: '', category: state.categories[0], sprite: 1, color: 0, scale: 0.7, active: true, coords: { ...pos } };
    const f = state.form;

    $('#sheet-title').textContent = b ? 'Ubah Blip' : 'Tambah Blip';
    $('#f-label').value = f.label;
    $('#f-cat').innerHTML = state.categories.map((c) => `<option ${c === f.category ? 'selected' : ''}>${esc(c)}</option>`).join('');
    $('#f-sprite').max = state.limits.sprite || 900;
    $('#f-color').max = state.limits.color || 85;
    $('#f-sprite').value = f.sprite;
    $('#f-color').value = f.color;
    $('#f-scale').min = state.limits.minScale || 0.4;
    $('#f-scale').max = state.limits.maxScale || 1.5;
    $('#f-scale').value = f.scale;
    $('#f-active').checked = f.active;

    $('#sheet-msg').classList.add('hidden');
    $('#sheet').classList.remove('hidden');
    onFormChange();
    $('#f-label').focus();
}

function closeSheet() {
    clearTimeout(previewTimer);
    if (!$('#sheet').classList.contains('hidden')) post('clearPreview');
    $('#sheet').classList.add('hidden');
    state.editing = null;
}

$('#add-btn').addEventListener('click', () => openSheet(null));
$('#sheet-close').addEventListener('click', closeSheet);

$('#use-pos').addEventListener('click', async () => {
    const pos = await post('pos');
    if (!pos) return;
    state.pos = pos;
    state.form.coords = { ...pos };
    onFormChange();
});

['#f-label', '#f-sprite', '#f-color', '#f-scale'].forEach((s) => $(s).addEventListener('input', onFormChange));
['#f-cat', '#f-active'].forEach((s) => $(s).addEventListener('change', onFormChange));

$('#f-palette').addEventListener('click', (e) => {
    const b = e.target.closest('button[data-c]');
    if (!b) return;
    $('#f-color').value = b.dataset.c;
    onFormChange();
});

$('#save-btn').addEventListener('click', async () => {
    if (state.busy) return;
    const data = { ...readForm(), id: state.editing };
    state.busy = true;
    $('#save-btn').disabled = true;
    const res = await post(state.editing ? 'update' : 'create', data);
    state.busy = false;
    $('#save-btn').disabled = false;

    if (res && res.ok) {
        closeSheet();
        applyResult(res);
    } else {
        const m = $('#sheet-msg');
        m.textContent = (res && res.msg) || 'Gagal menyimpan.';
        m.classList.remove('hidden');
    }
});

// ---------------------------------------------------------------- open/close
function close() {
    closeSheet();
    $('#panel').classList.add('hidden');
    armed = null;
    post('close');
}

document.querySelectorAll('[data-close]').forEach((b) => b.addEventListener('click', close));
document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape' || $('#panel').classList.contains('hidden')) return;
    if (!$('#sheet').classList.contains('hidden')) return closeSheet();
    close();
});

window.addEventListener('message', (e) => {
    const { action, data } = e.data || {};
    if (action === 'open') {
        state.blips = data.blips || [];
        state.categories = data.categories || [];
        state.limits = data.limits || {};
        state.pending = data.pending || 0;
        state.pos = data.pos;
        state.tab = 'Semua';
        state.search = '';
        $('#search').value = '';
        armed = null;
        $('#msg').classList.add('hidden');
        closeSheet();
        renderTabs();
        renderList();
        $('#panel').classList.remove('hidden');
    } else if (action === 'close') {
        $('#panel').classList.add('hidden');
        $('#sheet').classList.add('hidden');
        state.editing = null;
    }
});
