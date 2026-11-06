(() => {
const $ = (id) => document.getElementById(id);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const safeName = (s) => String(s ?? '').replace(/[^a-zA-Z0-9_-]/g, '');
const rupiah = (n) => 'Rp ' + Math.floor(Number(n) || 0).toString().replace(/\B(?=(\d{3})+(?!\d))/g, '.');
const fmtDate = (t) => {
    if (!t) return '-';
    const d = new Date(Number(t) * 1000);
    const p = (x) => String(x).padStart(2, '0');
    return `${p(d.getDate())}/${p(d.getMonth() + 1)}/${d.getFullYear()} ${p(d.getHours())}:${p(d.getMinutes())}`;
};

function post(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data),
    }).then((r) => r.json()).catch(() => ({ ok: false, msg: 'Server tidak merespons.' }));
}

// gambar kendaraan bersama (f_vehimages) → docs FiveM → ikon mobil
function thumb(model) {
    const m = safeName(model);
    return `<span class="dk-thumb"><img src="nui://f_vehimages/images/${m}.webp" data-alt="https://docs.fivem.net/vehicles/${m}.webp" onerror="dkImgErr(this)"></span>`;
}
window.dkImgErr = (img) => {
    const alt = img.dataset.alt;
    if (alt) { img.dataset.alt = ''; img.src = alt; return; }
    img.parentElement.innerHTML = '<svg class="ic"><use href="#i-car"/></svg>';
};

const S = {
    mode: null,           // 'shop' | 'admin'
    view: 'shop',         // tampilan saat mode shop: 'shop' | 'admin'
    d: null,              // data toko dari server
    cat: null,
    q: '',
    sel: null,
    seq: 0,
    busy: false,
    modal: null,          // 'pay' | 'ticket'
    method: null,
    A: { tab: 'veh', vehicles: [], requests: [], catalog: null, cats: [], filter: 'pending', q: '', cat: '', edit: null, pick: null },
};

const catLabel = (key, cats) => ((cats || []).find((c) => c.key === key) || {}).label || key;
const donationKey = () => ((S.d && S.d.categories) || S.A.cats).find((c) => c.key === 'donasi') ? 'donasi' : null;

// ===================================================================
// TOKO
// ===================================================================
function shopVisible(on) {
    $('shop').classList.toggle('hidden', !on);
}

function vehiclesInCat() {
    const q = S.q.trim().toLowerCase();
    return S.d.vehicles.filter((v) => (q ? (v.label.toLowerCase().includes(q) || v.model.includes(q)) : v.category === S.cat));
}

function renderCats() {
    const used = new Set(S.d.vehicles.map((v) => v.category));
    const cats = S.d.categories.filter((c) => used.has(c.key));
    if (!cats.find((c) => c.key === S.cat)) S.cat = cats.length ? cats[0].key : null;
    $('cats').innerHTML = cats.map((c) => `<button data-cat="${esc(c.key)}" class="${c.key === S.cat ? 'active' : ''} ${c.key === 'donasi' ? 'don' : ''}">${esc(c.label)}</button>`).join('');
    $('cats').classList.toggle('hidden', !!S.q.trim());
}

function reqChip(v) {
    if (!v.donation) return '';
    const r = S.d.requests[v.model];
    if (!r) return '';
    if (r.status === 'pending') return '<span class="chip orange">Menunggu</span>';
    if (r.status === 'approved') return '<span class="chip green">Disetujui</span>';
    if (r.status === 'rejected') return '<span class="chip red">Ditolak</span>';
    return '';
}

