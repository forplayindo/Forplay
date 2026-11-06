const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'f_graffiti';
const $ = (s) => document.querySelector(s);

const state = { data: null, tab: 'spray', pick: null, busy: false };
let armed = null; // id graffiti yang menunggu klik kedua (konfirmasi hapus)
let armTimer, msgTimer;

const post = (name, data) =>
    fetch(`https://${RES}/${name}`, { method: 'POST', body: JSON.stringify(data || {}) }).then((r) => r.json()).catch(() => null);

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const img = (key) => `../images/${key.split('/').map(encodeURIComponent).join('/')}`;

function banner(text, error) {
    const el = $('#msg');
    el.textContent = text;
    el.classList.toggle('error', !!error);
    el.classList.remove('hidden');
    clearTimeout(msgTimer);
    msgTimer = setTimeout(() => el.classList.add('hidden'), 4000);
}

function fmtDate(sec) {
    const d = new Date(sec * 1000);
    const p = (n) => String(n).padStart(2, '0');
    return `${p(d.getDate())}/${p(d.getMonth() + 1)} ${p(d.getHours())}:${p(d.getMinutes())}`;
}

function isFull() {
    const d = state.data;
    return d.list.length >= d.max;
}

// ---------------------------------------------------------------- header
function renderHead() {
    const d = state.data;
    $('#sub').textContent = d.gang;
    $('#pylox').textContent = d.sprayLeft > 0 ? `Pylox: sisa ${d.sprayLeft}/${d.sprayUses}` : 'Pylox habis';
    $('#pylox').className = `chip ${d.sprayLeft > 0 ? 'accent' : 'red'}`;
    $('#tab-list').textContent = `Graffiti Gang (${d.list.length}/${d.max})`;
}

// ---------------------------------------------------------------- semprot
function renderDesigns() {
    const d = state.data;
    const box = $('#designs');
    if (!d.designs.length) {
        box.innerHTML = '<div class="empty">Gangmu belum punya desain graffiti.<small>Minta admin menambahkan desain PNG untuk gangmu.</small></div>';
    } else {
        box.innerHTML = d.designs.map((g) => `
            <button class="design${state.pick === g.key ? ' sel' : ''}" data-key="${esc(g.key)}">
                <div class="art"><img src="${img(g.key)}" alt=""></div>
                <b>${esc(g.label)}</b>
            </button>`).join('');
    }

    const full = isFull();
    const note = $('#full-note');
    note.classList.toggle('hidden', !full);
    note.textContent = `Graffiti gangmu sudah ${d.max}/${d.max}. Bersihkan salah satu di tembok, atau hapus di tab Graffiti Gang.`;

    const can = !!state.pick && !full && d.sprayLeft > 0;
    $('#spray-btn').disabled = !can;
    $('#pick-note').textContent = full ? 'Slot penuh.' : d.sprayLeft <= 0 ? 'Kamu tidak punya pylox.' : state.pick ? 'Tekan Semprot lalu bidik tembok.' : 'Pilih desain lalu tekan Semprot.';
}

// ---------------------------------------------------------------- daftar gang
function renderList() {
    const d = state.data;
    const box = $('#list');
    const top = box.scrollTop;
    if (!d.list.length) {
        box.innerHTML = '<div class="empty">Belum ada graffiti gangmu di kota.</div>';
        return;
    }
    box.innerHTML = d.list.map((g) => `
        <div class="row-g">
            <div class="art">${g.missing ? '' : `<img src="${img(g.design)}" alt="">`}</div>
            <div class="t">
                <b>${esc(g.label)}</b>
                <span class="loc"><svg class="ic"><use href="#i-pin"/></svg>${esc(g.street)} · ${g.dist < 1000 ? `${g.dist} m` : `${(g.dist / 1000).toFixed(1)} km`}</span>
                <small>oleh ${esc(g.by)} · ${fmtDate(g.created)}</small>
            </div>
            <button class="b b-sm b-red-tint del${armed === g.id ? ' armed' : ''}" data-id="${g.id}">
                <svg class="ic"><use href="#i-trash"/></svg>${armed === g.id ? 'Yakin hapus?' : 'Hapus'}
            </button>
        </div>`).join('');
    box.scrollTop = top;
}

function render() {
    renderHead();
    renderDesigns();
    renderList();
}

function setTab(tab) {
    state.tab = tab;
    document.querySelectorAll('#tabs button').forEach((b) => b.classList.toggle('active', b.dataset.tab === tab));
    $('#view-spray').classList.toggle('hidden', tab !== 'spray');
    $('#view-list').classList.toggle('hidden', tab !== 'list');
}

function close() {
    $('#panel').classList.add('hidden');
    state.data = null;
    armed = null;
    post('close');
}

// ---------------------------------------------------------------- events
$('#tabs').addEventListener('click', (e) => {
    const b = e.target.closest('button[data-tab]');
    if (b) setTab(b.dataset.tab);
});

$('#designs').addEventListener('click', (e) => {
    const b = e.target.closest('.design');
    if (!b) return;
    state.pick = b.dataset.key;
    renderDesigns();
});

$('#spray-btn').addEventListener('click', () => {
    if (!state.pick || isFull()) return;
    const key = state.pick;
    $('#panel').classList.add('hidden');
    state.data = null;
    post('spray', { key });
});

$('#list').addEventListener('click', async (e) => {
    const b = e.target.closest('.del');
    if (!b || state.busy) return;
    const id = Number(b.dataset.id);
    if (armed !== id) {
        armed = id;
        clearTimeout(armTimer);
        armTimer = setTimeout(() => { armed = null; if (state.data) renderList(); }, 3000);
        return renderList();
    }
    armed = null;
    state.busy = true;
    const res = await post('remove', { id });
    state.busy = false;
    if (!res) return banner('Tidak ada respon server.', true);
    if (res.designs) {
        state.data = res;
        render();
    }
    banner(res.msg || (res.ok ? 'Berhasil.' : 'Gagal.'), !res.ok);
});

document.querySelector('[data-close]').addEventListener('click', close);
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape' && state.data) close();
});

window.addEventListener('message', ({ data: m }) => {
    if (m.action === 'open') {
        state.data = m.data;
        if (!m.data.designs.some((g) => g.key === state.pick)) state.pick = m.data.designs.length === 1 ? m.data.designs[0].key : null;
        armed = null;
        $('#msg').classList.add('hidden');
        setTab(isFull() && m.data.list.length ? 'list' : 'spray');
        render();
        $('#panel').classList.remove('hidden');
    } else if (m.action === 'close') {
        $('#panel').classList.add('hidden');
        state.data = null;
    } else if (m.action === 'hint') {
        $('#hint').classList.toggle('hidden', !m.show);
        if (m.show && m.data) {
            const st = $('#h-status');
            st.className = `st ${m.data.status}`;
            st.textContent = m.data.status === 'ok' ? 'Siap semprot' : m.data.status === 'far' ? 'Terlalu jauh' : 'Arahkan ke tembok';
            $('#h-size').textContent = m.data.w.toFixed(1);
            $('#h-rot').textContent = m.data.rot;
        }
    }
});
