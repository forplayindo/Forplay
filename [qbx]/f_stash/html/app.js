const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'f_stash';
const $ = (s) => document.querySelector(s);

const state = {
    stashes: [], groups: { job: [], gang: [] }, grades: [0, 1, 2, 3, 4], pos: null,
    tab: 'all', search: '', editing: null, busy: false,
    form: { gtype: 'job', personal: false, grade: 0 },
};
let armed = null; // { id, action } untuk konfirmasi klik kedua
let msgTimer;

const post = (name, data) =>
    fetch(`https://${RES}/${name}`, { method: 'POST', body: JSON.stringify(data || {}) }).then((r) => r.json()).catch(() => null);

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

function findGroup(gtype, name) {
    return (state.groups[gtype] || []).find((g) => g.name === name);
}

function gradeText(gtype, group, grade) {
    if (!grade) return 'Semua grade';
    const g = findGroup(gtype, group);
    const name = g && g.grades[String(grade)];
    return `Grade ${grade}+${name ? ` (${name})` : ''}`;
}

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
    if (res.stashes) state.stashes = res.stashes;
    banner(res.msg || (res.ok ? 'Berhasil.' : 'Gagal.'), !res.ok);
    renderList();
    return res.ok;
}

// ---------------------------------------------------------------- list
function renderList() {
    const q = state.search.trim().toLowerCase();
    const items = state.stashes.filter((s) => {
        if (state.tab !== 'all' && s.gtype !== state.tab) return false;
        if (!q) return true;
        const g = findGroup(s.gtype, s.group);
        return [s.label, s.group, g && g.label, s.id].some((v) => v && String(v).toLowerCase().includes(q));
    });

    $('#sub').textContent = `${state.stashes.length} stash terpasang`;
    const list = $('#list');
    if (!items.length) {
        list.innerHTML = '<div class="empty">Belum ada stash di sini.</div>';
        return;
    }

    list.innerHTML = items.map((s) => {
        const g = findGroup(s.gtype, s.group);
        const d = distanceTo(s.coords);
        const isArmed = (a) => armed && armed.id === s.id && armed.action === a;
        return `
        <div class="card">
            <div class="head">
                <div><b>${esc(s.label)}</b><small>${esc(s.id)}${s.createdBy ? ` · oleh ${esc(s.createdBy)}` : ''}</small></div>
                <span class="dist">${d == null ? '' : d < 1000 ? `${d.toFixed(0)} m` : `${(d / 1000).toFixed(1)} km`}</span>
            </div>
            <div class="chips">
                ${s.gtype === 'public'
                    ? '<span class="chip public">Umum: semua warga</span>'
                    : `<span class="chip ${s.gtype}">${s.gtype === 'job' ? 'Job' : 'Gang'}: ${esc(g ? g.label : s.group)}</span>
                       <span class="chip info">${esc(gradeText(s.gtype, s.group, s.grade))}</span>`}
                <span class="chip ${s.personal ? 'warn' : 'ok'}">${s.personal ? 'Personal' : 'Bersama'}</span>
                ${s.duty ? '<span class="chip info">Wajib on duty</span>' : ''}
                ${s.protected ? `<span class="chip warn">Dipakai ${esc(s.protected)}</span>` : ''}
            </div>
            <div class="meta"><span>Berat <b>${s.weight} kg</b></span><span>Slot <b>${s.slots}</b></span>
                <span>${s.coords.x.toFixed(1)}, ${s.coords.y.toFixed(1)}, ${s.coords.z.toFixed(1)}</span></div>
            <div class="actions">
                <button data-act="edit" data-id="${esc(s.id)}">Ubah</button>
                <button data-act="move" data-id="${esc(s.id)}" class="${isArmed('move') ? 'armed' : ''}">${isArmed('move') ? 'Yakin?' : 'Pindah ke sini'}</button>
                <button data-act="tp" data-id="${esc(s.id)}">Teleport</button>
                <button data-act="delete" data-id="${esc(s.id)}" class="del ${isArmed('delete') ? 'armed' : ''}"
                    ${s.protected ? `disabled title="Dipakai ${esc(s.protected)}, tidak bisa dihapus"` : ''}>${isArmed('delete') ? 'Hapus + isi?' : 'Hapus'}</button>
            </div>
        </div>`;
    }).join('');
}