function renderList() {
    const list = vehiclesInCat();
    const el = $('vlist');
    const top = el.scrollTop;
    if (!list.length) {
        el.innerHTML = `<div class="empty">${S.d.vehicles.length ? 'Tidak ada kendaraan yang cocok' : 'Belum ada kendaraan di dealer'}<small>${S.d.vehicles.length ? '' : 'Admin menambahkan kendaraan lewat tombol perisai'}</small></div>`;
        return;
    }
    let lastCat = null;
    const searching = !!S.q.trim();
    el.innerHTML = list.map((v) => {
        let head = '';
        if (searching && v.category !== lastCat) { lastCat = v.category; head = `<div class="dk-group">${esc(catLabel(v.category, S.d.categories))}</div>`; }
        return `${head}<button class="dk-item ${v.model === S.sel ? 'sel' : ''}" data-model="${esc(v.model)}">
            ${thumb(v.model)}
            <span class="t"><b>${esc(v.label)}</b><small>${v.donation ? 'Kendaraan donasi' : esc(v.brand || catLabel(v.category, S.d.categories))}</small></span>
            ${reqChip(v) || `<span class="p num">${v.donation ? 'Donasi' : rupiah(v.price)}</span>`}
        </button>`;
    }).join('');
    el.scrollTop = top;
}

function statRows(st) {
    const row = (label, val, pct) => `<div class="row"><div class="sl"><span>${label}</span><b>${val}</b></div><div class="bar"><i style="--v:${pct}%"></i></div></div>`;
    if (!st) {
        return ['Kecepatan Maks', 'Akselerasi', 'Pengereman', 'Traksi'].map((l) => row(l, '-', 0)).join('');
    }
    return row('Kecepatan Maks', `${st.speed} km/j`, st.speedPct)
        + row('Akselerasi', `${st.accelPct}/100`, st.accelPct)
        + row('Pengereman', `${st.brakePct}/100`, st.brakePct)
        + row('Traksi', `${st.tractionPct}/100`, st.tractionPct)
        + `<div class="row"><div class="sl"><span>Jumlah Kursi</span><b>${st.seats}</b></div></div>`;
}

function current() { return S.d && S.d.vehicles.find((v) => v.model === S.sel); }

function renderDetail() {
    const v = current();
    $('detail').classList.toggle('hidden', !v);
    $('detail-empty').classList.toggle('hidden', !!v);
    if (!v) return;
    $('d-cat').textContent = catLabel(v.category, S.d.categories);
    $('d-cat').className = `chip ${v.donation ? 'orange' : 'accent'}`;
    $('d-name').textContent = v.label;
    $('d-brand').textContent = v.brand || v.model;
    $('d-price').textContent = v.donation ? 'Kendaraan Donasi' : rupiah(v.price);
    $('d-price').classList.toggle('don', !!v.donation);

    const note = $('d-note');
    const main = $('btn-main');
    main.className = 'primary b-lg';
    main.disabled = S.busy;
    note.className = 'notice hidden';
    if (v.donation) {
        const r = S.d.requests[v.model];
        if (r && r.status === 'approved') {
            main.textContent = 'Ambil Kendaraan';
            main.classList.add('claim');
            note.className = 'notice';
            note.style.cssText = 'background:var(--green-soft);color:var(--green)';
            note.textContent = 'Permintaanmu sudah disetujui. Tekan Ambil Kendaraan, kendaraan siap di garasi dealer.';
        } else if (r && r.status === 'pending') {
            main.textContent = 'Menunggu Persetujuan';
            main.classList.add('wait');
            main.disabled = true;
            note.className = 'notice warn';
            note.style.cssText = '';
            note.textContent = 'Admin sedang mengecek tiket Discord kamu. Hasilnya dikirim ke email HP.';
        } else {
            main.textContent = 'Beli';
            note.style.cssText = '';
            if (r && r.status === 'rejected') {
                note.className = 'notice bad';
                note.textContent = `Permintaan sebelumnya ditolak: ${r.reason || '-'}`;
            } else {
                note.className = 'notice';
                note.textContent = 'Kendaraan donasi: bisa test drive, pembelian memakai nomor tiket Discord.';
            }
        }
    } else {
        main.textContent = 'Beli';
        note.style.cssText = '';
    }
    $('btn-test-t').textContent = `Test Drive ${Math.round((S.d.testSeconds || 60) / 60)} Menit`;
    $('btn-test').disabled = S.busy;
}

