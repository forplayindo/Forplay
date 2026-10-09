const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'f_spawnpoints';
const $ = (s) => document.querySelector(s);

const state = {
    points: [], pos: null,
    tab: 'all', search: '', busy: false,
    sheet: null, // { mode: 'create' | 'rename' | 'give', point }
};
let armed = null; // { id, action } untuk konfirmasi klik kedua
let msgTimer;

const post = (name, data) =>
    fetch(`https://${RES}/${name}`, { method: 'POST', body: JSON.stringify(data || {}) }).then((r) => r.json()).catch(() => null);

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

function distanceTo(c) {
    if (!state.pos) return null;
    const dx = c.x - state.pos.x, dy = c.y - state.pos.y, dz = c.z - state.pos.z;
    return Math.sqrt(dx * dx + dy * dy + dz * dz);
}

const fmtPos = (c) => (c ? `${c.x.toFixed(1)}, ${c.y.toFixed(1)}, ${c.z.toFixed(1)}` : '-');

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
    if (res.points) state.points = res.points;
    banner(res.msg || (res.ok ? 'Berhasil.' : 'Gagal.'), !res.ok);
    renderList();
    return res.ok;
}

// ---------------------------------------------------------------- list
function renderList() {
    const q = state.search.trim().toLowerCase();
    const items = state.points.filter((p) => {
        if (state.tab === 'owned' && !p.owner) return false;
        if (state.tab === 'empty' && p.owner) return false;
        if (!q) return true;
        return [p.label, p.owner, p.ownerName, String(p.id)].some((v) => v && String(v).toLowerCase().includes(q));
    });

    const owned = state.points.filter((p) => p.owner).length;
    $('#sub').textContent = `${state.points.length} rumah · ${owned} ada pemilik`;
    const list = $('#list');
    if (!items.length) {
        list.innerHTML = '<div class="empty">Belum ada rumah di sini.</div>';
        return;
    }

    list.innerHTML = items.map((p) => {
        const d = distanceTo(p.coords);
        const isArmed = (a) => armed && armed.id === p.id && armed.action === a;
        return `
        <div class="card">
            <div class="head">
                <div><b>${esc(p.label)}</b><small>#${p.id}${p.createdBy ? ` · oleh ${esc(p.createdBy)}` : ''}</small></div>
                <span class="dist">${d == null ? '' : d < 1000 ? `${d.toFixed(0)} m` : `${(d / 1000).toFixed(1)} km`}</span>
            </div>
            ${p.owner
                ? `<div class="owner"><span>Pemilik</span><span><b>${esc(p.ownerName || '?')}</b> · ${esc(p.owner)}</span></div>`
                : '<div class="owner vacant"><span>Pemilik</span><b>Kosong</b></div>'}
            <div class="meta">Spawn: ${fmtPos(p.coords)} · hadap ${Math.round(p.coords.w || 0)}°</div>
            <div class="actions">
                <button data-act="give" data-id="${p.id}" class="give">Serahkan</button>
                <button data-act="revoke" data-id="${p.id}" class="${isArmed('revoke') ? 'armed' : ''}" ${p.owner ? '' : 'disabled'}>${isArmed('revoke') ? 'Yakin?' : 'Cabut'}</button>
                <button data-act="rename" data-id="${p.id}">Ubah Nama</button>
                <button data-act="move" data-id="${p.id}" class="${isArmed('move') ? 'armed' : ''}">${isArmed('move') ? 'Yakin?' : 'Pindah ke sini'}</button>
                <button data-act="tp" data-id="${p.id}">Teleport</button>
                <button data-act="delete" data-id="${p.id}" class="del ${isArmed('delete') ? 'armed' : ''}">${isArmed('delete') ? 'Yakin hapus?' : 'Hapus'}</button>
            </div>
        </div>`;
    }).join('');
}

$('#list').addEventListener('click', async (e) => {
    const btn = e.target.closest('button[data-act]');
    if (!btn || btn.disabled || state.busy) return;
    const p = state.points.find((x) => String(x.id) === btn.dataset.id);
    if (!p) return;
    const act = btn.dataset.act;

    if (act === 'give' || act === 'rename') return openSheet(act, p);
    if (act === 'tp') return post('teleport', { coords: p.coords });

    if (!armed || armed.id !== p.id || armed.action !== act) {
        armed = { id: p.id, action: act };
        renderList();
        return;
    }
    armed = null;
    state.busy = true;
    applyResult(await post(act, { id: p.id }));
    state.busy = false;
});

$('#tabs').addEventListener('click', (e) => {
    const b = e.target.closest('button[data-tab]');
    if (!b) return;
    state.tab = b.dataset.tab;
    document.querySelectorAll('#tabs button').forEach((x) => x.classList.toggle('active', x === b));
    renderList();
});

$('#search').addEventListener('input', (e) => {
    state.search = e.target.value;
    renderList();
});

// ---------------------------------------------------------------- sheet
function openSheet(mode, p) {
    state.sheet = { mode, point: p || null };
    const isGive = mode === 'give';

    $('#sheet-title').textContent = mode === 'create' ? 'Tambah Rumah' : isGive ? 'Serahkan Rumah' : 'Ubah Nama';
    $('#loc-note').textContent = mode === 'create'
        ? `Titik spawn = posisi & arah hadap kamu sekarang (${fmtPos(state.pos)}). Berdiri di dalam rumah, hadap ke arah yang diinginkan.`
        : p.label;
    $('#label-box').classList.toggle('hidden', isGive);
    $('#give-box').classList.toggle('hidden', !isGive);
    $('#f-label').value = mode === 'rename' ? p.label : '';
    $('#f-target').value = '';
    $('#give-current').textContent = isGive && p.owner
        ? `Pemilik sekarang: ${p.ownerName || '?'} (${p.owner}). Akan diganti.`
        : '';
    $('#save-btn').textContent = isGive ? 'Serahkan' : 'Simpan';

    $('#sheet-msg').classList.add('hidden');
    $('#sheet').classList.remove('hidden');
    (isGive ? $('#f-target') : $('#f-label')).focus();
}

function closeSheet() {
    $('#sheet').classList.add('hidden');
    state.sheet = null;
}

$('#add-btn').addEventListener('click', () => openSheet('create'));
$('#sheet-close').addEventListener('click', closeSheet);

async function save() {
    if (state.busy || !state.sheet) return;
    const { mode, point } = state.sheet;
    const data = mode === 'give'
        ? { id: point.id, target: $('#f-target').value }
        : { id: point && point.id, label: $('#f-label').value };

    state.busy = true;
    $('#save-btn').disabled = true;
    const res = await post(mode, data);
    state.busy = false;
    $('#save-btn').disabled = false;

    if (res && res.ok) {
        applyResult(res);
        closeSheet();
    } else {
        const m = $('#sheet-msg');
        m.textContent = (res && res.msg) || 'Gagal menyimpan.';
        m.classList.remove('hidden');
    }
}

$('#save-btn').addEventListener('click', save);
['#f-label', '#f-target'].forEach((s) => $(s).addEventListener('keydown', (e) => { if (e.key === 'Enter') save(); }));

// ---------------------------------------------------------------- open/close
function close() {
    $('#panel').classList.add('hidden');
    closeSheet();
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
        state.points = data.points || [];
        state.pos = data.pos;
        state.search = '';
        $('#search').value = '';
        armed = null;
        $('#msg').classList.add('hidden');
        closeSheet();
        renderList();
        $('#panel').classList.remove('hidden');
    } else if (action === 'close') {
        $('#panel').classList.add('hidden');
        closeSheet();
    }
});
