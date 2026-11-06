const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'f_cityhall';
const $ = (id) => document.getElementById(id);
const arr = (v) => (Array.isArray(v) ? v : Object.values(v || {}));
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = (n) => 'Rp ' + Number(n || 0).toLocaleString('id-ID');

const post = (name, data = {}) =>
    fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) })
        .then((r) => r.json())
        .catch(() => null);

const ICON = (id) => `<svg class="ic"><use href="#${id}"/></svg>`;

// ikon + warna gradasi kotak dokumen (gaya ikon aplikasi iOS)
const DOC_STYLE = {
    id_card: ['i-id', '#f3b354', '#c8872c'],
    driver_license: ['i-car', '#5ac8fa', '#0a84ff'],
    weaponlicense: ['i-shield', '#8e8e93', '#48484a'],
    stnk: ['i-file', '#bf5af2', '#5e5ce6'],
    tax: ['i-receipt', '#30d158', '#248a3d'],
};

const docThumb = (doc) => {
    const [icon, c1, c2] = DOC_STYLE[doc] || ['i-file', '#f3b354', '#c8872c'];
    return `<div class="thumb" style="--c1:${c1};--c2:${c2}">${ICON(icon)}</div>`;
};

const TAB_LABEL = { all: 'Semua Layanan', license: 'Dokumen', vehicle: 'Kendaraan', redeem: 'Penebusan', company: 'Pajak Perusahaan' };
const STAFF_LABEL = { requests: 'Permohonan', tickets: 'Tilang', prices: 'Atur Harga' };

/* ---------------- LAYANAN WARGA ---------------- */
let S = null;      // data layanan
let tab = 'all';
let cart = [];     // entry ids
let method = 'cash';
let busy = false;

const entryById = (id) => arr(S.entries).find((e) => e.id === id);

function vehicleThumb(model, doc) {
    const safe = String(model || '').replace(/[^a-z0-9_]/gi, '');
    return `<div class="thumb veh"><img src="nui://f_vehimages/images/${safe}.webp" data-model="${safe}" data-doc="${esc(doc)}" onerror="vehImgError(this)"></div>`;
}

window.vehImgError = (img) => {
    if (!img.dataset.tried) {
        img.dataset.tried = '1';
        img.src = `https://docs.fivem.net/vehicles/${img.dataset.model}.webp`;
    } else {
        img.parentNode.outerHTML = docThumb(img.dataset.doc);
    }
};

function renderGrid() {
    const list = arr(S.entries).filter((e) => tab === 'all' || e.category === tab);
    $('s-head').textContent = TAB_LABEL[tab] || 'Layanan';
    $('s-count').textContent = list.length ? `${list.length} layanan` : '';
    if (!list.length) {
        const empty = {
            vehicle: 'Kamu belum punya kendaraan.',
            redeem: 'Tidak ada dokumen atau kendaraan yang harus ditebus.<br><small>SIM, STNK, atau kendaraan yang ditahan polisi akan muncul di sini untuk ditebus.</small>',
        };
        $('grid').innerHTML = `<div class="empty">${empty[tab] || 'Tidak ada layanan.'}</div>`;
        return;
    }
    $('grid').innerHTML = list.map((e) => {
        const inCart = cart.includes(e.id);
        const button = e.disabled
            ? '<span class="cap lock">TERKUNCI</span>'
            : `<button class="cap add ${inCart ? 'in' : ''}" data-id="${esc(e.id)}" title="${inCart ? 'Keluarkan dari keranjang' : ''}">${inCart ? ICON('i-check') : 'TAMBAH'}</button>`;
        return `<div class="app-card ${e.disabled ? 'off' : ''}">
            ${e.model ? vehicleThumb(e.model, e.doc) : docThumb(e.doc)}
            <div class="t">
                ${e.actionLabel ? `<span class="kicker">${esc(e.actionLabel)}</span>` : ''}
                <b>${esc(e.label)}</b>
                <small>${esc(e.sub || '')}</small>
                ${e.disabled ? `<small class="why">${esc(e.disabled)}</small>` : ''}
            </div>
            <div class="buy">${button}<span class="price">${money(e.price)}</span></div>
        </div>`;
    }).join('');
}

