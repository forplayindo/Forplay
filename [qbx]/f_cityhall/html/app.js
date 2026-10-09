const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'f_cityhall';
const $ = (id) => document.getElementById(id);
const arr = (v) => (Array.isArray(v) ? v : Object.values(v || {}));
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const money = (n) => 'Rp ' + Number(n || 0).toLocaleString('id-ID');

const post = (name, data = {}) =>
    fetch(`https://${RES}/${name}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data) })
        .then((r) => r.json())
        .catch(() => null);

const DOC_ICON = { id_card: '🪪', driver_license: '🚗', weaponlicense: '🔫', stnk: '📄', tax: '🧾' };

/* ---------------- LAYANAN WARGA ---------------- */
let S = null;      // data layanan
let tab = 'all';
let cart = [];     // entry ids
let method = 'cash';
let busy = false;

const entryById = (id) => arr(S.entries).find((e) => e.id === id);

function vehicleImg(model, fallback) {
    const safe = String(model || '').replace(/[^a-z0-9_]/gi, '');
    return `<img src="nui://f_vehimages/images/${safe}.webp" data-model="${safe}" data-fallback="${fallback}" onerror="vehImgError(this)">`;
}

window.vehImgError = (img) => {
    if (!img.dataset.tried) {
        img.dataset.tried = '1';
        img.src = `https://docs.fivem.net/vehicles/${img.dataset.model}.webp`;
    } else {
        img.parentNode.textContent = img.dataset.fallback;
    }
};

function renderGrid() {
    const list = arr(S.entries).filter((e) => tab === 'all' || e.category === tab);
    if (!list.length) {
        const empty = {
            vehicle: 'Kamu belum punya kendaraan.',
            redeem: 'Tidak ada dokumen atau kendaraan yang harus ditebus.<br><small>SIM, STNK, atau kendaraan yang ditahan polisi akan muncul di sini untuk ditebus.</small>',
        };
        $('grid').innerHTML = `<div class="empty">${empty[tab] || 'Tidak ada layanan.'}</div>`;
        return;
    }
    $('grid').innerHTML = list.map((e) => {
        const icon = DOC_ICON[e.doc] || '📄';
        const inCart = cart.includes(e.id);
        const button = e.disabled
            ? `<div class="reason">${esc(e.disabled)}</div>`
            : `<button class="add ${inCart ? 'in' : ''}" data-id="${esc(e.id)}">${inCart ? '✓ Di keranjang' : 'Tambah'}</button>`;
        return `<div class="card ${e.disabled ? 'off' : ''}">
            <span class="tag">${esc(e.actionLabel || '')}</span>
            <div class="img">${e.model ? vehicleImg(e.model, icon) : icon}</div>
            <h3>${esc(e.label)}</h3>
            <p>${esc(e.sub || '')}</p>
            <div class="price">${money(e.price)}</div>
            ${button}
        </div>`;
    }).join('');
}

function renderCart() {
    cart = cart.filter((id) => entryById(id));
    $('cart-count').textContent = cart.length;
    $('cart-count').classList.toggle('hidden', cart.length === 0);

    $('cart-list').innerHTML = cart.length
        ? cart.map((id) => {
            const e = entryById(id);
            return `<div class="line">
                <div><b>${esc(e.label)}</b><span>${esc(e.actionLabel)} · ${esc(e.sub || '')}</span></div>
                <div class="right"><b>${money(e.price)}</b><button class="remove" data-id="${esc(id)}">Hapus</button></div>
            </div>`;
        }).join('')
        : '<div class="empty">Keranjang masih kosong.</div>';

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
    tab = 'all';
    busy = false;
    $('s-title').textContent = data.label;
    $('s-sub').textContent = data.subtitle || '';
    $('s-logo').textContent = data.office === 'police' ? '👮' : '🏛️';
    setTab($('s-tabs'), 'all');
    document.querySelector('#s-tabs [data-tab="vehicle"]').classList.toggle('hidden', !arr(data.entries).some((e) => e.category === 'vehicle'));
    document.querySelector('#s-tabs [data-tab="redeem"]').classList.toggle('hidden', !data.redeem);

    const banner = data.closed
        ? 'Pelayanan sedang tutup. Kamu bisa melihat layanan, tetapi pengajuan baru bisa dilakukan saat petugas administrasi sudah bertugas.'
        : data.unpaid ? `Tagihan #${data.unpaid} belum dibayar. Bayar lewat Bank di HP sebelum mengajukan lagi.` : '';
    $('s-banner').textContent = banner;
    $('s-banner').classList.toggle('hidden', !banner);
    $('s-banner').classList.toggle('closed', !!data.closed);

    document.querySelector('[data-method="transfer"]').disabled = !data.transfer;
    setMethod('cash');
    showMsg('');
    $('cart').classList.add('hidden');
    renderGrid();
    renderCart();
    $('staff').classList.add('hidden');
    $('services').classList.remove('hidden');
}

