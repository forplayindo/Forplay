const $ = (id) => document.getElementById(id);
const resource = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'f_petshop';
const rp = (n) => 'Rp ' + Number(n || 0).toLocaleString('id-ID');
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

function post(name, data) {
    return fetch(`https://${resource}/${name}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json; charset=UTF-8' },
        body: JSON.stringify(data || {}),
    }).then((r) => r.json()).catch(() => null);
}

// coba gambar satu per satu (html/pets/<model>.png/.webp/.jpg -> gambar di config) lalu emoji
window.petImgFallback = (img) => {
    const list = JSON.parse(img.dataset.list || '[]');
    const next = Number(img.dataset.i || 0) + 1;
    if (next < list.length) {
        img.dataset.i = next;
        if (/^https?:/.test(list[next])) img.classList.add('alt');
        img.src = list[next];
        return;
    }
    const span = document.createElement('span');
    span.className = 'emoji';
    span.textContent = img.dataset.icon || '🐾';
    img.replaceWith(span);
};

/* ------------------------------------------------------------------ toko */
const shop = { pets: [], food: [], info: {}, tab: 'pets', nameMax: 20, pick: null, method: 'cash' };

function renderWallet() {
    $('wallet').innerHTML = `Cash <b>${rp(shop.info.cash)}</b><br>Bank <b>${rp(shop.info.bank)}</b>`;
    $('shop-sub').textContent = `Hewan dimiliki: ${shop.info.owned}/${shop.info.max}`;
}

function renderGrid() {
    const grid = $('grid');
    const full = shop.info.owned >= shop.info.max;
    let html = '';
    if (shop.tab === 'pets') {
        if (full) html += `<div class="banner" style="grid-column:1/-1;margin:0">Kamu sudah punya ${shop.info.max} hewan (maksimal).</div>`;
        html += shop.pets.map((p) => `
            <div class="card">
                <div class="img">${(p.photos || []).length
                    ? `<img src="${esc(p.photos[0])}" data-i="0" data-list='${esc(JSON.stringify(p.photos))}' data-icon="${esc(p.icon || '🐾')}" onerror="petImgFallback(this)">`
                    : `<span class="emoji">${esc(p.icon || '🐾')}</span>`}</div>
                <h3>${esc(p.label)}</h3>
                <span class="price">${rp(p.price)}</span>
                <button class="add" data-pet="${esc(p.id)}" ${full ? 'disabled' : ''}>Beli</button>
            </div>`).join('');
    } else {
        html += shop.food.map((f) => `
            <div class="card">
                <div class="img">🦴</div>
                <h3>${esc(f.label)}</h3>
                <p>Mengisi rasa lapar +${f.hunger}</p>
                <span class="price">${rp(f.price)}</span>
                <button class="add" data-food="${esc(f.item)}">Beli</button>
            </div>`).join('');
    }
    grid.innerHTML = html || '<div class="empty">Kosong</div>';
}

function openModal(pick) {
    shop.pick = pick;
    const isPet = pick.type === 'pet';
    $('m-icon').textContent = isPet ? (pick.data.icon || '🐾') : '🦴';
    $('m-title').textContent = pick.data.label;
    $('m-price').textContent = rp(pick.data.price) + (isPet ? '' : ' / buah');
    $('m-name-wrap').classList.toggle('hidden', !isPet);
    $('m-qty-wrap').classList.toggle('hidden', isPet);
    $('m-name').value = '';
    $('m-name').maxLength = shop.nameMax;
    $('m-qty').value = 1;
    $('m-msg').classList.add('hidden');
    $('m-buy').disabled = false;
    updateTotal();
    $('modal').classList.remove('hidden');
    if (isPet) setTimeout(() => $('m-name').focus(), 50);
}

function qty() {
    let q = parseInt($('m-qty').value, 10);
    if (!Number.isFinite(q) || q < 1) q = 1;
    if (q > 50) q = 50;
    return q;
}

function updateTotal() {
    if (!shop.pick) return;
    const total = shop.pick.type === 'pet' ? shop.pick.data.price : shop.pick.data.price * qty();
    $('m-total').textContent = rp(total);
}

function showMsg(text) {
    $('m-msg').textContent = text;
    $('m-msg').classList.remove('hidden');
}

async function buy() {
    const p = shop.pick;
    if (!p) return;
    let res;
    $('m-buy').disabled = true;
    if (p.type === 'pet') {
        const name = $('m-name').value.trim();
        if (name.length < 2) { $('m-buy').disabled = false; return showMsg('Isi nama hewan (minimal 2 huruf).'); }
        res = await post('buyPet', { id: p.data.id, name, method: shop.method });
    } else {
        res = await post('buyFood', { item: p.data.item, amount: qty(), method: shop.method });
    }
    $('m-buy').disabled = false;
    if (!res || !res.ok) return showMsg((res && res.msg) || 'Gagal membeli.');
    $('modal').classList.add('hidden');
    if (p.type === 'food') {
        const total = p.data.price * qty();
        if (shop.method === 'cash') shop.info.cash -= total; else shop.info.bank -= total;
        renderWallet();
    }
}

$('shop-tabs').addEventListener('click', (e) => {
    const b = e.target.closest('button[data-tab]');
    if (!b) return;
    shop.tab = b.dataset.tab;
    document.querySelectorAll('#shop-tabs button').forEach((x) => x.classList.toggle('active', x === b));
    renderGrid();
});

$('grid').addEventListener('click', (e) => {
    const b = e.target.closest('button.add');
    if (!b || b.disabled) return;
    if (b.dataset.pet) openModal({ type: 'pet', data: shop.pets.find((p) => p.id === b.dataset.pet) });
    if (b.dataset.food) openModal({ type: 'food', data: shop.food.find((f) => f.item === b.dataset.food) });
});

document.querySelectorAll('.methods button').forEach((b) => b.addEventListener('click', () => {
    shop.method = b.dataset.method;
    document.querySelectorAll('.methods button').forEach((x) => x.classList.toggle('active', x === b));
}));
document.querySelectorAll('.qty button').forEach((b) => b.addEventListener('click', () => {
    $('m-qty').value = Math.min(50, Math.max(1, qty() + parseInt(b.dataset.q, 10)));
    updateTotal();
}));
$('m-qty').addEventListener('input', updateTotal);
$('m-cancel').addEventListener('click', () => $('modal').classList.add('hidden'));
$('m-buy').addEventListener('click', buy);
$('m-name').addEventListener('keydown', (e) => { if (e.key === 'Enter') buy(); });

/* ---------------------------------------------------------- panel kontrol */
const MODES = { follow: 'Mengikuti', stay: 'Diam', sit: 'Duduk', lay: 'Rebahan', vehicle: 'Di kendaraan', idle: 'Diam' };

function bar(label, value, color) {
    const v = Math.max(0, Math.min(100, value | 0));
    return `<div class="bar"><span>${label}</span><div class="track"><div class="fill" style="width:${v}%;background:${color}"></div></div><span>${v}%</span></div>`;
}

let selected = 'all'; // 'all' atau id hewan aktif

function petStatus(p) {
    const hungerColor = p.hunger <= 20 ? 'var(--red)' : 'var(--gold)';
    return `
        <div class="pet-row">
            <span class="pet-ico">${esc(p.icon)}</span>
            <div><b>${esc(p.name)}</b><small>${esc(p.breed)} · ${p.dead ? (p.carried ? 'Digendong' : 'Mati') : (p.inVehicle ? 'Di kendaraan' : MODES[p.mode] || 'Diam')}</small></div>
            <span class="chip ${p.dead ? 'no' : 'ok'}">${p.dead ? 'MATI' : 'AKTIF'}</span>
        </div>
        <div class="bars">${bar('Kenyang', p.hunger, hungerColor)}${bar('Nyawa', p.health, 'var(--green)')}</div>`;
}

function renderPanel(d) {
    const active = d.pets.filter((p) => p.active);
    if (selected !== 'all' && !active.some((p) => String(p.id) === String(selected))) selected = 'all';
    const box = $('active');

    if (active.length) {
        box.classList.remove('hidden');

        // pilihan: Semua + tiap hewan yang dipanggil
        $('select').innerHTML = (active.length > 1 ? `<button data-sel="all" class="${selected === 'all' ? 'on' : ''}">Semua (${active.length})</button>` : '')
            + active.map((p) => `<button data-sel="${p.id}" class="${p.dead ? 'dead' : ''} ${String(selected) === String(p.id) || (active.length === 1) ? 'on' : ''}">${esc(p.icon)} ${esc(p.name)}</button>`).join('');
        if (active.length === 1) selected = active[0].id;

        const sel = selected === 'all' ? active : active.filter((p) => String(p.id) === String(selected));
        $('status').innerHTML = sel.length === 1 ? petStatus(sel[0])
            : `<div class="status-list">${sel.map((p) => `<div class="pet-row"><span class="pet-ico">${esc(p.icon)}</span><div><b>${esc(p.name)}</b><small>${p.dead ? '<span style="color:var(--red)">Mati</span>' : `${MODES[p.mode] || 'Diam'} · Kenyang ${p.hunger}%`}</small></div></div>`).join('')}</div>`;

        const one = sel.length === 1 ? sel[0] : null;
        if (one && one.dead) {
            $('cmds').innerHTML = `
                <div class="hint">${esc(one.name)} mati. ${one.canCarry ? 'Gendong ke rumah sakit' : 'Terlalu besar untuk digendong, panggil EMS ke lokasi'} lalu minta petugas EMS menyembuhkannya.</div>
                <div class="cmds">
                    ${one.canCarry ? `<button class="cmd wide ${one.carried ? 'on' : ''}" data-cmd="carry"><span>🤲</span>${one.carried ? 'Turunkan' : 'Gendong'}</button>` : ''}
                    <button class="cmd wide danger" data-cmd="dismiss"><span>🏠</span>Pulangkan</button>
                </div>`;
        } else {
            const alive = sel.filter((p) => !p.dead);
            const m = one ? one.mode : (alive.every((p) => p.mode === alive[0]?.mode) ? alive[0]?.mode : null);
            const inVeh = alive.some((p) => p.inVehicle);
            $('cmds').innerHTML = `
                <div class="cmds">
                    <button class="cmd ${m === 'follow' ? 'on' : ''}" data-cmd="follow"><span>🐾</span>Ikuti</button>
                    <button class="cmd ${m === 'stay' ? 'on' : ''}" data-cmd="stay"><span>✋</span>Diam</button>
                    <button class="cmd ${m === 'sit' ? 'on' : ''}" data-cmd="sit"><span>🪑</span>Duduk</button>
                    <button class="cmd ${m === 'lay' ? 'on' : ''}" data-cmd="lay"><span>💤</span>Rebahan</button>
                    <button class="cmd ${inVeh ? 'on' : ''}" data-cmd="${inVeh ? 'exit' : 'enter'}"><span>🚗</span>${inVeh ? 'Turun Mobil' : 'Naik Mobil'}</button>
                    <button class="cmd danger" data-cmd="dismiss"><span>🏠</span>${selected === 'all' && active.length > 1 ? 'Pulangkan Semua' : 'Pulangkan'}</button>
                </div>`;
        }
    } else {
        box.classList.add('hidden');
    }

    const idle = d.pets.filter((p) => !p.active);
    const all = $('summon-all');
    all.classList.toggle('hidden', idle.length < 2);
    all.disabled = false;
    all.textContent = 'Panggil semua';
    $('pet-list').innerHTML = idle.length ? idle.map((p) => `
        <div class="pet-item">
            <span class="pet-ico">${esc(p.icon)}</span>
            <div class="info"><b>${esc(p.name)}</b><small>${esc(p.breed)}${p.dead ? ' · <span style="color:var(--red)">Mati</span>' : ` · Kenyang ${p.hunger}%`}</small></div>
            <button class="release" data-release="${p.id}" title="Hapus hewan ini permanen">Lepas</button>
            <button data-summon="${p.id}">Panggil</button>
        </div>`).join('')
        : `<div class="empty">${d.pets.length ? 'Semua hewanmu sudah dipanggil.' : 'Belum punya hewan.<small>Beli di Toko Hewan.</small>'}</div>`;
}

$('select').addEventListener('click', (e) => {
    const b = e.target.closest('button[data-sel]');
    if (!b) return;
    selected = b.dataset.sel === 'all' ? 'all' : b.dataset.sel;
    if (lastPanel) renderPanel(lastPanel);
});

$('cmds').addEventListener('click', async (e) => {
    const b = e.target.closest('button[data-cmd]');
    if (!b) return;
    const d = await post('command', { cmd: b.dataset.cmd, target: selected });
    if (d) { lastPanel = d; renderPanel(d); }
});

async function summon(id, btn) {
    if (btn) { btn.disabled = true; btn.textContent = '...'; }
    const d = await post('summon', { id });
    if (d) { lastPanel = d; renderPanel(d); }
}

$('pet-list').addEventListener('click', async (e) => {
    const b = e.target.closest('button[data-summon]');
    if (b && !b.disabled) return summon(b.dataset.summon, b);

    // lepas: klik pertama minta konfirmasi, klik kedua (dalam 4 detik) menghapus
    const r = e.target.closest('button[data-release]');
    if (!r || r.disabled) return;
    if (!r.classList.contains('armed')) {
        r.classList.add('armed');
        r.textContent = 'Yakin?';
        setTimeout(() => { if (r.isConnected) { r.classList.remove('armed'); r.textContent = 'Lepas'; } }, 4000);
        return;
    }
    r.disabled = true;
    r.textContent = '...';
    const d = await post('release', { id: r.dataset.release });
    if (d) { lastPanel = d; renderPanel(d); }
});
$('summon-all').addEventListener('click', (e) => summon('all', e.currentTarget));

let lastPanel = null;

/* ------------------------------------------------------------- umum */
function closeAll() {
    $('shop').classList.add('hidden');
    $('modal').classList.add('hidden');
    $('ctl').classList.add('hidden');
}

document.querySelectorAll('[data-close]').forEach((b) => b.addEventListener('click', () => post('close')));
document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape') return;
    if (!$('modal').classList.contains('hidden')) return $('modal').classList.add('hidden');
    post('close');
});

window.addEventListener('message', (e) => {
    const { action, data } = e.data || {};
    if (action === 'openShop') {
        Object.assign(shop, { pets: data.pets, food: data.food, info: data.info, nameMax: data.nameMax, tab: 'pets', method: 'cash' });
        $('shop-title').textContent = data.title;
        document.querySelectorAll('#shop-tabs button').forEach((x) => x.classList.toggle('active', x.dataset.tab === 'pets'));
        document.querySelectorAll('.methods button').forEach((x) => x.classList.toggle('active', x.dataset.method === 'cash'));
        renderWallet();
        renderGrid();
        $('shop').classList.remove('hidden');
    } else if (action === 'openPanel') {
        selected = 'all';
        lastPanel = data;
        renderPanel(data);
        $('ctl').classList.remove('hidden');
    } else if (action === 'panelData') {
        lastPanel = data;
        renderPanel(data);
    } else if (action === 'close') {
        closeAll();
    }
});