function renderCart() {
    cart = cart.filter((id) => entryById(id));
    $('cart-count').textContent = cart.length;
    $('cart-count').classList.toggle('hidden', cart.length === 0);

    $('cart-list').innerHTML = cart.length
        ? `<div class="group">${cart.map((id) => {
            const e = entryById(id);
            const sub = [e.actionLabel, e.sub].filter(Boolean).map(esc).join(' · ');
            return `<div class="row">
                <button class="remove" data-id="${esc(id)}" title="Hapus"></button>
                <span class="t">${esc(e.label)}<small>${sub}</small></span>
                <span class="d">${money(e.price)}</span>
            </div>`;
        }).join('')}</div>`
        : '<div class="cart-empty">Keranjang masih kosong.<small>Tekan TAMBAH pada layanan.</small></div>';

    $('cart-total').textContent = money(cart.reduce((s, id) => s + (entryById(id)?.price || 0), 0));
    $('order-btn').disabled = !cart.length || busy;
}

function showMsg(text) {
    $('cart-msg').textContent = text;
    $('cart-msg').classList.toggle('hidden', !text);
}

function setMethod(m) {
    method = m;
    document.querySelectorAll('.methods button').forEach((b) => b.classList.toggle('active', b.dataset.method === m));
}

function setTab(container, value) {
    container.querySelectorAll('button').forEach((b) => b.classList.toggle('active', b.dataset.tab === value));
}

function openServices(data) {
    S = data;
    cart = [];
    busy = false;
    C = null;
    // tiap loket hanya punya kategorinya sendiri; tab "Semua" cuma muncul kalau lebih dari satu
    const cats = arr(data.categories);
    tab = cats.length > 1 ? 'all' : (cats[0] || 'company');
    $('s-title').textContent = data.label;
    $('s-sub').textContent = data.subtitle || '';
    $('s-logo').innerHTML = ICON(data.police ? 'i-shield' : 'i-home');
    const visible = { all: cats.length > 1, company: !!data.companyTax };
    document.querySelectorAll('#s-tabs button').forEach((b) => {
        const t = b.dataset.tab;
        b.classList.toggle('hidden', t in visible ? !visible[t] : !cats.includes(t));
    });
    setTab($('s-tabs'), tab);

    S.banner = data.closed
        ? 'Pelayanan sedang tutup. Kamu bisa melihat layanan, tetapi pengajuan baru bisa dilakukan saat petugas administrasi sudah bertugas.'
        : data.unpaid ? `Tagihan #${data.unpaid} belum dibayar. Bayar lewat Bank di HP sebelum mengajukan lagi.` : '';
    $('s-banner').textContent = S.banner;
    $('s-banner').classList.toggle('closed', !!data.closed);

    document.querySelector('[data-method="transfer"]').disabled = !data.transfer;
    setMethod('cash');
    showMsg('');
    renderCart();
    renderTab();
    showPanel('services');
}

// tampilkan isi sesuai tab: layanan (+ keranjang) atau Pajak Perusahaan
function renderTab() {
    const service = tab !== 'company';
    $('grid').classList.toggle('hidden', !service);
    $('cart').classList.toggle('hidden', !service);
    $('c-view').classList.toggle('hidden', service);
    $('s-banner').classList.toggle('hidden', !service || !S.banner);
    $('s-head').textContent = TAB_LABEL[tab] || 'Layanan';
    if (service) renderGrid();
    else loadCompany();
}

$('s-tabs').addEventListener('click', (e) => {
    const b = e.target.closest('button');
    if (!b || b.dataset.tab === tab) return;
    tab = b.dataset.tab;
    setTab($('s-tabs'), tab);
    renderTab();
});

$('grid').addEventListener('click', (e) => {
    const b = e.target.closest('.add');
    if (!b) return;
    const id = b.dataset.id;
    if (cart.includes(id)) cart = cart.filter((x) => x !== id);
    else if (cart.length >= (S.maxCart || 6)) return showMsg('Keranjang penuh.');
    else cart.push(id);
    showMsg('');
    renderGrid();
    renderCart();
});

$('cart-list').addEventListener('click', (e) => {
    const rm = e.target.closest('.remove');
    if (!rm) return;
    cart = cart.filter((x) => x !== rm.dataset.id);
    renderGrid();
    renderCart();
});

document.querySelector('.methods').addEventListener('click', (e) => {
    const b = e.target.closest('button');
    if (b && !b.disabled) setMethod(b.dataset.method);
});

