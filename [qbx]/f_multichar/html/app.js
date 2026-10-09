const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'f_multichar';
const $ = (id) => document.getElementById(id);

const ICON = {
    pin: '<svg viewBox="0 0 24 24"><path d="M12 2a7 7 0 0 0-7 7c0 5.3 7 13 7 13s7-7.7 7-13a7 7 0 0 0-7-7Zm0 9.5A2.5 2.5 0 1 1 12 6.5a2.5 2.5 0 0 1 0 5Z"/></svg>',
    city: '<svg viewBox="0 0 24 24"><path d="M3 21V9l6-3v3l6-3v5h6v10H3Zm2-2h2v-2H5v2Zm0-4h2v-2H5v2Zm4 4h2v-2H9v2Zm0-4h2v-2H9v2Zm4 4h2v-2h-2v2Zm4 0h2v-2h-2v2Zm0-4h2v-2h-2v2Z"/></svg>',
    home: '<svg viewBox="0 0 24 24"><path d="M12 3 2 12h3v8h5v-6h4v6h5v-8h3L12 3Z"/></svg>',
    user: '<svg viewBox="0 0 24 24"><path d="M12 12a5 5 0 1 0 0-10 5 5 0 0 0 0 10Zm0 2c-4.4 0-8 2.2-8 5v2h16v-2c0-2.8-3.6-5-8-5Z"/></svg>',
    cal: '<svg viewBox="0 0 24 24"><path d="M7 2v2H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V6a2 2 0 0 0-2-2h-2V2h-2v2H9V2H7Zm12 8H5v10h14V10Z"/></svg>',
    sex: '<svg viewBox="0 0 24 24"><path d="M15 2v2h3.6l-3.2 3.2A6 6 0 1 0 11 17.9V20H9v2h2v2h2v-2h2v-2h-2v-2.1a6 6 0 0 0 3.8-9.3L20 5.4V9h2V2h-7Zm-3 6a4 4 0 1 1 0 8 4 4 0 0 1 0-8Z"/></svg>',
};

const state = { chars: [], slots: 1, sel: 0, loc: {}, gender: 0, birth: { min: '1900-01-01', max: '2006-12-31' }, busy: false };