async function select(model) {
    if (!model || S.sel === model) return;
    S.sel = model;
    renderList();
    renderDetail();
    const my = ++S.seq;
    $('stats').classList.add('loading');
    const st = await post('preview', { model });
    if (my !== S.seq) return;
    $('stats').classList.remove('loading');
    $('stats').innerHTML = statRows(st || null);
}

function openShop(d) {
    S.d = d;
    S.d.requests = S.d.requests || {};
    S.q = ''; $('q').value = '';
    S.sel = null; S.busy = false;
    $('title').textContent = d.title || 'Dealer';
    $('btn-admin').classList.toggle('hidden', !d.admin);
    const focus = d.focus && d.vehicles.find((v) => v.model === d.focus);
    S.cat = focus ? focus.category : null;
    renderCats();
    $('stats').innerHTML = statRows(null);
    const first = focus || vehiclesInCat()[0];
    renderList();
    renderDetail();
    if (first) select(first.model);
    shopVisible(true);
}

$('cats').addEventListener('click', (e) => {
    const b = e.target.closest('button[data-cat]');
    if (!b) return;
    S.cat = b.dataset.cat;
    renderCats();
    renderList();
    $('vlist').scrollTop = 0;
});
$('q').addEventListener('input', (e) => { S.q = e.target.value; renderCats(); renderList(); });
$('vlist').addEventListener('click', (e) => {
    const b = e.target.closest('.dk-item');
    if (b) select(b.dataset.model);
});

// --- putar & zoom kamera (maks 1 permintaan berjalan) ---
let drag = null, acc = { dx: 0, dy: 0 }, sending = false;
async function flush() {
    if (sending || (!acc.dx && !acc.dy)) return;
    sending = true;
    const d = acc; acc = { dx: 0, dy: 0 };
    await post('rotate', d);
    sending = false;
    if (acc.dx || acc.dy) flush();
}
$('stage').addEventListener('mousedown', (e) => { drag = { x: e.clientX, y: e.clientY }; $('stage').classList.add('drag'); });
window.addEventListener('mouseup', () => { drag = null; $('stage').classList.remove('drag'); });
window.addEventListener('mousemove', (e) => {
    if (!drag) return;
    acc.dx += e.clientX - drag.x;
    acc.dy += e.clientY - drag.y;
    drag = { x: e.clientX, y: e.clientY };
    flush();
});
$('stage').addEventListener('wheel', (e) => { post('zoom', { delta: e.deltaY > 0 ? 1 : -1 }); }, { passive: true });

// --- tombol ---
$('btn-test').addEventListener('click', () => {
    const v = current();
    if (!v || S.busy) return;
    post('testdrive', { model: v.model });
});

$('btn-main').addEventListener('click', async () => {
    const v = current();
    if (!v || S.busy) return;
    if (!v.donation) return openModal('pay');
    const r = S.d.requests[v.model];
    if (r && r.status === 'approved') {
        S.busy = true; renderDetail();
        $('btn-main').textContent = 'Memproses...';
        const res = await post('claim', { model: v.model });
        S.busy = false;
        if (!res.ok) { renderDetail(); toastNote(res.msg); }
        return;
    }
    if (r && r.status === 'pending') return;
    openModal('ticket');
});

function toastNote(text) {
    const n = $('d-note');
    n.className = 'notice bad';
    n.style.cssText = '';
    n.textContent = text || 'Gagal.';
}

// --- modal ---
function modalMsg(text, ok) {
    $('m-msg').textContent = text || '';
    $('m-msg').classList.toggle('ok', !!ok);
    $('m-msg').classList.toggle('hidden', !text);
}

