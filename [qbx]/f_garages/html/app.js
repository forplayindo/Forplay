const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'f_garages';
const $ = (s) => document.querySelector(s);

const VTYPE = { car: 'Mobil', air: 'Udara', sea: 'Laut' };

const state = {
    garages: [], groups: { job: [], gang: [] }, grades: [0, 1, 2, 3, 4], pos: null, defaultHeight: 6,
    tab: 'all', search: '', editing: null, busy: false,
    form: null, // { vtype, depot, gtype, grade, points, spawns, z }
};
let armed = null;
let msgTimer;

const post = (name, data) =>
    fetch(`https://${RES}/${name}`, { method: 'POST', body: JSON.stringify(data || {}) }).then((r) => r.json()).catch(() => null);

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

function findGroup(gtype, name) {
    return (state.groups[gtype] || []).find((g) => g.name === name);
}

function center(g) {
    let x = 0, y = 0;
    g.points.forEach((p) => { x += p.x; y += p.y; });
    return { x: x / g.points.length, y: y / g.points.length, z: g.z };
}

function distanceTo(g) {
    if (!state.pos || !g.points.length) return null;
    const c = center(g);
    return Math.hypot(c.x - state.pos.x, c.y - state.pos.y);
}

function banner(text, error) {
    const el = $('#msg');
    el.textContent = text;
    el.classList.toggle('error', !!error);
    el.classList.remove('hidden');
    clearTimeout(msgTimer);
    msgTimer = setTimeout(() => el.classList.add('hidden'), 5000);
}

function applyResult(res) {
    if (!res) return banner('Tidak ada respon server.', true), false;
    if (res.pos) state.pos = res.pos;
    if (res.garages) state.garages = res.garages;
    banner(res.msg || (res.ok ? 'Berhasil.' : 'Gagal.'), !res.ok);
    renderList();
    return res.ok;
}

// ---------------------------------------------------------------- daftar
function ownerChip(g) {
    if (g.gtype === 'public') return '<span class="chip public">Umum</span>';
    if (g.gtype === 'group') return `<span class="chip group">Grup: ${esc(g.group)}</span>`;
    const grp = findGroup(g.gtype, g.group);
    const grade = g.grade ? ` · grade ${g.grade}+` : '';
    return `<span class="chip ${g.gtype}">${g.gtype === 'job' ? 'Job' : 'Gang'}: ${esc(grp ? grp.label : g.group)}${grade}</span>`;
}

function renderList() {
    const q = state.search.trim().toLowerCase();
    const items = state.garages.filter((g) => {
        if (state.tab === 'editor' && !g.editable) return false;
        if (state.tab === 'builtin' && g.editable) return false;
        if (!q) return true;
        return [g.label, g.id, g.group].some((v) => v && String(v).toLowerCase().includes(q));
    });

    const own = state.garages.filter((g) => g.editable).length;
    $('#sub').textContent = `${state.garages.length} garasi · ${own} buatan editor`;
    const list = $('#list');
    if (!items.length) {
        list.innerHTML = '<div class="empty">Belum ada garasi di sini.</div>';
        return;
    }

    list.innerHTML = items.map((g) => {
        const d = distanceTo(g);
        const isArmed = armed && armed.id === g.id;
        return `
        <div class="card">
            <div class="head">
                <div><b>${esc(g.label)}</b><small>${esc(g.id)}${g.createdBy ? ` · oleh ${esc(g.createdBy)}` : ''}</small></div>
                <span class="dist">${d == null ? '' : d < 1000 ? `${d.toFixed(0)} m` : `${(d / 1000).toFixed(1)} km`}</span>
            </div>
            <div class="chips">
                <span class="chip info">${VTYPE[g.vtype] || g.vtype}</span>
                ${g.depot ? '<span class="chip warn">Tempat Sitaan</span>' : ''}
                ${ownerChip(g)}
                ${g.shared ? '<span class="chip info">Kendaraan bersama</span>' : ''}
                ${g.editable ? '' : '<span class="chip info">Bawaan (config / script lain)</span>'}
            </div>
            <div class="meta"><span>Area <b>${g.points.length} titik</b></span><span>Keluar <b>${g.spawns.length} titik</b></span><span>Tinggi <b>${g.height} m</b></span></div>
            <div class="actions">
                <button data-act="edit" data-id="${esc(g.id)}" ${g.editable ? '' : 'disabled title="Garasi bawaan diatur di config"'}>Ubah</button>
                <button data-act="preview" data-id="${esc(g.id)}">Lihat Area</button>
                <button data-act="tp" data-id="${esc(g.id)}">Teleport</button>
                <button data-act="delete" data-id="${esc(g.id)}" class="del ${isArmed ? 'armed' : ''}" ${g.editable ? '' : 'disabled'}>${isArmed ? 'Yakin?' : 'Hapus'}</button>
            </div>
        </div>`;
    }).join('');
}