$('s-tabs').addEventListener('click', (e) => {
    const b = e.target.closest('button');
    if (!b) return;
    tab = b.dataset.tab;
    setTab($('s-tabs'), tab);
    renderGrid();
});

$('grid').addEventListener('click', (e) => {
    const b = e.target.closest('.add');
    if (!b) return;
    const id = b.dataset.id;
    if (cart.includes(id)) cart = cart.filter((x) => x !== id);
    else if (cart.length >= (S.maxCart || 6)) return showMsg('Keranjang penuh.');
    else cart.push(id);
    renderGrid();
    renderCart();
    $('cart-btn').animate([{ transform: 'scale(1.2)' }, { transform: 'scale(1)' }], { duration: 200 });
});

$('cart-list').addEventListener('click', (e) => {
    const rm = e.target.closest('.remove');
    if (!rm) return;
    cart = cart.filter((x) => x !== rm.dataset.id);
    renderGrid();
    renderCart();
});

$('cart-btn').addEventListener('click', () => $('cart').classList.toggle('hidden'));
$('cart-close').addEventListener('click', () => $('cart').classList.add('hidden'));
document.querySelector('.methods').addEventListener('click', (e) => {
    const b = e.target.closest('button');
    if (b && !b.disabled) setMethod(b.dataset.method);
});

$('order-btn').addEventListener('click', async () => {
    if (busy || !cart.length) return;
    busy = true;
    showMsg('');
    renderCart();
    const res = await post('order', { office: S.office, ids: cart, method });
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
                <span class="chip ${r.online ? 'ok' : 'no'}">${r.online ? 'ONLINE' : 'OFFLINE'}</span>
                <span class="chip ${r.near ? 'ok' : 'info'}">${r.near ? 'DI DEKATMU' : 'TIDAK DI DEKATMU'}</span>
            </div>
            <div class="actions">
                <button class="approve" ${r.near ? '' : 'disabled'} title="${r.near ? '' : 'Pemohon harus berdiri di dekatmu'}">Approve</button>
                <button class="reject">Reject</button>
            </div>
            <div class="reject-box hidden">
                <input maxlength="150" placeholder="Alasan penolakan (dikirim ke email pemohon)">
                <div class="actions"><button class="reject confirm">Tolak &amp; Refund</button><button class="pill cancel">Batal</button></div>
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
    $('t-prices').innerHTML = arr(list).map((p) => `
        <div class="price-row" data-key="${esc(p.key)}">
            <div><b>${esc(p.label)}</b><small>Default ${p.percent ? p.default + '%' : money(p.default)} · batas ${p.percent ? `${p.min}% - ${p.max}%` : `${money(p.min)} - ${money(p.max)}`}${p.note ? ' · ' + esc(p.note) : ''}</small></div>
            <input type="number" step="${p.percent ? '0.1' : '1'}" min="${p.min}" max="${p.max}" value="${p.value}">
            <button class="save">Simpan</button>
        </div>`).join('');
}

/* ---- tab Tilang (khusus kantor polisi) ---- */
let K = null;           // { tickets, canManage }
let ticketFilter = 'all';

const KIND_ICON = { sim: '🚗', stnk: '📄', vehicle: '🚙', fine: '🧾' };

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
            <div class="doc">${KIND_ICON[t.kind] || ''} ${esc(t.condition)}<span>${esc(t.detail || '')}</span></div>
            <div class="phone">
                <span>📞 <b>${esc(t.phone || 'Tidak ada nomor')}</b></span>
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
    $('services').classList.add('hidden');
    $('staff').classList.remove('hidden');
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

/* ---------------- GLOBAL ---------------- */
function closeAll() {
    $('services').classList.add('hidden');
    $('staff').classList.add('hidden');
}

document.querySelectorAll('[data-close]').forEach((b) => b.addEventListener('click', () => post('close')));
document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    if (!$('services').classList.contains('hidden') && !$('cart').classList.contains('hidden')) return $('cart').classList.add('hidden');
    post('close');
});

window.addEventListener('message', ({ data }) => {
    switch (data.action) {
        case 'openServices': return openServices(data.data);
        case 'openStaff': return openStaff(data.data);
        case 'staffData': return updateStaff(data.data);
        case 'close': return closeAll();
    }
});