$('order-btn').addEventListener('click', async () => {
    if (busy || !cart.length) return;
    busy = true;
    showMsg('');
    renderCart();
    const res = await post('order', { office: S.office, counter: S.counter, ids: cart, method });
    busy = false;
    if (!res || !res.ok) {
        showMsg((res && res.msg) || 'Pengajuan gagal.');
        renderCart();
    }
});

/* ---------------- MEJA PETUGAS ---------------- */
let T = null;
let staffTab = 'requests';

function timeAgo(ts) {
    const s = Math.max(0, Math.floor(Date.now() / 1000 - ts));
    if (s < 60) return 'baru saja';
    if (s < 3600) return Math.floor(s / 60) + ' menit lalu';
    if (s < 86400) return Math.floor(s / 3600) + ' jam lalu';
    return Math.floor(s / 86400) + ' hari lalu';
}

function renderRequests() {
    const list = arr(T.requests);
    $('t-sub').textContent = `${T.label} · ${list.length} permohonan menunggu`;
    $('t-count').textContent = list.length;
    $('t-count').classList.toggle('hidden', !list.length);
    if (!list.length) {
        $('t-list').innerHTML = '<div class="empty">Belum ada permohonan.</div>';
        return;
    }
    $('t-list').innerHTML = list.map((r) => `
        <div class="req" data-id="${r.id}">
            <div class="head">
                <div><b>${esc(r.name)}</b><small>#${esc(r.code)} · ${r.method === 'cash' ? 'Cash' : 'Transfer'} · ${timeAgo(r.time)}</small></div>
                <b>${money(r.price)}</b>
            </div>
            <div class="doc">${esc(r.title)}${r.vehicle ? `<span>${esc(r.vehicle)}</span>` : ''}</div>
            <div class="chips">
                <span class="chip ${r.online ? 'ok' : 'no'}">${r.online ? 'Online' : 'Offline'}</span>
                <span class="chip ${r.near ? 'ok' : 'info'}">${r.near ? 'Di dekatmu' : 'Tidak di dekatmu'}</span>
            </div>
            <div class="actions">
                <button class="approve" ${r.near ? '' : 'disabled'} title="${r.near ? '' : 'Pemohon harus berdiri di dekatmu'}">Setujui</button>
                <button class="reject">Tolak</button>
            </div>
            <div class="reject-box hidden">
                <input class="input" maxlength="150" placeholder="Alasan penolakan (dikirim ke email pemohon)">
                <div class="actions"><button class="reject confirm">Tolak &amp; Refund</button><button class="cancel">Batal</button></div>
            </div>
        </div>`).join('');
}

async function renderPrices() {
    $('t-prices').innerHTML = '<div class="empty">Memuat...</div>';
    const list = await post('prices');
    if (!list) {
        $('t-prices').innerHTML = '<div class="empty">Hanya pimpinan yang bisa mengatur harga.</div>';
        return;
    }
    $('t-prices').innerHTML = `<div class="group plain">${arr(list).map((p) => `
        <div class="row price-row" data-key="${esc(p.key)}">
            <div class="t"><b>${esc(p.label)}</b><small>Default ${p.percent ? p.default + '%' : money(p.default)} · batas ${p.percent ? `${p.min}% - ${p.max}%` : `${money(p.min)} - ${money(p.max)}`}${p.note ? ' · ' + esc(p.note) : ''}</small></div>
            <input class="input" type="number" step="${p.percent ? '0.1' : '1'}" min="${p.min}" max="${p.max}" value="${p.value}">
            <button class="cap add save">SIMPAN</button>
        </div>`).join('')}</div>`;
}

/* ---- tab Tilang (khusus kantor polisi) ---- */
let K = null;           // { tickets, canManage }
let ticketFilter = 'all';

