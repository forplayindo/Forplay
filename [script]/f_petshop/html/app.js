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

/* ------------------------------------------------------------------ toko */
// sel = id hewan / item makanan yang sedang dipilih; hewan terpilih tampil 3D di tengah layar
const shop = { pets: [], food: [], info: {}, tab: 'pets', nameMax: 20, sel: null, variant: 0, method: 'cash' };

const selPet = () => shop.pets.find((p) => p.id === shop.sel);
const selFood = () => shop.food.find((f) => f.item === shop.sel);

function renderWallet() {
    $('wallet').innerHTML = `<span>Cash <b>${rp(shop.info.cash)}</b></span><span>Bank <b>${rp(shop.info.bank)}</b></span>`;
    $('shop-sub').textContent = `Hewan dimiliki: ${shop.info.owned}/${shop.info.max}`;
}

function row(key, icon, title, sub, price) {
    return `<button class="row ${shop.sel === key ? 'sel' : ''}" data-key="${esc(key)}">
        <span class="sq">${esc(icon)}</span>
        <div class="t"><b>${esc(title)}</b><small class="t-muted">${esc(sub)}</small></div>
        ${price != null ? `<span class="d">${rp(price)}</span>` : ''}
    </button>`;
}

const mmss = (sec) => `${Math.floor(sec / 60)}:${String(sec % 60).padStart(2, '0')}`;

// status masa coba & pengajuan di atas daftar hewan
function statusBanners() {
    let html = '';
    const t = shop.info.trial;
    if (t) {
        const left = Math.max(0, Math.round((shop.trialEnds - Date.now()) / 1000));
        html += `<div class="banner st"><span>Sedang mencoba <b>${esc(t.label)}</b> · sisa <b id="trial-left">${mmss(left)}</b></span>
            <button class="b b-sm b-tinted" data-st="return">Kembalikan</button></div>`;
    }
    const r = shop.info.pending;
    if (r) {
        html += `<div class="banner st warn"><span>Pengajuan <b>${esc(r.name)}</b> (${esc(r.label)}) menunggu persetujuan admin</span>
            <button class="b b-sm b-red-tint" data-st="cancel">Batalkan</button></div>`;
    }
    if (shop.info.owned >= shop.info.max) html += `<div class="banner">Kamu sudah punya ${shop.info.max} hewan (maksimal).</div>`;
    return html;
}

// gambar ulang daftar tanpa membuat posisi scroll lompat ke atas
function renderList() {
    const top = $('list').scrollTop;
    renderListInner();
    $('list').scrollTop = top;
}

function renderListInner() {
    if (shop.tab === 'acc') return renderAccList();
    let html = '';
    if (shop.tab === 'pets') {
        html += statusBanners();
        const groups = [];
        shop.pets.forEach((p) => {
            let g = groups.find((x) => x.name === p.group);
            if (!g) groups.push(g = { name: p.group, pets: [] });
            g.pets.push(p);
        });
        html += groups.map((g) => `<div><div class="group-h">${esc(g.name)}</div><div class="group icons">${
            g.pets.map((p) => row(p.id, p.icon || '🐾', p.label, p.variants ? `${p.variants.length} warna` : '1 warna', null)).join('')
        }</div></div>`).join('');
    } else {
        html += `<div class="group icons">${shop.food.map((f) => row(f.item, f.icon, f.label, f.desc, f.price)).join('')}</div>`;
    }
    $('list').innerHTML = html || '<div class="empty">Kosong</div>';
}