$('#list').addEventListener('click', async (e) => {
    const btn = e.target.closest('button[data-act]');
    if (!btn || btn.disabled || state.busy) return;
    const s = state.stashes.find((x) => x.id === btn.dataset.id);
    if (!s) return;
    const act = btn.dataset.act;

    if (act === 'edit') return openSheet(s);
    if (act === 'tp') return post('teleport', { coords: s.coords });

    if (!armed || armed.id !== s.id || armed.action !== act) {
        armed = { id: s.id, action: act };
        renderList();
        return;
    }
    armed = null;
    state.busy = true;
    applyResult(await post(act, { id: s.id }));
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

function fillGroups(selected) {
    const list = state.groups[state.form.gtype] || [];
    $('#f-group').innerHTML = list.length
        ? list.map((g) => `<option value="${esc(g.name)}">${esc(g.label)} (${esc(g.name)})</option>`).join('')
        : '<option value="">Belum ada</option>';
    if (selected && list.some((g) => g.name === selected)) $('#f-group').value = selected;
    renderGrades();
}

function renderGrades() {
    const f = state.form;
    $('#f-grade').innerHTML = state.grades
        .map((g) => `<button data-v="${g}" class="${g === f.grade ? 'active' : ''}">${g === 0 ? 'Semua' : g}</button>`).join('');
    $('#grade-hint').textContent = f.grade === 0
        ? 'Semua anggota bisa membuka.'
        : `${gradeText(f.gtype, $('#f-group').value, f.grade)} ke atas yang bisa membuka.`;
    $('#duty-row').classList.toggle('hidden', f.gtype !== 'job');
    const isPublic = f.gtype === 'public';
    $('#f-group').classList.toggle('hidden', isPublic);
    $('#grade-box').classList.toggle('hidden', isPublic);
    $('#public-hint').classList.toggle('hidden', !isPublic);
}

function openSheet(s) {
    state.editing = s ? s.id : null;
    state.form = { gtype: s ? s.gtype : 'job', personal: s ? s.personal : false, grade: s ? s.grade : 0 };

    $('#sheet-title').textContent = s ? 'Ubah Stash' : 'Tambah Stash';
    $('#loc-note').textContent = s
        ? 'Lokasi tidak berubah. Pakai tombol "Pindah ke sini" untuk memindah.'
        : `Lokasi = posisi kamu berdiri sekarang (${state.pos ? `${state.pos.x.toFixed(1)}, ${state.pos.y.toFixed(1)}, ${state.pos.z.toFixed(1)}` : '-'}).`;
    $('#f-label').value = s ? s.label : '';
    $('#f-weight').value = s ? s.weight : 500;
    $('#f-slots').value = s ? s.slots : 50;
    $('#f-duty').checked = s ? s.duty : false;

    setSeg('f-gtype', state.form.gtype);
    setSeg('f-personal', state.form.personal ? 1 : 0);
    document.querySelectorAll('#f-personal button').forEach((b) => (b.disabled = !!s));
    $('#personal-hint').textContent = s
        ? 'Akses tidak bisa diubah setelah dibuat (isi lama bisa hilang). Buat stash baru kalau perlu.'
        : 'Bersama: satu isi untuk semua anggota. Personal: tiap anggota punya isi sendiri.';

    fillGroups(s && s.group);
    $('#sheet-msg').classList.add('hidden');
    $('#sheet').classList.remove('hidden');
    $('#f-label').focus();
}

function closeSheet() {
    $('#sheet').classList.add('hidden');
    state.editing = null;
}

$('#add-btn').addEventListener('click', () => openSheet(null));
$('#sheet-close').addEventListener('click', closeSheet);

$('#f-gtype').addEventListener('click', (e) => {
    const b = e.target.closest('button');
    if (!b) return;
    state.form.gtype = b.dataset.v;
    setSeg('f-gtype', b.dataset.v);
    if (b.dataset.v === 'public' && !state.editing) { // stash umum paling aman personal
        state.form.personal = true;
        setSeg('f-personal', 1);
    }
    fillGroups();
});
$('#f-personal').addEventListener('click', (e) => {
    const b = e.target.closest('button');
    if (!b || b.disabled) return;
    state.form.personal = b.dataset.v === '1';
    setSeg('f-personal', b.dataset.v);
});
$('#f-grade').addEventListener('click', (e) => {
    const b = e.target.closest('button');
    if (!b) return;
    state.form.grade = Number(b.dataset.v);
    renderGrades();
});
$('#f-group').addEventListener('change', renderGrades);

$('#save-btn').addEventListener('click', async () => {
    if (state.busy) return;
    const data = {
        id: state.editing,
        label: $('#f-label').value,
        gtype: state.form.gtype,
        group: $('#f-group').value,
        grade: state.form.grade,
        personal: state.form.personal,
        duty: state.form.gtype === 'job' && $('#f-duty').checked,
        weight: Number($('#f-weight').value),
        slots: Number($('#f-slots').value),
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
        state.stashes = data.stashes || [];
        state.groups = data.groups || { job: [], gang: [] };
        state.grades = data.grades || [0, 1, 2, 3, 4];
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