function renderTickets() {
    if (!K) {
        $('k-list').innerHTML = '<div class="empty">Memuat...</div>';
        return;
    }
    const all = arr(K.tickets);
    document.querySelectorAll('#k-filters button').forEach((b) => {
        const f = b.dataset.filter;
        const n = f === 'all' ? all.length : all.filter((t) => t.kind === f).length;
        b.classList.toggle('active', f === ticketFilter);
        b.innerHTML = `${esc(b.dataset.label || (b.dataset.label = b.textContent))}<span>${n}</span>`;
    });

    const list = all.filter((t) => ticketFilter === 'all' || t.kind === ticketFilter);
    $('t-sub').textContent = `Tilang terbuka · ${all.length}`;
    if (!list.length) {
        $('k-list').innerHTML = '<div class="empty">Tidak ada tilang.</div>';
        return;
    }
    $('k-list').innerHTML = list.map((t) => {
        let buttons = '';
        if (K.canManage) {
            const giveBack = t.kind === 'fine' ? '' : '<button class="giveback" data-act="return">Kembalikan</button>';
            const remove = t.kind === 'vehicle' ? '' : `<button class="reject" data-act="delete">${t.kind === 'fine' ? 'Batalkan' : 'Hapus'}</button>`;
            buttons = `<div class="actions ${giveBack && remove ? '' : 'single'}">${giveBack}${remove}</div>`;
        }
        return `<div class="req" data-id="${t.id}">
            <div class="head">
                <div><b>${esc(t.name)}</b><small>${timeAgo(t.created)}${t.officer ? ' · ' + esc(t.officer) : ''}</small></div>
                <b>${money(t.price)}</b>
            </div>
            <div class="doc">${esc(t.condition)}<span>${esc(t.detail || '')}</span></div>
            <div class="phone">
                <span>${ICON('i-call')}<b>${esc(t.phone || 'Tidak ada nomor')}</b></span>
                ${t.phone ? `<button class="copy" data-phone="${esc(t.phone)}">Salin</button>` : ''}
            </div>
            ${buttons}
        </div>`;
    }).join('');
}

async function loadTickets() {
    K = null;
    renderTickets();
    K = (await post('tickets')) || { tickets: [], canManage: false };
    renderTickets();
}

$('k-filters').addEventListener('click', (e) => {
    const b = e.target.closest('button');
    if (!b) return;
    ticketFilter = b.dataset.filter;
    renderTickets();
});

$('k-list').addEventListener('click', async (e) => {
    const copy = e.target.closest('.copy');
    if (copy) return post('copy', { text: copy.dataset.phone });

    const b = e.target.closest('[data-act]');
    if (!b) return;
    // klik pertama mengunci tombol, klik kedua menjalankan (mencegah salah klik)
    if (!b.classList.contains('armed')) {
        document.querySelectorAll('#k-list .armed').forEach((x) => { x.classList.remove('armed'); x.textContent = x.dataset.text; });
        b.dataset.text = b.textContent;
        b.classList.add('armed');
        b.textContent = 'Yakin?';
        return;
    }
    b.disabled = true;
    const id = Number(b.closest('.req').dataset.id);
    const res = await post('ticketAction', { id, action: b.dataset.act });
    if (res && res.ok) loadTickets();
    else { b.disabled = false; b.classList.remove('armed'); b.textContent = b.dataset.text; }
});

function showStaffTab(value) {
    staffTab = value;
    setTab($('t-tabs'), value);
    $('t-head').textContent = STAFF_LABEL[value] || '';
    $('t-list').classList.toggle('hidden', value !== 'requests');
    $('t-tickets').classList.toggle('hidden', value !== 'tickets');
    $('t-prices').classList.toggle('hidden', value !== 'prices');
    if (value === 'prices') renderPrices();
    if (value === 'tickets') loadTickets();
    if (value === 'requests' && T) renderRequests();
}

function openStaff(data) {
    T = data;
    ticketFilter = 'all';
    $('t-tickets-tab').classList.toggle('hidden', !data.tickets);
    $('t-prices-tab').classList.toggle('hidden', !data.isBoss);
    $('t-duty').classList.toggle('hidden', !data.dutyToggle);
    showPanel('staff');
    renderRequests();
    showStaffTab('requests');
}

function updateStaff(data) {
    if (!data) return;
    T = data;
    if (staffTab === 'requests') renderRequests();
}

$('t-tabs').addEventListener('click', (e) => {
    const b = e.target.closest('button');
    if (b) showStaffTab(b.dataset.tab);
});

$('t-refresh').addEventListener('click', async () => {
    if (staffTab === 'prices') return renderPrices();
    if (staffTab === 'tickets') return loadTickets();
    updateStaff(await post('refresh'));
});

$('t-duty').addEventListener('click', () => post('toggleDuty'));