function renderDetail() {
    // tampilan detail dikembalikan (tab Aksesoris menyembunyikan sebagian)
    document.querySelector('#detail .methods').classList.toggle('hidden', shop.tab === 'pets');
    document.querySelector('#detail .total').classList.toggle('hidden', shop.tab === 'pets');
    $('d-trial').classList.toggle('hidden', shop.tab !== 'pets');
    if (shop.tab === 'acc') return renderAccDetail();
    const pet = shop.tab === 'pets' ? selPet() : null;
    const food = shop.tab === 'food' ? selFood() : null;
    const item = pet || food;
    $('detail').classList.toggle('hidden', !item);
    if (!item) return;

    $('d-icon').textContent = pet ? (pet.icon || '🐾') : food.icon;
    $('d-title').textContent = item.label;
    $('d-sub').textContent = pet ? pet.group : food.desc;
    $('d-price').textContent = pet ? 'Gratis' : rp(item.price);

    const variants = pet && pet.variants;
    $('d-variants-wrap').classList.toggle('hidden', !variants || variants.length < 2);
    $('d-variants').innerHTML = variants ? variants.map((v, i) =>
        `<button data-variant="${i}" class="${i === shop.variant ? 'active' : ''}">${esc(v)}</button>`).join('') : '';

    $('d-name-wrap').classList.toggle('hidden', !pet);
    $('d-qty-wrap').classList.toggle('hidden', !food);
    $('d-name').maxLength = shop.nameMax;

    if (pet) {
        // hewan tidak dibeli: coba dulu, lalu ajukan kepemilikan ke admin
        const full = shop.info.owned >= shop.info.max;
        $('d-trial').disabled = !!shop.info.trial;
        $('d-trial').textContent = shop.info.trial ? 'Kembalikan hewan coba dulu' : 'Coba 5 Menit';
        $('d-buy').disabled = full || !!shop.info.pending;
        $('d-buy').textContent = full ? 'Jumlah hewan maksimal' : shop.info.pending ? 'Masih ada pengajuan' : 'Ajukan Kepemilikan';
    } else {
        $('d-buy').disabled = false;
        $('d-buy').textContent = 'Beli';
    }
    updateTotal();
}

function select(key) {
    if (shop.sel === key) return;
    shop.sel = key;
    shop.variant = 0;
    $('d-name').value = '';
    $('d-qty').value = 1;
    $('d-msg').classList.add('hidden');
    renderList();
    renderDetail();
    if (shop.tab === 'pets') post('preview', { id: key, variant: 0 });
}

function qty() {
    let q = parseInt($('d-qty').value, 10);
    if (!Number.isFinite(q) || q < 1) q = 1;
    if (q > 50) q = 50;
    return q;
}

function updateTotal() {
    const pet = shop.tab === 'pets' ? selPet() : null;
    const food = shop.tab === 'food' ? selFood() : null;
    $('d-total').textContent = rp(pet ? 0 : food ? food.price * qty() : 0);
}

function showMsg(text, ok) {
    $('d-msg').textContent = text;
    $('d-msg').classList.toggle('ok', !!ok);
    $('d-msg').classList.remove('hidden');
}

async function buy() {
    if (shop.tab === 'acc') return accAction();
    const pet = shop.tab === 'pets' ? selPet() : null;
    const food = shop.tab === 'food' ? selFood() : null;
    if (!pet && !food) return;
    $('d-buy').disabled = true;
    let res;
    if (pet) {
        const name = $('d-name').value.trim();
        if (name.length < 2) { $('d-buy').disabled = false; return showMsg('Isi nama hewan (minimal 2 huruf).'); }
        res = await post('request', { id: pet.id, name, variant: shop.variant });
        if (res && res.ok) {
            setInfo(res.info);
            return showMsg(res.msg, true);
        }
    } else {
        res = await post('buyFood', { item: food.item, amount: qty(), method: shop.method });
    }
    $('d-buy').disabled = false;
    if (!res || !res.ok) return showMsg((res && res.msg) || 'Gagal membeli.');
    if (food) {
        const total = food.price * qty();
        if (shop.method === 'cash') shop.info.cash -= total; else shop.info.bank -= total;
        renderWallet();
        showMsg(res.msg, true);
    }
}