function post(name, data) {
    return fetch(`https://${RES}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data || {}),
    }).then((r) => r.json()).catch(() => ({ error: 'Gagal terhubung' }));
}

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const rp = (n) => 'Rp ' + Math.floor(Number(n) || 0).toLocaleString('id-ID');
const dmy = (iso) => { const m = /^(\d{4})-(\d{2})-(\d{2})/.exec(iso || ''); return m ? `${m[3]}-${m[2]}-${m[1]}` : (iso || '-'); };

/* ---------- render ---------- */
function renderSlots() {
    let html = state.chars.map((c, i) => `<button class="slot ${i === state.sel ? 'active' : ''}" data-i="${i}">
        <span class="first">${esc(c.first)}</span><span class="last">${esc(c.last)}</span>
        <span class="sex ${c.gender === 1 ? 'f' : ''}">${c.gender === 1 ? '♀' : '♂'}</span></button>`).join('');
    for (let i = state.chars.length; i < state.slots; i++) {
        html += `<button class="slot plus ${i === state.sel ? 'active' : ''}" data-i="${i}"><span class="p">+</span></button>`;
    }
    $('slots').innerHTML = html;
}

function renderExisting(c) {
    $('left').innerHTML = `<div class="title">Informasi</div>
        <div class="info">
            <div class="row"><span>Citizen ID</span><b>${esc(c.citizenid)}</b></div>
            <div class="row"><span>Tanggal Lahir</span><b>${esc(dmy(c.birthdate))}</b></div>
            <div class="row"><span>Kewarganegaraan</span><b>${esc(c.nationality || 'Indonesia')}</b></div>
            <div class="row"><span>Pekerjaan</span><b>${esc(c.job || '-')}${c.grade ? ' · ' + esc(c.grade) : ''}</b></div>
            <div class="row"><span>Gang</span><b>${esc(c.gang || '-')}</b></div>
            <div class="row"><span>Telepon</span><b>${esc(c.phone || '-')}</b></div>
            <div class="row"><span>Bank</span><b class="money">${rp(c.bank)}</b></div>
            <div class="row"><span>Cash</span><b class="money">${rp(c.cash)}</b></div>
        </div>`;
    const cur = state.loc[c.citizenid] || 'last';
    $('right').innerHTML = `<div class="title">Lokasi Spawn</div>
        <div class="locs">${c.locations.map((l) => `<button class="loc ${l.key === cur ? 'active' : ''}" data-key="${esc(l.key)}">
            <div class="txt"><b>${esc(l.label)}</b><small>${esc(l.area)}</small></div><div class="ico">${ICON[l.icon] || ICON.pin}</div></button>`).join('')}</div>
        <button class="btn" id="play">Main</button>
        <div class="err" id="err"></div>`;
}

function renderNew() {
    $('left').innerHTML = '';
    $('right').innerHTML = `<div class="title">Karakter Baru</div>
        <div class="form">
            <div class="field"><div class="seg" id="gender">
                <button data-g="0" class="${state.gender === 0 ? 'on' : ''}">Laki-laki</button>
                <button data-g="1" class="${state.gender === 1 ? 'on' : ''}">Perempuan</button>
            </div><div class="ico">${ICON.sex}</div></div>
            <div class="field"><input id="first" maxlength="20" placeholder="Nama depan"><div class="ico">${ICON.user}</div></div>
            <div class="field"><input id="last" maxlength="20" placeholder="Nama belakang"><div class="ico">${ICON.user}</div></div>
            <div class="field"><input id="birth" maxlength="10" placeholder="dd/mm/yyyy" inputmode="numeric"><div class="ico">${ICON.cal}</div></div>
        </div>
        <button class="btn" id="create">Buat Karakter</button>
        <div class="err" id="err"></div>
        <div class="hint">Karakter baru langsung muncul di City Hall</div>`;
}

function render() {
    renderSlots();
    const c = state.chars[state.sel];
    if (c) renderExisting(c); else renderNew();
}

function setErr(text) { const e = $('err'); if (e) e.textContent = text || ''; }

/* ---------- validasi form karakter baru ---------- */
const NAME_RE = /^[A-Za-z][A-Za-z '.-]{1,19}$/;

function parseBirth(v) {
    const m = /^(\d{2})\/(\d{2})\/(\d{4})$/.exec(v);
    if (!m) return null;
    const iso = `${m[3]}-${m[2]}-${m[1]}`;
    const d = new Date(`${iso}T00:00:00Z`);
    if (isNaN(d) || d.toISOString().slice(0, 10) !== iso) return null;
    if (iso < state.birth.min || iso > state.birth.max) return null;
    return iso;
}

/* ---------- event ---------- */
$('slots').addEventListener('click', (e) => {
    const b = e.target.closest('.slot');
    if (!b || state.busy) return;
    const i = Number(b.dataset.i);
    if (i === state.sel) return;
    state.sel = i;
    render();
    post('select', { index: i + 1, gender: state.gender });
});

$('right').addEventListener('click', async (e) => {
    if (state.busy) return;

    const loc = e.target.closest('.loc');
    if (loc) {
        const c = state.chars[state.sel];
        state.loc[c.citizenid] = loc.dataset.key;
        document.querySelectorAll('.loc').forEach((x) => x.classList.toggle('active', x === loc));
        return;
    }

    const g = e.target.closest('[data-g]');
    if (g) {
        state.gender = Number(g.dataset.g);
        document.querySelectorAll('#gender button').forEach((x) => x.classList.toggle('on', x === g));
        post('gender', { gender: state.gender });
        return;
    }

    if (e.target.id === 'play') {
        const c = state.chars[state.sel];
        state.busy = true;
        e.target.disabled = true;
        setErr('');
        const res = await post('play', { index: state.sel + 1, location: state.loc[c.citizenid] || 'last' });
        state.busy = false;
        if (res.error) { e.target.disabled = false; setErr(res.error); }
        return;
    }

    if (e.target.id === 'create') {
        const first = $('first').value.trim().replace(/\s+/g, ' ');
        const last = $('last').value.trim().replace(/\s+/g, ' ');
        const birth = parseBirth($('birth').value.trim());
        if (!NAME_RE.test(first)) return setErr('Nama depan 2-20 huruf, tanpa angka/simbol.');
        if (!NAME_RE.test(last)) return setErr('Nama belakang 2-20 huruf, tanpa angka/simbol.');
        if (!birth) return setErr(`Tanggal lahir tidak valid (${dmy(state.birth.min)} s/d ${dmy(state.birth.max)}).`);
        state.busy = true;
        e.target.disabled = true;
        setErr('');
        const res = await post('create', { firstname: first, lastname: last, birthdate: birth, gender: state.gender });
        state.busy = false;
        if (res.error) { e.target.disabled = false; setErr(res.error); }
    }
});

// tanggal lahir: otomatis tambah "/" saat mengetik
$('right').addEventListener('input', (e) => {
    if (e.target.id !== 'birth') return;
    const d = e.target.value.replace(/\D/g, '').slice(0, 8);
    e.target.value = d.length > 4 ? `${d.slice(0, 2)}/${d.slice(2, 4)}/${d.slice(4)}` : d.length > 2 ? `${d.slice(0, 2)}/${d.slice(2)}` : d;
});

window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.action === 'open') {
        state.chars = d.characters || [];
        state.slots = Math.max(1, Number(d.slots) || 1, state.chars.length);
        state.sel = 0;
        state.loc = {};
        state.gender = 0;
        state.busy = false;
        if (d.birthdate) state.birth = d.birthdate;
        render();
        $('app').classList.remove('hidden');
    } else if (d.action === 'close') {
        $('app').classList.add('hidden');
    }
});