$('t-list').addEventListener('click', async (e) => {
    const card = e.target.closest('.req');
    if (!card) return;
    const id = Number(card.dataset.id);
    const box = card.querySelector('.reject-box');

    if (e.target.closest('.approve')) {
        const b = e.target.closest('.approve');
        if (b.disabled) return;
        b.disabled = true;
        const res = await post('approve', { id });
        if (res && res.ok) updateStaff(await post('refresh'));
        else b.disabled = false;
    } else if (e.target.closest('.confirm')) {
        const b = e.target.closest('.confirm');
        b.disabled = true;
        const res = await post('reject', { id, reason: box.querySelector('input').value });
        if (res && res.ok) updateStaff(await post('refresh'));
        else b.disabled = false;
    } else if (e.target.closest('.reject')) {
        box.classList.remove('hidden');
        box.querySelector('input').focus();
    } else if (e.target.closest('.cancel')) {
        box.classList.add('hidden');
    }
});

$('t-prices').addEventListener('click', async (e) => {
    const b = e.target.closest('.save');
    if (!b) return;
    const row = b.closest('.price-row');
    b.disabled = true;
    await post('setPrice', { key: row.dataset.key, value: Number(row.querySelector('input').value) });
    b.disabled = false;
    renderPrices();
});

/* ---------------- CARI PEKERJAAN ---------------- */
const JOB_STYLE = {
    trucker: ['i-truck', '#ff9f0a'],
    taxi: ['i-car', '#ffcc00'],
    bus: ['i-bus', '#64d2ff'],
    tow: ['i-wrench', '#0a84ff'],
    garbage: ['i-trash', '#30d158'],
    courier: ['i-box', '#ac8e68'],
    reporter: ['i-mic', '#bf5af2'],
    unemployed: ['i-user', '#8e8e93'],
};

let J = null;          // { list, current, currentLabel }
let pickedJob = null;
let jobBusy = false;

function renderJobs() {
    const jobs = arr(J.list);
    const current = jobs.find((j) => j.name === J.current);
    $('j-sub').textContent = `Pekerjaanmu sekarang: ${current ? current.label : J.currentLabel || J.current || '-'}`;
    $('j-list').innerHTML = jobs.map((j) => {
        const [icon, color] = JOB_STYLE[j.name] || ['i-briefcase', '#f3b354'];
        // side jobs never become the current job, they only open their own menu
        const isCurrent = j.name === J.current && !j.sideJob;
        return `<button class="row ${pickedJob === j.name ? 'sel' : ''}" data-job="${esc(j.name)}" ${isCurrent ? 'disabled' : ''}>
            <span class="sq" style="--c:${color}">${ICON(icon)}</span>
            <span class="t">${esc(j.label)}<small>${esc(j.desc || '')}</small></span>
            ${isCurrent ? '<span class="chip ok">Saat ini</span>' : j.sideJob ? '<span class="chip info">Sampingan</span>' : '<svg class="ic chk"><use href="#i-check"/></svg>'}
        </button>`;
    }).join('');
    const picked = jobs.find((j) => j.name === pickedJob);
    $('j-apply').disabled = !picked || jobBusy;
    $('j-apply').textContent = !picked ? 'Pilih pekerjaan'
        : picked.name === 'unemployed' ? 'Berhenti Bekerja'
        : picked.sideJob ? 'Buka Menu Kerja'
        : `Lamar sebagai ${picked.label}`;
}

function showJobMsg(text) {
    $('j-msg').textContent = text;
    $('j-msg').classList.toggle('hidden', !text);
}

function openJobs(data) {
    J = data;
    pickedJob = null;
    jobBusy = false;
    showJobMsg('');
    renderJobs();
    showPanel('jobs');
}

$('j-list').addEventListener('click', (e) => {
    const row = e.target.closest('[data-job]');
    if (!row || row.disabled) return;
    pickedJob = row.dataset.job;
    showJobMsg('');
    renderJobs();
});

$('j-apply').addEventListener('click', async () => {
    if (jobBusy || !pickedJob) return;
    jobBusy = true;
    renderJobs();
    const res = await post('applyJob', { job: pickedJob });
    jobBusy = false;
    if (!res || !res.ok) {
        showJobMsg((res && res.msg) || 'Gagal melamar pekerjaan.');
        renderJobs();
    }
});

/* ---------------- PAJAK PERUSAHAAN (f_tax) ---------------- */
let C = null;          // payload f_tax mode 'pay' atau { err }
let cHist = null;      // riwayat pembayaran
let cBusy = false;
let cConfirm = false;
let cTimer = null;