// info toko baru dari server (setelah coba / kembalikan / ajukan / batalkan)
function setInfo(info) {
    if (!info) return;
    shop.info = info;
    shop.trialEnds = Date.now() + ((info.trial && info.trial.left) || 0) * 1000;
    renderWallet();
    renderList();
    renderDetail();
}

$('d-trial').addEventListener('click', async () => {
    const pet = selPet();
    if (!pet || shop.info.trial) return;
    $('d-trial').disabled = true;
    const res = await post('trial', { id: pet.id, variant: shop.variant });
    $('d-trial').disabled = false;
    if (!res || !res.ok) showMsg((res && res.msg) || 'Gagal.');
});

$('list').addEventListener('click', async (e) => {
    const b = e.target.closest('button[data-st]');
    if (!b) return;
    e.stopPropagation();
    b.disabled = true;
    setInfo(await post(b.dataset.st === 'return' ? 'trialReturn' : 'requestCancel'));
});

// hitung mundur masa coba di banner
setInterval(() => {
    const el = $('trial-left');
    if (el && shop.info.trial) el.textContent = mmss(Math.max(0, Math.round((shop.trialEnds - Date.now()) / 1000)));
}, 1000);

$('shop-tabs').addEventListener('click', (e) => {
    const b = e.target.closest('button[data-tab]');
    if (!b || b.dataset.tab === shop.tab) return;
    shop.tab = b.dataset.tab;
    document.querySelectorAll('#shop-tabs button').forEach((x) => x.classList.toggle('active', x === b));
    // hewan terakhir tetap tampil di tengah; detail mengikuti tab yang aktif
    shop.sel = null;
    if (shop.tab === 'acc') return loadAcc();
    renderList();
    renderDetail();
});

$('list').addEventListener('click', (e) => {
    if (shop.tab === 'acc') return accClick(e);
    const b = e.target.closest('button[data-key]');
    if (b) select(b.dataset.key);
});

$('d-variants').addEventListener('click', (e) => {
    const b = e.target.closest('button[data-variant]');
    if (!b) return;
    shop.variant = Number(b.dataset.variant);
    document.querySelectorAll('#d-variants button').forEach((x) => x.classList.toggle('active', x === b));
    post('preview', { id: shop.sel, variant: shop.variant });
});

document.querySelectorAll('.methods button').forEach((b) => b.addEventListener('click', () => {
    shop.method = b.dataset.method;
    document.querySelectorAll('.methods button').forEach((x) => x.classList.toggle('active', x === b));
}));
document.querySelectorAll('.qty button').forEach((b) => b.addEventListener('click', () => {
    $('d-qty').value = Math.min(50, Math.max(1, qty() + parseInt(b.dataset.q, 10)));
    updateTotal();
}));
$('d-qty').addEventListener('input', updateTotal);
$('d-buy').addEventListener('click', buy);
$('d-name').addEventListener('keydown', (e) => { if (e.key === 'Enter') buy(); });

/* ------------------------------------------------------- toko: aksesoris */
// accPet = id hewan milik sendiri yang sedang didandani; accSel = { slot, value } yang dipilih;
// trial = aksesoris yang ditampilkan di preview (yang dipakai + yang sedang dicoba)
const acc = { pets: [], accPet: null, accSel: null, trial: {}, collarCount: 0, catalog: null };

const accPetData = () => acc.pets.find((p) => p.id === acc.accPet);
const accItem = (prop) => acc.catalog.items.find((a) => a.prop === prop);
const slotOf = (id) => acc.catalog.slots.find((s) => s.id === id);
const sameVal = (a, b) => a !== undefined && a !== null && String(a) === String(b);

function accOwned(p, slot, value) {
    return slot === 'collar' ? !!(p.collars && p.collars[String(value)]) : !!(p.owned && p.owned[value]);
}

function accLabel(slot, value) {
    return slot === 'collar' ? `Kalung ${acc.catalog.colors[value]}` : (accItem(value) || {}).label || value;
}