function openModal(kind) {
    const v = current();
    S.modal = kind;
    modalMsg('');
    $('m-pay').classList.toggle('hidden', kind !== 'pay');
    $('m-ticket').classList.toggle('hidden', kind !== 'ticket');
    $('m-sub').textContent = v.label;
    if (kind === 'pay') {
        $('m-title').textContent = 'Pembayaran';
        $('m-ic').innerHTML = '<svg class="ic"><use href="#i-cash"/></svg>';
        $('m-price').textContent = rupiah(v.price);
        const m = S.d.money || {};
        $('m-cash').textContent = rupiah(m.cash);
        $('m-bank').textContent = rupiah(m.bank);
        S.method = null;
        document.querySelectorAll('.dk-method').forEach((b) => {
            b.classList.remove('active');
            b.classList.toggle('short', (m[b.dataset.m] || 0) < v.price);
        });
        $('m-ok').textContent = 'Bayar';
        $('m-ok').disabled = true;
    } else {
        $('m-title').textContent = 'Tiket Donasi';
        $('m-ic').innerHTML = '<svg class="ic"><use href="#i-ticket"/></svg>';
        $('m-ticket-in').value = '';
        $('m-ok').textContent = 'Kirim Permintaan';
        $('m-ok').disabled = false;
        setTimeout(() => $('m-ticket-in').focus(), 30);
    }
    $('modal').classList.remove('hidden');
}

function closeModal() { S.modal = null; $('modal').classList.add('hidden'); }

document.querySelectorAll('.dk-method').forEach((b) => b.addEventListener('click', () => {
    S.method = b.dataset.m;
    document.querySelectorAll('.dk-method').forEach((x) => x.classList.toggle('active', x === b));
    $('m-ok').disabled = false;
}));
$('m-close').addEventListener('click', closeModal);
$('modal').addEventListener('mousedown', (e) => { if (e.target === $('modal')) closeModal(); });
$('m-ticket-in').addEventListener('keydown', (e) => { if (e.key === 'Enter') $('m-ok').click(); });

$('m-ok').addEventListener('click', async () => {
    const v = current();
    if (!v || S.busy) return;
    if (S.modal === 'pay') {
        if (!S.method) return modalMsg('Pilih metode pembayaran');
        S.busy = true; $('m-ok').disabled = true; $('m-ok').textContent = 'Memproses...';
        const res = await post('buy', { model: v.model, method: S.method });
        S.busy = false;
        if (!res.ok) { $('m-ok').disabled = false; $('m-ok').textContent = 'Bayar'; modalMsg(res.msg); }
        // berhasil: client menutup NUI dan pemain sudah di dalam kendaraan
    } else if (S.modal === 'ticket') {
        const ticket = $('m-ticket-in').value.trim();
        if (!ticket) return modalMsg('Isi nomor tiket Discord');
        S.busy = true; $('m-ok').disabled = true; $('m-ok').textContent = 'Mengirim...';
        const res = await post('request', { model: v.model, ticket });
        S.busy = false; $('m-ok').disabled = false; $('m-ok').textContent = 'Kirim Permintaan';
        if (!res.ok) return modalMsg(res.msg);
        S.d.requests[v.model] = { status: 'pending' };
        closeModal();
        renderList();
        renderDetail();
        const n = $('d-note');
        n.className = 'notice'; n.style.cssText = 'background:var(--green-soft);color:var(--green)';
        n.textContent = res.msg;
    }
});

// ===================================================================
// ADMIN
// ===================================================================
function aMsg(text, ok) {
    const el = $('a-msg');
    el.textContent = text || '';
    el.className = `banner ${ok ? 'ok-msg' : 'bad'}`;
    el.classList.toggle('hidden', !text);
    clearTimeout(aMsg.t);
    if (text) aMsg.t = setTimeout(() => el.classList.add('hidden'), 4000);
}