async function loadCompany() {
    $('s-count').textContent = '';
    $('c-body').innerHTML = '<div class="empty">Memuat...</div>';
    const data = await post('companyTax');
    if (data && data.soft && C) return renderCompany(); // klik terlalu cepat, pakai data lama
    C = data || { err: 'Server tidak merespons.' };
    cHist = null;
    cConfirm = false;
    if (tab === 'company') renderCompany();
    loadCompanyHistory();
}

async function loadCompanyHistory() {
    const j = C && !C.err && arr(C.jobs)[0];
    if (!j) return;
    const rows = await post('companyTaxHistory', { job: j.name });
    cHist = arr(rows);
    if (tab === 'company') renderCompany();
}

function renderCompany() {
    const j = C && !C.err && arr(C.jobs)[0];
    if (!j) {
        $('c-body').innerHTML = `<div class="empty">${esc((C && C.err) || 'Tidak ada data pajak.')}</div>`;
        return;
    }
    const noBank = j.balance === null || j.balance === undefined;
    const short = !noBank && j.balance < j.tax;
    const status = j.tax <= 0 ? '<span class="chip ok">Tidak ada tagihan</span>'
        : short ? '<span class="chip no">Saldo kurang</span>'
        : '<span class="chip warn">Belum bayar</span>';
    $('s-count').textContent = `${j.label} · tarif ${C.rate}%`;

    const hist = cHist === null
        ? '<div class="row"><span class="t" style="color:var(--label-2)">Memuat...</span></div>'
        : cHist.length
            ? cHist.map((r) => `<div class="row"><span class="t">${esc(r.date)}</span><span class="d">${money(r.amount)}</span></div>`).join('')
            : '<div class="row"><span class="t" style="color:var(--label-2)">Belum ada riwayat pembayaran.</span></div>';

    $('c-body').innerHTML = `
        <div class="tax-hero"><div><small>Pajak yang harus dibayar</small><div class="big">${money(j.tax)}</div></div>${status}</div>
        <div class="group plain">
            <div class="row"><span class="t">Jumlah transaksi</span><span class="d">${Number(j.count || 0).toLocaleString('id-ID')}</span></div>
            <div class="row"><span class="t">Total pendapatan</span><span class="d">${money(j.income)}</span></div>
            <div class="row"><span class="t">Saldo rekening</span><span class="d ${short ? 'bad' : ''}">${noBank ? '-' : money(j.balance)}</span></div>
            <div class="row"><span class="t">Tarif pajak</span><span class="d">${C.rate}%</span></div>
            <div class="row"><span class="t">Terakhir bayar</span><span class="d">${esc(j.lastPaid || '-')}</span></div>
        </div>
        <button class="b b-filled b-lg b-block" id="c-pay" ${j.tax <= 0 || short || cBusy ? 'disabled' : ''}>${cBusy ? 'Memproses...' : cConfirm ? `Konfirmasi bayar ${money(j.tax)}` : 'Bayar Pajak'}</button>
        <div class="group-h">Riwayat pembayaran</div>
        <div class="group plain">${hist}</div>`;
}

$('c-body').addEventListener('click', async (e) => {
    if (!e.target.closest('#c-pay') || cBusy) return;
    // klik pertama minta konfirmasi, klik kedua membayar
    if (!cConfirm) {
        cConfirm = true;
        clearTimeout(cTimer);
        cTimer = setTimeout(() => { cConfirm = false; if (tab === 'company') renderCompany(); }, 4000);
        return renderCompany();
    }
    clearTimeout(cTimer);
    cConfirm = false;
    cBusy = true;
    renderCompany();
    const res = await post('payCompanyTax');
    cBusy = false;
    if (res && res.data && !res.data.err) C = res.data;
    if (res && res.ok) { cHist = null; loadCompanyHistory(); }
    if (tab === 'company') renderCompany();
});

/* ---------------- GLOBAL ---------------- */
const PANELS = ['services', 'staff', 'jobs'];

function showPanel(id) {
    PANELS.forEach((p) => $(p).classList.toggle('hidden', p !== id));
}

function closeAll() {
    showPanel(null);
}

document.querySelectorAll('[data-close]').forEach((b) => b.addEventListener('click', () => post('close')));
document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    post('close');
});

window.addEventListener('message', ({ data }) => {
    switch (data.action) {
        case 'openServices': return openServices(data.data);
        case 'openStaff': return openStaff(data.data);
        case 'openJobs': return openJobs(data.data);
        case 'staffData': return updateStaff(data.data);
        case 'close': return closeAll();
    }
});