function accPrice(slot, value) {
    return slot === 'collar' ? slotOf('collar').price : (accItem(value) || {}).price || 0;
}

function accPreview() {
    if (acc.accPet != null) post('previewAcc', { pet: acc.accPet, worn: acc.trial });
}

function pickAccPet(id) {
    acc.accPet = id;
    acc.accSel = null;
    const p = accPetData();
    acc.trial = Object.assign({}, p ? p.worn : {});
    acc.collarCount = 0; // diisi lagi oleh previewInfo setelah model tampil
    renderList();
    renderDetail();
    accPreview();
}

async function loadAcc() {
    $('list').innerHTML = '<div class="empty">Memuat...</div>';
    acc.pets = (await post('accPets')) || [];
    if (shop.tab !== 'acc') return;
    pickAccPet(acc.pets.some((p) => p.id === acc.accPet) ? acc.accPet : (acc.pets[0] && acc.pets[0].id));
}

function accRow(p, slot, value, label) {
    const worn = sameVal(p.worn[slot], value);
    const owned = accOwned(p, slot, value);
    const sel = acc.accSel && acc.accSel.slot === slot && sameVal(acc.accSel.value, value);
    const right = worn ? '<span class="chip ok">Dipakai</span>' : owned ? '<span class="chip">Dimiliki</span>' : `<span class="d">${rp(accPrice(slot, value))}</span>`;
    return `<button class="row ${sel ? 'sel' : ''}" data-slot="${esc(slot)}" data-value="${esc(value)}">
        <div class="t"><b>${esc(label)}</b></div>${right}
    </button>`;
}

function renderAccList() {
    if (!acc.pets.length) {
        $('list').innerHTML = '<div class="empty">Belum punya hewan.<small>Beli hewan dulu di tab Hewan.</small></div>';
        return;
    }
    const p = accPetData();
    let html = `<div class="filters" id="acc-pets">${acc.pets.map((x) =>
        `<button data-accpet="${x.id}" class="${x.id === acc.accPet ? 'active' : ''}">${esc(x.icon)} ${esc(x.name)}</button>`).join('')}</div>`;

    const groups = acc.catalog.slots.map((s) => {
        let rows = '';
        if (s.id === 'collar') {
            if (p.collar) for (let i = 0; i < acc.collarCount; i++) rows += accRow(p, 'collar', i, `Kalung ${acc.catalog.colors[i]}`);
        } else {
            rows = p.items.map(accItem).filter((a) => a && a.slot === s.id).map((a) => accRow(p, s.id, a.prop, a.label)).join('');
        }
        return rows ? `<div><div class="group-h">${esc(s.label)}</div><div class="group">${rows}</div></div>` : '';
    }).join('');
    html += groups || `<div class="empty">Belum ada aksesoris yang pas untuk ${esc(p.breed)}.<small>Admin bisa menyetelnya dengan /petfit.</small></div>`;
    $('list').innerHTML = html;
}

function renderAccDetail() {
    const p = accPetData();
    const s = acc.accSel;
    $('detail').classList.toggle('hidden', !p || !s);
    if (!p || !s) return;
    const worn = sameVal(p.worn[s.slot], s.value);
    const owned = accOwned(p, s.slot, s.value);

    $('d-icon').textContent = p.icon;
    $('d-title').textContent = accLabel(s.slot, s.value);
    $('d-sub').textContent = `${slotOf(s.slot).label} · untuk ${p.name}`;
    $('d-price').textContent = owned ? 'Dimiliki' : rp(accPrice(s.slot, s.value));
    $('d-variants-wrap').classList.add('hidden');
    $('d-name-wrap').classList.add('hidden');
    $('d-qty-wrap').classList.add('hidden');
    document.querySelector('#detail .methods').classList.toggle('hidden', owned);
    document.querySelector('#detail .total').classList.toggle('hidden', owned);
    $('d-total').textContent = rp(accPrice(s.slot, s.value));
    $('d-buy').disabled = false;
    $('d-buy').textContent = worn ? 'Lepas' : owned ? 'Pakai' : 'Beli & Pakai';
}