async function openAdmin(fromShop) {
    S.view = 'admin';
    shopVisible(false);
    $('a-back').classList.toggle('hidden', !fromShop);
    $('admin').classList.remove('hidden');
    $('a-list').innerHTML = '<div class="empty">Memuat...</div>';
    const d = await post('admin:data', { catalog: !S.A.catalog });
    if (!d) { $('a-list').innerHTML = '<div class="empty">Tidak punya akses</div>'; return; }
    S.A.loaded = true;
    S.A.vehicles = d.vehicles || [];
    S.A.requests = d.requests || [];
    S.A.cats = d.categories || [];
    if (d.catalog) S.A.catalog = d.catalog;
    $('a-cat').innerHTML = '<option value="">Semua kategori</option>' + S.A.cats.map((c) => `<option value="${esc(c.key)}">${esc(c.label)}</option>`).join('');
    $('a-cat').value = S.A.cat;
    $('s-cat').innerHTML = S.A.cats.map((c) => `<option value="${esc(c.key)}">${esc(c.label)}</option>`).join('');
    renderAdmin();
}

function closeAdminView() {
    closeSheet();
    $('admin').classList.add('hidden');
    if (S.mode === 'shop') {
        S.view = 'shop';
        shopVisible(true);
        // perubahan admin (tambah/hapus) baru terlihat setelah menu dibuka ulang; daftar lokal disegarkan seadanya
        if (S.d && S.A.loaded) {
            const extra = S.d.vehicles.filter((v) => v.donation && !S.A.vehicles.find((x) => x.model === v.model) && (S.d.requests[v.model] || {}).status === 'approved');
            S.d.vehicles = S.A.vehicles.concat(extra);
            renderCats(); renderList(); renderDetail();
        }
    }
}

function setTab(tab) {
    S.A.tab = tab;
    document.querySelectorAll('#a-tabs button').forEach((b) => b.classList.toggle('active', b.dataset.tab === tab));
    $('a-filter').classList.toggle('hidden', tab !== 'req');
    $('a-catf').classList.toggle('hidden', tab !== 'veh');
    $('a-add').classList.toggle('hidden', tab !== 'veh');
    closeSheet();
    renderAdmin();
    $('a-list').scrollTop = 0;
}

function renderAdmin() {
    const pending = S.A.requests.filter((r) => r.status === 'pending').length;
    $('a-badge').textContent = pending;
    $('a-badge').classList.toggle('hidden', !pending);
    const el = $('a-list');
    const top = el.scrollTop;
    if (S.A.tab === 'veh') el.innerHTML = adminVehicles();
    else el.innerHTML = adminRequests();
    el.scrollTop = top;
}

function adminVehicles() {
    const q = S.A.q.trim().toLowerCase();
    const list = S.A.vehicles.filter((v) => (!S.A.cat || v.category === S.A.cat) && (!q || v.label.toLowerCase().includes(q) || v.model.includes(q)));
    if (!list.length) return `<div class="empty">${S.A.vehicles.length ? 'Tidak ada yang cocok' : 'Dealer masih kosong'}<small>Tekan "Tambah Kendaraan" untuk mulai</small></div>`;
    return list.map((v) => `<div class="card">
        <div class="dk-card-head">${thumb(v.model)}<div class="t"><b>${esc(v.label)}</b><small>${esc(v.model)}</small></div></div>
        <div class="meta"><span class="chip ${v.donation ? 'orange' : 'accent'}">${esc(catLabel(v.category, S.A.cats))}</span><b class="num">${v.donation ? 'Donasi' : rupiah(v.price)}</b></div>
        <div class="dk-cbtns"><button data-edit="${esc(v.model)}">Ubah</button><button class="del" data-del="${esc(v.model)}">Hapus</button></div>
    </div>`).join('');
}

const STATUS = { pending: ['Menunggu', 'orange'], approved: ['Disetujui', 'green'], rejected: ['Ditolak', 'red'], claimed: ['Sudah diambil', 'blue'] };