$('#list').addEventListener('click', async (e) => {
    const btn = e.target.closest('button[data-act]');
    if (!btn || btn.disabled || state.busy) return;
    const g = state.garages.find((x) => x.id === btn.dataset.id);
    if (!g) return;
    const act = btn.dataset.act;

    if (act === 'edit') return openSheet(g);
    if (act === 'preview') { $('#panel').classList.add('hidden'); return post('preview', { garage: g }); }
    if (act === 'tp') return post('teleport', { garage: g });

    if (!armed || armed.id !== g.id) {
        armed = { id: g.id };
        renderList();
        return;
    }
    armed = null;
    state.busy = true;
    applyResult(await post('delete', { id: g.id }));
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

// ---------------------------------------------------------------- form
function setSeg(id, value) {
    document.querySelectorAll(`#${id} button`).forEach((b) => b.classList.toggle('active', b.dataset.v === String(value)));
}

function renderOwner(selected) {
    const f = state.form;
    const isPublic = f.gtype === 'public';
    const list = state.groups[f.gtype] || [];
    if (!isPublic) {
        $('#f-group').innerHTML = list.length
            ? list.map((g) => `<option value="${esc(g.name)}">${esc(g.label)} (${esc(g.name)})</option>`).join('')
            : '<option value="">Belum ada</option>';
        if (selected && list.some((g) => g.name === selected)) $('#f-group').value = selected;
    }
    $('#f-group').classList.toggle('hidden', isPublic);
    $('#grade-box').classList.toggle('hidden', isPublic);
    $('#shared-row').classList.toggle('hidden', isPublic);
    $('#f-grade').innerHTML = state.grades
        .map((g) => `<button data-v="${g}" class="${g === f.grade ? 'active' : ''}">${g === 0 ? 'Semua' : g}</button>`).join('');
}

function renderMarks() {
    const f = state.form;
    const a = $('#area-info'), s = $('#spawn-info');
    a.textContent = f.points.length >= 3 ? `${f.points.length} titik · tanah z ${Number(f.z).toFixed(1)}` : 'Belum ditandai';
    a.classList.toggle('ok', f.points.length >= 3);
    s.textContent = f.spawns.length ? `${f.spawns.length} titik` : 'Belum ditandai';
    s.classList.toggle('ok', f.spawns.length > 0);
    $('#mark-area').textContent = f.points.length ? 'Tandai Ulang' : 'Tandai Area';
    $('#mark-spawn').textContent = f.spawns.length ? 'Ubah Titik' : 'Tandai Titik Keluar';
    $('#depot-hint').textContent = f.depot
        ? 'Tempat sitaan: ambil kendaraan yang disita / tertinggal di luar.'
        : 'Garasi: parkir & ambil kendaraan sendiri.';
}

function openSheet(g) {
    state.editing = g ? g.id : null;
    state.form = {
        vtype: g ? g.vtype : 'car',
        depot: g ? g.depot : false,
        gtype: g ? g.gtype : 'public',
        grade: g ? g.grade : 0,
        points: g ? g.points.map((p) => ({ x: p.x, y: p.y, z: g.z })) : [],
        spawns: g ? g.spawns.map((s) => ({ ...s })) : [],
        z: g ? g.z : 0,
    };
    $('#sheet-title').textContent = g ? 'Ubah Garasi' : 'Garasi Baru';
    $('#f-label').value = g ? g.label : '';
    $('#f-height').value = g ? g.height : state.defaultHeight;
    $('#f-shared').checked = g ? !!g.shared : false;
    setSeg('f-vtype', state.form.vtype);
    setSeg('f-depot', state.form.depot ? 1 : 0);
    setSeg('f-gtype', state.form.gtype);
    renderOwner(g && g.group);
    renderMarks();
    $('#sheet-msg').classList.add('hidden');
    $('#sheet').classList.remove('hidden');
}

function closeSheet() {
    $('#sheet').classList.add('hidden');
    state.editing = null;
    state.form = null;
}

$('#add-btn').addEventListener('click', () => openSheet(null));
$('#sheet-close').addEventListener('click', closeSheet);

$('#f-vtype').addEventListener('click', (e) => {
    const b = e.target.closest('button'); if (!b) return;
    state.form.vtype = b.dataset.v; setSeg('f-vtype', b.dataset.v);
});
$('#f-depot').addEventListener('click', (e) => {
    const b = e.target.closest('button'); if (!b) return;
    state.form.depot = b.dataset.v === '1'; setSeg('f-depot', b.dataset.v); renderMarks();
});
$('#f-gtype').addEventListener('click', (e) => {
    const b = e.target.closest('button'); if (!b) return;
    state.form.gtype = b.dataset.v; state.form.grade = 0; setSeg('f-gtype', b.dataset.v); renderOwner();
});
$('#f-grade').addEventListener('click', (e) => {
    const b = e.target.closest('button'); if (!b) return;
    state.form.grade = Number(b.dataset.v); renderOwner($('#f-group').value);
});

function startMark(mode) {
    const f = state.form;
    $('#panel').classList.add('hidden');
    post('mark', { mode, draft: { points: f.points, spawns: f.spawns, z: f.z, height: Number($('#f-height').value) || state.defaultHeight } });
}
$('#mark-area').addEventListener('click', () => startMark('area'));
$('#mark-spawn').addEventListener('click', () => startMark('spawn'));

$('#save-btn').addEventListener('click', async () => {
    if (state.busy || !state.form) return;
    const f = state.form;
    const data = {
        id: state.editing,
        label: $('#f-label').value,
        vtype: f.vtype,
        depot: f.depot,
        gtype: f.gtype,
        group: $('#f-group').value,
        grade: f.grade,
        shared: f.gtype !== 'public' && $('#f-shared').checked,
        height: Number($('#f-height').value),
        points: f.points,
        spawns: f.spawns,
    };
    state.busy = true;
    $('#save-btn').disabled = true;
    const res = await post(state.editing ? 'update' : 'create', data);
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
});

// ---------------------------------------------------------------- buka / tutup
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
    const d = e.data || {};
    if (d.pos) state.pos = d.pos;
    if (d.action === 'open') {
        const data = d.data || {};
        state.garages = data.garages || [];
        state.groups = data.groups || { job: [], gang: [] };
        state.grades = data.grades || [0, 1, 2, 3, 4];
        state.defaultHeight = data.defaultHeight || 6;
        state.search = '';
        $('#search').value = '';
        armed = null;
        $('#msg').classList.add('hidden');
        closeSheet();
        renderList();
        $('#panel').classList.remove('hidden');
    } else if (d.action === 'marked') {
        // kembali dari mode tandai: form tetap terbuka dengan hasil baru
        if (state.form && d.result) {
            if (d.mode === 'area') { state.form.points = d.result.points; state.form.z = d.result.z; }
            else state.form.spawns = d.result.spawns;
            renderMarks();
        }
        renderList();
        $('#panel').classList.remove('hidden');
    } else if (d.action === 'show') {
        renderList();
        $('#panel').classList.remove('hidden');
    } else if (d.action === 'close') {
        $('#panel').classList.add('hidden');
        closeSheet();
    }
});