function accUpdate(res) {
    const p = accPetData();
    if (!p || !res) return;
    p.owned = res.owned || {};
    p.collars = res.collars || {};
    p.worn = res.worn || {};
    acc.trial = Object.assign({}, p.worn);
    renderList();
    renderDetail();
    accPreview();
}

async function accAction() {
    const p = accPetData();
    const s = acc.accSel;
    if (!p || !s) return;
    $('d-buy').disabled = true;
    let res;
    if (sameVal(p.worn[s.slot], s.value)) {
        res = await post('wearAcc', { pet: p.id, slot: s.slot, value: null });
    } else if (accOwned(p, s.slot, s.value)) {
        res = await post('wearAcc', { pet: p.id, slot: s.slot, value: s.value });
    } else {
        res = await post('buyAcc', { pet: p.id, slot: s.slot, value: s.value, method: shop.method });
        if (res && res.ok) {
            const price = accPrice(s.slot, s.value);
            if (shop.method === 'cash') shop.info.cash -= price; else shop.info.bank -= price;
            renderWallet();
        }
    }
    $('d-buy').disabled = false;
    if (!res || !res.ok) return showMsg((res && res.msg) || 'Gagal.');
    $('d-msg').classList.add('hidden');
    accUpdate(res);
}

function accClick(e) {
    const pb = e.target.closest('button[data-accpet]');
    if (pb) return pickAccPet(Number(pb.dataset.accpet));
    const b = e.target.closest('button[data-slot]');
    if (!b) return;
    const slot = b.dataset.slot;
    const value = slot === 'collar' ? Number(b.dataset.value) : b.dataset.value;
    acc.accSel = { slot, value };
    // coba di preview: aksesoris yang dipakai + yang dipilih
    acc.trial = Object.assign({}, accPetData().worn, { [slot]: value });
    $('d-msg').classList.add('hidden');
    renderList();
    renderDetail();
    accPreview();
}

// putar hewan: seret di area kosong; zoom: scroll. Kirim maksimal ~25x per detik.
let dragX = null, pendingDx = 0, rotTimer = null;
$('stage').addEventListener('mousedown', (e) => { dragX = e.clientX; $('stage').classList.add('drag'); });
window.addEventListener('mouseup', () => { dragX = null; $('stage').classList.remove('drag'); });
window.addEventListener('mousemove', (e) => {
    if (dragX === null) return;
    pendingDx += e.clientX - dragX;
    dragX = e.clientX;
    if (rotTimer) return;
    rotTimer = setTimeout(() => {
        rotTimer = null;
        const dx = pendingDx;
        pendingDx = 0;
        if (dx) post('rotate', { dx });
    }, 40);
});
$('stage').addEventListener('wheel', (e) => post('zoom', { dir: e.deltaY > 0 ? 1 : -1 }), { passive: true });

/* ---------------------------------------------------------- panel kontrol */
const MODES = {
    follow: 'Mengikuti', stay: 'Diam', sit: 'Duduk', lay: 'Rebahan', vehicle: 'Di kendaraan', idle: 'Diam',
    trick: 'Main trik', fetch: 'Main bola', petted: 'Dielus', boarding: 'Naik/turun mobil',
    attack: 'Menyerang', guard: 'Menjaga area',
};

function bar(label, value, color) {
    const v = Math.max(0, Math.min(100, value | 0));
    return `<div class="bar"><span>${label}</span><div class="track"><div class="fill" style="width:${v}%;background:${color}"></div></div><span>${v}%</span></div>`;
}

let selected = 'all'; // 'all' atau id hewan aktif