function adminRequests() {
    const q = S.A.q.trim().toLowerCase();
    const f = S.A.filter;
    const list = S.A.requests.filter((r) => (f === 'all' || r.status === f)
        && (!q || [r.label, r.model, r.name, r.citizenid, r.ticket].some((x) => String(x || '').toLowerCase().includes(q))));
    if (!list.length) return `<div class="empty">${f === 'pending' ? 'Tidak ada permintaan yang menunggu' : 'Belum ada data'}</div>`;
    return list.map((r) => {
        const [sl, sc] = STATUS[r.status] || [r.status, ''];
        let btns = '';
        if (r.status === 'pending') btns = `<div class="dk-cbtns"><button class="approve" data-approve="${r.id}">Setujui</button><button class="reject" data-reject="${r.id}">Tolak</button></div>`;
        else if (r.status === 'approved') btns = `<div class="dk-cbtns one"><button class="reject" data-reject="${r.id}">Batalkan Persetujuan</button></div>`;
        return `<div class="card" data-card="${r.id}">
            <div class="dk-card-head">${thumb(r.model)}<div class="t"><b>${esc(r.label)}</b><small>#${r.id} · ${esc(r.model)}</small></div><span class="chip ${sc}">${sl}</span></div>
            <div class="dk-kv">
                <span>Tiket Discord</span><b class="ticket">${esc(r.ticket)}</b>
                <span>Pemain</span><b>${esc(r.name)}</b>
                <span>Citizen ID</span><b>${esc(r.citizenid)}</b>
                <span>Diajukan</span><b>${fmtDate(r.created)}</b>
                ${r.decided_by ? `<span>Diputuskan</span><b>${esc(r.decided_by)}<br><small>${fmtDate(r.decided)}</small></b>` : ''}
                ${r.reason ? `<span>Alasan</span><b>${esc(r.reason)}</b>` : ''}
                ${r.plate ? `<span>Plat</span><b>${esc(r.plate)}</b>` : ''}
            </div>
            ${btns}
            <div class="dk-reason hidden" data-reason="${r.id}">
                <textarea maxlength="250" placeholder="Alasan penolakan (dikirim ke email pemain)"></textarea>
                <div class="dk-cbtns"><button data-cancel="${r.id}">Batal</button><button class="reject" data-send="${r.id}">Kirim Penolakan</button></div>
            </div>
        </div>`;
    }).join('');
}

let armed = null;
function arm(btn, label) {
    if (armed === btn) return true;
    if (armed) { armed.classList.remove('armed'); armed.textContent = armed.dataset.orig; }
    armed = btn;
    btn.dataset.orig = btn.textContent;
    btn.textContent = label;
    btn.classList.add('armed');
    setTimeout(() => { if (armed === btn) { btn.classList.remove('armed'); btn.textContent = btn.dataset.orig; armed = null; } }, 3000);
    return false;
}

$('a-list').addEventListener('click', async (e) => {
    const b = e.target.closest('button');
    if (!b || S.busy) return;
    if (b.dataset.edit) return openSheet(b.dataset.edit);
    if (b.dataset.del) {
        if (!arm(b, 'Yakin hapus?')) return;
        armed = null;
        S.busy = true;
        const res = await post('admin:remove', { model: b.dataset.del });
        S.busy = false;
        aMsg(res.msg, res.ok);
        if (res.ok) { S.A.vehicles = res.vehicles || []; renderAdmin(); }
        return;
    }
    if (b.dataset.approve) {
        if (!arm(b, 'Yakin setujui?')) return;
        armed = null;
        return decide(Number(b.dataset.approve), true);
    }
    if (b.dataset.reject) {
        const box = document.querySelector(`[data-reason="${b.dataset.reject}"]`);
        box.classList.remove('hidden');
        b.parentElement.classList.add('hidden');
        box.querySelector('textarea').focus();
        return;
    }
    if (b.dataset.cancel) {
        const box = document.querySelector(`[data-reason="${b.dataset.cancel}"]`);
        box.classList.add('hidden');
        box.previousElementSibling.classList.remove('hidden');
        return;
    }
    if (b.dataset.send) {
        const box = document.querySelector(`[data-reason="${b.dataset.send}"]`);
        const reason = box.querySelector('textarea').value.trim();
        if (reason.length < 3) return aMsg('Tulis alasan penolakan (minimal 3 huruf)');
        return decide(Number(b.dataset.send), false, reason);
    }
});

