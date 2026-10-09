const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'f_karakter';
const $ = (id) => document.getElementById(id);

const state = { days: 30, search: '', loading: false, rows: [], now: 0 };
let searchTimer = 0;

function post(name, data) {
    return fetch(`https://${RES}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data || {}),
    }).then((r) => r.json()).catch(() => ({ error: 'Gagal terhubung' }));
}

const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const rp = (n) => 'Rp ' + Math.floor(n || 0).toLocaleString('id-ID');

function ago(ts) {
    if (!ts) return { text: 'Belum pernah logout', days: Infinity };
    const days = Math.floor((state.now - ts) / 86400);
    if (days <= 0) return { text: 'Hari ini', days };
    return { text: `${days} hari lalu`, days };
}

function setMsg(text, kind) {
    const old = document.querySelector('.msg');
    if (old) old.remove();
    if (!text) return;
    const el = document.createElement('div');
    el.className = `msg ${kind || 'err'}`;
    el.textContent = text;
    $('list').before(el);
    setTimeout(() => el.remove(), 5000);
}

function render() {
    const list = $('list');
    if (!state.rows.length) {
        list.innerHTML = `<div class="empty">${state.loading ? 'Memuat...' : 'Tidak ada karakter yang cocok.'}</div>`;
    } else {
        list.innerHTML = state.rows.map((r, i) => {
            const a = ago(r.lastSeen);
            const chip = r.online ? '<i class="chip on">ONLINE</i>' : (a.days >= 30 ? '<i class="chip old">TIDAK AKTIF</i>' : '');
            return `<div class="row">
                <div><b>${esc(r.name)}${chip}</b><span>${esc(r.citizenid)} · akun ${esc(r.account)}</span></div>
                <div><span>Terakhir main</span><div class="val">${esc(a.text)}</div><span>${esc(r.job)}</span></div>
                <div><span>Bank / Cash</span><div class="val">${rp(r.bank)} / ${rp(r.cash)}</div><span>${r.vehicles} kendaraan</span></div>
                <button class="del" data-i="${i}" ${r.online ? 'disabled title="Sedang online"' : ''}>Hapus</button>
            </div>`;
        }).join('');
    }
    $('foot').textContent = state.rows.length ? `${state.rows.length} karakter ditampilkan (maks. 50, yang paling lama tidak aktif di atas)` : '';
}

async function load() {
    state.loading = true;
    render();
    const res = await post('list', { days: state.days, search: state.search });
    state.loading = false;
    if (res.error) { state.rows = []; setMsg(res.error); }
    else { state.rows = res.list || []; state.now = res.now; }
    render();
}

function setDays(days) {
    state.days = days;
    document.querySelectorAll('#days button').forEach((b) => b.classList.toggle('active', Number(b.dataset.days) === days));
}

$('days').addEventListener('click', (e) => {
    const b = e.target.closest('button');
    if (!b) return;
    setDays(Number(b.dataset.days));
    load();
});

$('search').addEventListener('input', (e) => {
    state.search = e.target.value.trim();
    clearTimeout(searchTimer);
    searchTimer = setTimeout(load, 350);
});

// Hapus: klik pertama = konfirmasi (4 detik), klik kedua = hapus
$('list').addEventListener('click', async (e) => {
    const b = e.target.closest('.del');
    if (!b || b.disabled) return;
    const r = state.rows[Number(b.dataset.i)];
    if (!r) return;
    if (!b.classList.contains('armed')) {
        document.querySelectorAll('.del.armed').forEach((x) => { x.classList.remove('armed'); x.textContent = 'Hapus'; });
        b.classList.add('armed');
        b.textContent = 'Yakin? Klik lagi';
        setTimeout(() => { if (b.isConnected) { b.classList.remove('armed'); b.textContent = 'Hapus'; } }, 4000);
        return;
    }
    b.disabled = true;
    b.textContent = 'Menghapus...';
    const res = await post('delete', { citizenid: r.citizenid });
    if (res.error) { setMsg(res.error); b.disabled = false; b.classList.remove('armed'); b.textContent = 'Hapus'; return; }
    setMsg(`Karakter ${r.name} (${r.citizenid}) sudah dihapus.`, 'ok');
    state.rows = state.rows.filter((x) => x.citizenid !== r.citizenid);
    render();
});

function close() {
    $('panel').classList.add('hidden');
    post('close');
}

$('close').addEventListener('click', close);
$('refresh').addEventListener('click', load);
document.addEventListener('keydown', (e) => { if (e.key === 'Escape' && !$('panel').classList.contains('hidden')) close(); });

window.addEventListener('message', (e) => {
    const d = e.data || {};
    if (d.action === 'open') {
        $('panel').classList.remove('hidden');
        $('search').value = '';
        state.search = '';
        setDays(Number(d.days ?? 30));
        load();
    } else if (d.action === 'close') {
        $('panel').classList.add('hidden');
    }
});