function petStatus(p) {
    const hungerColor = p.hunger <= 20 ? 'var(--red)' : 'var(--gold)';
    const thirstColor = p.thirst <= 20 ? 'var(--red)' : 'var(--blue)';
    return `
        <div class="pet-row">
            <span class="pet-ico">${esc(p.icon)}</span>
            <div><b>${esc(p.name)}</b><small>${p.trial ? `<span class="t-accent">Coba · sisa ${mmss(p.left || 0)}</span>` : esc(p.breed)} · ${p.dead ? (p.carried ? 'Digendong' : 'Mati') : (p.inVehicle ? 'Di kendaraan' : MODES[p.mode] || 'Diam')}</small></div>
            <span class="chip ${p.dead ? 'no' : 'ok'}">${p.dead ? 'Mati' : 'Aktif'}</span>
        </div>
        <div class="bars">${bar('Kenyang', p.hunger, hungerColor)}${bar('Minum', p.thirst, thirstColor)}${bar('Nyawa', p.health, 'var(--green)')}</div>`;
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
            : `<div class="status-list">${sel.map((p) => `<div class="pet-row"><span class="pet-ico">${esc(p.icon)}</span><div><b>${esc(p.name)}</b><small>${p.dead ? '<span style="color:var(--red)">Mati</span>' : `${MODES[p.mode] || 'Diam'} · 🍖 ${p.hunger}% · 💧 ${p.thirst}%`}</small></div></div>`).join('')}</div>`;

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
            // naik/turun mobil otomatis mengikuti pemilik; "Ikuti" juga menurunkan hewan dari mobil
            const tricks = one && !one.inVehicle && one.tricks && one.tricks.length ? one.tricks : null;
            $('cmds').innerHTML = `
                <div class="cmds">
                    <button class="cmd ${m === 'follow' ? 'on' : ''}" data-cmd="follow"><span>🐾</span>Ikuti</button>
                    <button class="cmd ${m === 'stay' ? 'on' : ''}" data-cmd="stay"><span>✋</span>Diam</button>
                    <button class="cmd ${m === 'sit' ? 'on' : ''}" data-cmd="sit"><span>🪑</span>Duduk</button>
                    <button class="cmd ${m === 'lay' ? 'on' : ''}" data-cmd="lay"><span>💤</span>Rebahan</button>
                    ${one && one.canLeash ? `<button class="cmd ${one.leash ? 'on' : ''}" data-cmd="leash"><span>🦮</span>${one.leash ? 'Lepas Tali' : 'Pasang Tali'}</button>` : ''}
                    <button class="cmd ${one && one.canLeash ? '' : 'span2'} danger" data-cmd="dismiss"><span>🏠</span>${selected === 'all' && active.length > 1 ? 'Pulangkan Semua' : one && one.trial ? 'Kembalikan' : 'Pulangkan'}</button>
                </div>
                ${one && one.canFight && !one.inVehicle ? `<span class="side-label">Pertahanan</span>
                <div class="cmds two">
                    <button class="cmd ${one.mode === 'attack' ? 'on' : ''}" data-cmd="attack"><span>⚔️</span>Serang</button>
                    <button class="cmd ${one.guarding ? 'on' : ''}" data-cmd="guard"><span>🛡️</span>${one.guarding ? 'Berhenti Jaga' : 'Jaga Area'}</button>
                </div>` : ''}
                ${tricks ? `<span class="side-label">Trik</span>
                <div class="cmds">${tricks.map((t) => `<button class="cmd" data-trick="${esc(t.id)}" data-pet="${one.id}"><span>${esc(t.icon)}</span>${esc(t.label)}</button>`).join('')}</div>` : ''}`;
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
            <div class="info"><b>${esc(p.name)}</b><small>${esc(p.breed)}${p.dead ? ' · <span style="color:var(--red)">Mati</span>' : ` · 🍖 ${p.hunger}% · 💧 ${p.thirst}%`}</small></div>
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
    const t = e.target.closest('button[data-trick]');
    if (t) {
        const d = await post('trick', { id: t.dataset.pet, trick: t.dataset.trick });
        if (d) { lastPanel = d; renderPanel(d); }
        return;
    }
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

/* ------------------------------------------------------------ daftar teman */
function showFriends(on) {
    $('main-view').classList.toggle('hidden', on);
    $('friends').classList.toggle('hidden', !on);
}

function renderFriends(d) {
    const keep = $('friends').scrollTop;
    $('f-jobs').innerHTML = (d.jobs || []).map((j) => `
        <div class="row"><div class="t">${esc(j.label)}</div>
            <button class="switch ${j.on ? 'on' : ''}" data-job="${esc(j.name)}"></button></div>`).join('')
        || '<div class="row"><span class="none">Tidak ada job yang bisa dipilih.</span></div>';
    $('f-players').innerHTML = (d.players || []).map((x) => `
        <div class="row"><div class="t">${esc(x.name)}</div>
            <button class="act del" data-remove="${esc(x.cid)}">Hapus</button></div>`).join('')
        || '<div class="row"><span class="none">Belum ada teman.</span></div>';
    $('f-nearby').innerHTML = (d.nearby || []).map((x) => `
        <div class="row"><div class="t">${esc(x.name)}</div>
            <button class="act" data-add="${x.id}">Tambah</button></div>`).join('')
        || '<div class="row"><span class="none">Tidak ada pemain dalam 5 meter.</span></div>';
    $('friends').scrollTop = keep;
}

async function friends(action, value) {
    const d = await post('friends', { action, value });
    if (d) renderFriends(d);
}

$('friends-btn').addEventListener('click', () => { showFriends(true); friends(); });
$('friends-back').addEventListener('click', () => showFriends(false));
$('friends').addEventListener('click', (e) => {
    const j = e.target.closest('[data-job]');
    if (j) return friends('job', j.dataset.job);
    const r = e.target.closest('[data-remove]');
    if (r) return friends('remove', r.dataset.remove);
    const a = e.target.closest('[data-add]');
    if (a) return friends('add', Number(a.dataset.add));
});

/* ------------------------------------------------------- /petfit (admin) */
// values = [x, y, z, rotX, rotY, rotZ, bone]; langkah dasar 0,01 m untuk posisi, 1 derajat untuk rotasi
const fitState = { values: null, step: 1, timer: null };
const FIT_FIELDS = [['X', 0.01], ['Y', 0.01], ['Z', 0.01], ['Rot X', 1], ['Rot Y', 1], ['Rot Z', 1]];

function renderFit() {
    const v = fitState.values;
    if (!v) { $('fit-fields').innerHTML = '<div class="empty">Pilih aksesoris di atas.</div>'; return; }
    $('fit-fields').innerHTML = FIT_FIELDS.map(([label], i) => `
        <div class="fit-row"><span>${label}</span>
            <button data-i="${i}" data-d="-1">−</button>
            <input data-i="${i}" type="number" step="any" value="${i < 3 ? v[i].toFixed(3) : v[i].toFixed(1)}">
            <button data-i="${i}" data-d="1">+</button>
        </div>`).join('') + `
        <div class="fit-row"><span>Bone</span><span></span>
            <input data-i="6" type="number" step="1" value="${v[6]}"><span></span>
        </div>`;
}

// kirim ke game paling cepat tiap 60 ms supaya tombol bisa ditekan beruntun
function sendFit() {
    if (fitState.timer) return;
    fitState.timer = setTimeout(() => {
        fitState.timer = null;
        post('fitUpdate', { values: fitState.values });
    }, 60);
}

$('fit-item').addEventListener('change', async () => {
    const values = await post('fitSelect', { prop: $('fit-item').value });
    fitState.values = Array.isArray(values) ? values.map(Number) : null;
    renderFit();
});

$('fit-fields').addEventListener('click', (e) => {
    const b = e.target.closest('button[data-d]');
    if (!b || !fitState.values) return;
    const i = Number(b.dataset.i);
    const v = fitState.values[i] + Number(b.dataset.d) * FIT_FIELDS[i][1] * fitState.step;
    fitState.values[i] = Math.round(v * 1000) / 1000;
    renderFit();
    sendFit();
});

$('fit-fields').addEventListener('change', (e) => {
    const inp = e.target.closest('input[data-i]');
    if (!inp || !fitState.values) return;
    const n = Number(inp.value);
    if (Number.isFinite(n)) fitState.values[Number(inp.dataset.i)] = n;
    sendFit();
});

$('fit-step').addEventListener('click', (e) => {
    const b = e.target.closest('button[data-step]');
    if (!b) return;
    fitState.step = Number(b.dataset.step);
    document.querySelectorAll('#fit-step button').forEach((x) => x.classList.toggle('active', x === b));
});

$('fit-save').addEventListener('click', async () => {
    if (!fitState.values) return;
    $('fit-save').disabled = true;
    const ok = await post('fitSave');
    $('fit-save').disabled = false;
    if (ok) {
        const opt = $('fit-item').selectedOptions[0];
        if (opt && !opt.textContent.startsWith('✓')) opt.textContent = '✓ ' + opt.textContent;
    }
});

function openFit(d) {
    fitState.values = null;
    $('fit-sub').textContent = `${d.pet} · ${d.model}`;
    $('fit-item').innerHTML = '<option value="" disabled selected>Pilih aksesoris...</option>' + d.slots
        .filter((s) => s.id !== 'collar')
        .map((s) => `<optgroup label="${esc(s.label)}">${d.items.filter((a) => a.slot === s.id)
            .map((a) => `<option value="${esc(a.prop)}">${a.fitted ? '✓ ' : ''}${esc(a.label)}</option>`).join('')}</optgroup>`)
        .join('');
    renderFit();
    $('fit').classList.remove('hidden');
}

/* ------------------------------------------------------------- umum */
function closeAll() {
    $('shop').classList.add('hidden');
    $('ctl').classList.add('hidden');
    $('fit').classList.add('hidden');
    dragX = null;
}

document.querySelectorAll('[data-close]').forEach((b) => b.addEventListener('click', () => post('close')));
document.addEventListener('keydown', (e) => {
    if (e.key === 'Escape') post('close');
});

window.addEventListener('message', (e) => {
    const { action, data } = e.data || {};
    if (action === 'openShop') {
        Object.assign(shop, { pets: data.pets, food: data.food, info: data.info, nameMax: data.nameMax, tab: 'pets', method: 'cash', sel: null });
        shop.trialEnds = Date.now() + ((data.info.trial && data.info.trial.left) || 0) * 1000;
        acc.catalog = data.acc;
        acc.accPet = null;
        $('shop-title').textContent = data.title;
        document.querySelectorAll('#shop-tabs button').forEach((x) => x.classList.toggle('active', x.dataset.tab === 'pets'));
        document.querySelectorAll('.methods button').forEach((x) => x.classList.toggle('active', x.dataset.method === 'cash'));
        renderWallet();
        $('shop').classList.remove('hidden');
        if (shop.pets.length) select(shop.pets[0].id); else { renderList(); renderDetail(); }
    } else if (action === 'openFit') {
        openFit(data);
    } else if (action === 'previewInfo') {
        const n = data.collars || 0;
        if (n !== acc.collarCount) {
            acc.collarCount = n;
            if (shop.tab === 'acc') renderList();
        }
    } else if (action === 'openPanel') {
        selected = data.select != null ? String(data.select) : 'all';
        lastPanel = data;
        renderPanel(data);
        showFriends(false);
        $('ctl').classList.remove('hidden');
    } else if (action === 'panelData') {
        lastPanel = data;
        renderPanel(data);
    } else if (action === 'close') {
        closeAll();
    }
});