async function decide(id, approve, reason) {
    S.busy = true;
    const res = await post('admin:decide', { id, approve, reason });
    S.busy = false;
    aMsg(res.msg, res.ok);
    if (res.requests) { S.A.requests = res.requests; renderAdmin(); }
}

document.querySelectorAll('#a-tabs button').forEach((b) => b.addEventListener('click', () => setTab(b.dataset.tab)));
document.querySelectorAll('#a-filter button').forEach((b) => b.addEventListener('click', () => {
    S.A.filter = b.dataset.f;
    document.querySelectorAll('#a-filter button').forEach((x) => x.classList.toggle('active', x === b));
    renderAdmin();
    $('a-list').scrollTop = 0;
}));
$('a-q').addEventListener('input', (e) => { S.A.q = e.target.value; renderAdmin(); });
$('a-cat').addEventListener('change', (e) => { S.A.cat = e.target.value; renderAdmin(); });
$('a-back').addEventListener('click', closeAdminView);
$('a-close').addEventListener('click', () => post('close'));
$('btn-admin').addEventListener('click', () => openAdmin(true));

// --- sheet tambah / ubah ---
function sMsg(text) { $('s-msg').textContent = text || ''; $('s-msg').classList.toggle('hidden', !text); }

function openSheet(model) {
    sMsg('');
    S.A.edit = model || null;
    S.A.pick = null;
    $('s-title').textContent = model ? 'Ubah Kendaraan' : 'Tambah Kendaraan';
    $('s-pick').classList.toggle('hidden', !!model);
    $('s-del').classList.add('hidden');
    $('s-q').value = '';
    if (model) {
        const v = S.A.vehicles.find((x) => x.model === model);
        choose(model, v.category, v.price || catalogPrice(model));
    } else {
        $('s-chosen').classList.add('hidden');
        $('s-cat').value = S.A.cats[0] ? S.A.cats[0].key : '';
        $('s-price').value = '';
        renderResults();
        setTimeout(() => $('s-q').focus(), 30);
    }
    syncPrice();
    $('sheet').classList.remove('hidden');
}
function closeSheet() { $('sheet').classList.add('hidden'); S.A.edit = null; S.A.pick = null; }

const catalogItem = (m) => (S.A.catalog || []).find((c) => c.model === m);
const catalogPrice = (m) => (catalogItem(m) || {}).price || 0;

function choose(model, category, price) {
    const c = catalogItem(model) || S.A.vehicles.find((x) => x.model === model) || { model, label: model };
    S.A.pick = model;
    $('s-img').outerHTML = thumb(model).replace('class="dk-thumb"', 'class="dk-thumb" id="s-img"');
    $('s-label').textContent = c.label;
    $('s-model').textContent = model;
    $('s-chosen').classList.remove('hidden');
    $('s-cat').value = S.A.cats.find((x) => x.key === category) ? category : (S.A.cats[0] || {}).key;
    $('s-price').value = price || '';
    $('s-del').classList.toggle('hidden', !S.A.vehicles.find((x) => x.model === model));
    syncPrice();
}

function renderResults() {
    const q = $('s-q').value.trim().toLowerCase();
    const inShop = new Set(S.A.vehicles.map((v) => v.model));
    const all = S.A.catalog || [];
    const list = (q ? all.filter((c) => c.label.toLowerCase().includes(q) || c.model.includes(q)) : all).slice(0, 40);
    $('s-results').innerHTML = list.length ? list.map((c) => `<div class="row" data-pick="${esc(c.model)}">
        <span class="t"><b>${esc(c.label)}</b><small>${esc(c.model)} · ${esc(c.category)} · ${rupiah(c.price)}</small></span>
        ${inShop.has(c.model) ? '<span class="in">Sudah dijual</span>' : ''}
    </div>`).join('') : '<div class="empty">Model tidak ditemukan</div>';
}

function syncPrice() {
    const don = $('s-cat').value === donationKey();
    $('s-price-l').classList.toggle('hidden', don);
    $('s-price-f').classList.toggle('hidden', don);
    $('s-donasi').classList.toggle('hidden', !don);
    $('s-price-f').textContent = $('s-price').value ? rupiah($('s-price').value) : '';
}

$('s-q').addEventListener('input', renderResults);
$('s-results').addEventListener('click', (e) => {
    const r = e.target.closest('[data-pick]');
    if (!r) return;
    const m = r.dataset.pick;
    const existing = S.A.vehicles.find((x) => x.model === m);
    const c = catalogItem(m);
    choose(m, existing ? existing.category : c.category, existing ? (existing.price || c.price) : c.price);
});
$('s-cat').addEventListener('change', syncPrice);
$('s-price').addEventListener('input', syncPrice);
$('s-close').addEventListener('click', closeSheet);

$('s-save').addEventListener('click', async () => {
    if (S.busy) return;
    const model = S.A.edit || S.A.pick;
    if (!model) return sMsg('Pilih model kendaraan dulu');
    const category = $('s-cat').value;
    const price = Math.floor(Number($('s-price').value) || 0);
    if (category !== donationKey() && price < 1) return sMsg('Isi harga');
    S.busy = true;
    const res = await post('admin:save', { model, category, price });
    S.busy = false;
    if (!res.ok) return sMsg(res.msg);
    S.A.vehicles = res.vehicles || S.A.vehicles;
    closeSheet();
    aMsg(res.msg, true);
    renderAdmin();
});

$('s-del').addEventListener('click', async () => {
    const model = S.A.edit || S.A.pick;
    if (!model || S.busy) return;
    if (!arm($('s-del'), 'Yakin hapus dari dealer?')) return;
    armed = null;
    S.busy = true;
    const res = await post('admin:remove', { model });
    S.busy = false;
    if (!res.ok) return sMsg(res.msg);
    S.A.vehicles = res.vehicles || [];
    closeSheet();
    aMsg(res.msg, true);
    renderAdmin();
});

// ===================================================================
// TIMER TEST DRIVE
// ===================================================================
let timerInt = null;
function startTimer(seconds) {
    clearInterval(timerInt);
    if (!seconds) { $('timer').classList.add('hidden'); return; }
    const end = Date.now() + seconds * 1000;
    const tick = () => {
        const left = Math.max(0, Math.ceil((end - Date.now()) / 1000));
        $('t-left').textContent = `${Math.floor(left / 60)}:${String(left % 60).padStart(2, '0')}`;
        $('timer').classList.toggle('low', left <= 10);
        if (!left) clearInterval(timerInt);
    };
    tick();
    timerInt = setInterval(tick, 250);
    $('timer').classList.remove('hidden');
}

// ===================================================================
// PESAN DARI LUA
// ===================================================================
function closeAll() {
    closeModal();
    closeSheet();
    shopVisible(false);
    $('admin').classList.add('hidden');
    S.mode = null; S.view = 'shop';
}

window.addEventListener('message', (e) => {
    const m = e.data || {};
    if (m.action === 'open') {
        S.mode = m.mode;
        if (m.mode === 'shop') { S.view = 'shop'; $('admin').classList.add('hidden'); openShop(m.data); }
        else { openAdmin(false); }
    } else if (m.action === 'close') {
        closeAll();
    } else if (m.action === 'timer') {
        startTimer(m.seconds);
    }
});

window.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape' || !S.mode) return;
    if (S.modal) return closeModal();
    if (!$('sheet').classList.contains('hidden')) return closeSheet();
    if (S.mode === 'shop' && S.view === 'admin') return closeAdminView();
    post('close');
});

$('btn-close').addEventListener('click', () => post('close'));
})();
