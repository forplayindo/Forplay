// f_claimreward NUI. Semua hasil (gacha, saldo, kode) datang dari server; NUI hanya menampilkan.
const $ = (id) => document.getElementById(id);
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const num = (n) => Math.floor(n || 0).toLocaleString('id-ID');
const icon = (n) => `<svg class="ic"><use href="#i-${n}"/></svg>`;
const RANK = { common: 1, uncommon: 2, rare: 3, epic: 4, legendary: 5 };
const CAT = { item: 'Barang', vehicle: 'Kendaraan', bundle: 'Bundle', other: 'Lainnya' };
const SRC = { gacha: 'Gacha', code: 'Kode', shop: 'Toko', daily: 'Harian' };

let S = null;          // state dari server
let offset = 0;        // waktu server - waktu lokal (detik)
let rarLabel = {};
let busy = false;
let tab = 'gacha';
let timer = null;
let shopDirty = false;

function post(name, data = {}) {
    return fetch(`https://${GetParentResourceName()}/${name}`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(data),
    }).then((r) => r.json()).catch(() => ({ ok: false, msg: 'Server tidak merespons.' }));
}

let toastTimer;
function toast(msg, ok) {
    if (!msg) return;
    const t = $('toast');
    t.textContent = msg;
    t.className = `toast ${ok ? 'ok' : 'err'}`;
    clearTimeout(toastTimer);
    toastTimer = setTimeout(() => t.classList.add('hidden'), 2800);
}

// ---------- gambar hadiah ----------
function media(img, cls = '') {
    let inner;
    if (img === 'coin') inner = '<i class="ic-coin"></i>';
    else if (img === 'manual') inner = icon('house');
    else if (img && img.startsWith('item:')) inner = `<img src="nui://ox_inventory/web/images/${esc(img.slice(5))}.png" data-fb="box">`;
    else if (img && img.startsWith('veh:')) {
        const m = esc(img.slice(4));
        inner = `<img src="nui://f_vehimages/images/${m}.webp" data-alt="https://docs.fivem.net/vehicles/${m}.webp" data-fb="car">`;
    } else inner = icon('box');
    return `<div class="media ${cls}">${inner}</div>`;
}

// gambar gagal: coba sumber kedua, lalu ikon
document.addEventListener('error', (e) => {
    const img = e.target;
    if (!(img instanceof HTMLImageElement)) return;
    if (img.dataset.alt) {
        const alt = img.dataset.alt;
        delete img.dataset.alt;
        img.src = alt;
        return;
    }
    const wrap = document.createElement('span');
    wrap.innerHTML = icon(img.dataset.fb || 'box');
    img.replaceWith(wrap.firstChild);
}, true);

const capt = (r) => (r.type === 'item' ? `${r.label} x${r.count}` : r.label);
const stars = (rarity) => '★'.repeat(RANK[rarity] || 1);
const nowS = () => Date.now() / 1000 + offset;

function fmtLeft(s) {
    s = Math.floor(s);
    if (s <= 0) return 'Berakhir';
    const d = Math.floor(s / 86400), h = Math.floor((s % 86400) / 3600), m = Math.floor((s % 3600) / 60), sec = s % 60;
    if (d) return `${d} hari ${h} jam`;
    if (h) return `${h} jam ${m} mnt`;
    return `${m} mnt ${sec} dtk`;
}

// hitung mundur hanya saat menu terbuka
function tick() {
    document.querySelectorAll('[data-exp]').forEach((el) => {
        el.textContent = fmtLeft(Number(el.dataset.exp) - nowS());
    });
}

// ---------- buka / tutup ----------
window.addEventListener('message', (e) => {
    const m = e.data;
    if (m.action === 'open') {
        S = m.data;
        offset = S.now - Date.now() / 1000;
        $('admin-btn').classList.toggle('hidden', !S.admin);
        if (tab === 'admin' && !S.admin) tab = 'gacha';
        renderAll();
        $('panel').classList.remove('hidden');
        setTab(tab);
        clearInterval(timer);
        timer = setInterval(tick, 1000);
    } else if (m.action === 'close') {
        hide();
    }
});

function hide() {
    $('panel').classList.add('hidden');
    $('reveal').classList.add('hidden');
    closeModal();
    clearInterval(timer);
}

function close() {
    hide();
    post('close');
}

$('close').addEventListener('click', close);

document.addEventListener('keydown', (e) => {
    if (e.key !== 'Escape' || $('panel').classList.contains('hidden')) return;
    if (!$('modal').classList.contains('hidden')) return closeModal();
    if (!$('reveal').classList.contains('hidden')) return phase === 'done' ? endReveal() : skipReveal();
    close();
});

function renderAll() {
    rarLabel = {};
    S.gacha.rarities.forEach((r) => { rarLabel[r.id] = r.label; });
    setBalance(S.balance);
    renderGacha();
    renderShop();
    renderDaily();
}

function setBalance(b) {
    if (!b) return;
    S.balance = b;
    $('w-coins').textContent = num(b.coins);
    renderPity();
}

// ---------- tab ----------
$('tabs').addEventListener('click', (e) => {
    const b = e.target.closest('[data-tab]');
    if (b) setTab(b.dataset.tab);
});

async function setTab(t) {
    tab = t;
    document.querySelectorAll('#tabs [data-tab]').forEach((b) => b.classList.toggle('active', b.dataset.tab === t));
    document.querySelectorAll('main > .tab').forEach((s) => s.classList.toggle('hidden', s.id !== `tab-${t}`));
    if (t === 'admin') openAdmin();
    if (t === 'shop' && shopDirty) {
        shopDirty = false;
        const st = await post('state');
        if (st && st.shop) { S.shop = st.shop; renderShop(); }
    }
}

// ---------- modal ----------
function openModal(html) {
    $('modal-box').innerHTML = html;
    $('modal').classList.remove('hidden');
}
function closeModal() { $('modal').classList.add('hidden'); }
$('modal').addEventListener('click', (e) => {
    if (e.target === $('modal') || e.target.closest('[data-m="close"]')) closeModal();
});

// =====================================================================
// GACHA
// =====================================================================
function renderGacha() {
    const g = S.gacha;
    $('g-title').textContent = g.title;
    $('g-sub').textContent = g.subtitle;
    $('g-cost1').textContent = num(g.costOne);
    $('g-cost10').textContent = num(g.costTen);
    $('g-note').textContent = `Tarik 10x dijamin minimal 1 ${g.guarantee}`;

    const hero = g.featured[0];
    $('g-hero').innerHTML = hero ? `<div class="hero-rays"></div>
        <div class="hero r-${hero.rarity}">${media(hero.img, 'hm')}
            <span class="stars">${stars(hero.rarity)}</span><b>${esc(capt(hero))}</b>
            <span class="tag-main">${hero.featured ? 'HADIAH UTAMA · ' : ''}${esc(rarLabel[hero.rarity])}</span></div>` : '';
    $('g-feat').innerHTML = g.featured.slice(1, 9).map((f) =>
        `<div class="feat r-${f.rarity}"><div class="fm">${media(f.img)}</div><small>${esc(capt(f))}</small></div>`).join('');
    renderPity();
}

function renderPity() {
    if (!S || !S.gacha) return;
    const g = S.gacha, p = S.balance.pity;
    $('g-pity').textContent = `${p} / ${g.hard}`;
    $('g-pity-bar').style.width = `${Math.min(100, (p / g.hard) * 100)}%`;
    $('g-pity-note').textContent = p > g.softStart
        ? `Peluang Legendaris sedang naik! Pasti dapat dalam ${g.hard - p} tarikan.`
        : `Pasti dapat Legendaris paling lambat ${g.hard - p} tarikan lagi.`;
}

document.querySelectorAll('[data-pull]').forEach((b) => b.addEventListener('click', () => pull(Number(b.dataset.pull))));

async function pull(n) {
    if (busy) return;
    const cost = n === 10 ? S.gacha.costTen : S.gacha.costOne;
    if (S.balance.coins < cost) return toast(`Koin tidak cukup (butuh ${num(cost)}).`);
    busy = true;
    document.querySelectorAll('[data-pull]').forEach((b) => { b.disabled = true; });
    const res = await post('pull', { count: n });
    busy = false;
    document.querySelectorAll('[data-pull]').forEach((b) => { b.disabled = false; });
    if (!res.ok) return toast(res.msg || 'Gagal menarik.');
    setBalance(res.balance);
    showReveal(res.results);
}

// ---------- animasi hasil ----------
let phase = 'done';
let rvTimers = [];

function clearRv() { rvTimers.forEach(clearTimeout); rvTimers = []; }

function showReveal(results) {
    clearRv();
    const best = results.reduce((a, r) => (RANK[r.rarity] > RANK[a] ? r.rarity : a), 'common');
    $('reveal').className = `reveal best-${best}`;
    const cards = $('rv-cards');
    cards.className = `rv-cards ${results.length === 1 ? 'n1' : 'n10'} hidden`;
    cards.innerHTML = results.map((r, i) => `<div class="rcard r-${r.rarity}" style="--d:${i}"><div class="rc-inner">
        <div class="rc-back"></div>
        <div class="rc-face"><div class="rm">${media(r.img)}</div><span class="stars">${stars(r.rarity)}</span>
        <b>${esc(capt(r))}</b><small>${esc(rarLabel[r.rarity])}</small></div></div></div>`).join('');

    const orbWrap = $('rv-orb');
    orbWrap.classList.remove('hidden');
    const orb = orbWrap.firstElementChild;
    orb.style.animation = 'none';
    void orb.offsetWidth; // ulang animasi
    orb.style.animation = '';

    $('rv-skip').classList.remove('hidden');
    $('rv-done').classList.add('hidden');
    phase = 'orb';
    rvTimers.push(setTimeout(() => showCards(false), 1450));
}

function showCards(instant) {
    clearRv();
    phase = 'cards';
    $('rv-orb').classList.add('hidden');
    $('rv-cards').classList.remove('hidden');
    if (instant) $('reveal').classList.add('instant');
    const n = $('rv-cards').children.length;
    rvTimers.push(setTimeout(finishReveal, instant ? 30 : n * 110 + 800));
}

function finishReveal() {
    clearRv();
    phase = 'done';
    $('rv-skip').classList.add('hidden');
    $('rv-done').classList.remove('hidden');
}

function skipReveal() {
    if (phase === 'orb') return showCards(true);
    $('reveal').classList.add('instant');
    finishReveal();
}

function endReveal() {
    clearRv();
    $('reveal').classList.add('hidden');
}

$('rv-skip').addEventListener('click', skipReveal);
$('rv-done').addEventListener('click', endReveal);
$('reveal').addEventListener('click', (e) => {
    if (phase !== 'done' && !e.target.closest('button')) skipReveal();
});

// =====================================================================
// TOKO
// =====================================================================
let shopCat = 'all';
let shopQ = '';

const priceHtml = (e) => `<i class="ic-coin"></i>${num(e.price)}`;
const soldOut = (e) => e.limit > 0 && e.bought >= e.limit;
const tileHtml = (r) => `<div class="tile"><div class="tm">${media(r.img)}</div><small>${esc(capt(r))}</small></div>`;

function chipsHtml(e) {
    const c = [];
    if (e.rewards.some((r) => r.type === 'vehicle')) c.push('<span class="chip blue">Masuk garasi Balai Kota</span>');
    if (e.rewards.some((r) => r.type === 'manual')) c.push('<span class="chip orange">Diserahkan admin</span>');
    if (e.category !== 'bundle' && e.rewards.length > 1) c.push(`<span class="chip">+${e.rewards.length - 1} hadiah lain</span>`);
    if (e.limit > 0) c.push(`<span class="chip">${soldOut(e) ? 'Habis' : `Sisa ${e.limit - e.bought}/${e.limit}`}</span>`);
    if (e.expiresAt > 0) c.push(`<span class="chip warn">${icon('clock')}<span class="cd" data-exp="${e.expiresAt}">${fmtLeft(e.expiresAt - nowS())}</span></span>`);
    return c.join('');
}

function buyBtn(e, text) {
    const so = soldOut(e);
    return `<button class="buy" data-buy="${e.id}" ${so ? 'disabled' : ''}>${so ? 'Sudah dibeli' : text || priceHtml(e)}</button>`;
}

function renderShop() {
    const list = S.shop.filter((e) => (shopCat === 'all' || e.category === shopCat) && (!shopQ || e.label.toLowerCase().includes(shopQ)));
    const scroll = $('s-scroll').scrollTop;
    $('s-bundles').innerHTML = list.filter((e) => e.category === 'bundle').map((e) => `<div class="bundle">
        <div class="b-main">
            <div class="b-title">${icon('fire')}<div><b>${esc(e.label)}</b><small>${esc(e.description)}</small></div></div>
            <div class="tiles">${e.rewards.map(tileHtml).join('')}</div>
            <div class="chips">${chipsHtml(e)}</div>
        </div>
        <div class="b-side"><span></span><div class="price-big">${priceHtml(e)}</div>${buyBtn(e, 'Beli Sekarang')}</div>
    </div>`).join('');
    const cards = list.filter((e) => e.category !== 'bundle');
    $('s-grid').innerHTML = cards.map((e) => {
        const r0 = e.rewards[0];
        return `<div class="scard">
            <div class="sm">${media(r0.img)}${r0.type === 'item' && r0.count > 1 ? `<span class="count">x${r0.count}</span>` : ''}</div>
            <div class="sb"><b>${esc(e.label)}</b><p>${esc(e.description)}</p><div class="chips">${chipsHtml(e)}</div></div>
            ${buyBtn(e)}
        </div>`;
    }).join('');
    if (!list.length) $('s-grid').innerHTML = '<div class="empty" style="grid-column:1/-1">Tidak ada barang di kategori ini.</div>';
    $('s-scroll').scrollTop = scroll;
}

$('s-filters').addEventListener('click', (e) => {
    const b = e.target.closest('[data-cat]');
    if (!b) return;
    shopCat = b.dataset.cat;
    document.querySelectorAll('#s-filters button').forEach((x) => x.classList.toggle('active', x === b));
    $('s-scroll').scrollTop = 0;
    renderShop();
});

$('s-search').addEventListener('input', (e) => {
    shopQ = e.target.value.trim().toLowerCase();
    renderShop();
});

$('s-scroll').addEventListener('click', (e) => {
    const b = e.target.closest('[data-buy]');
    if (b && !b.disabled) confirmBuy(Number(b.dataset.buy));
});

function confirmBuy(id) {
    const e = S.shop.find((x) => x.id === id);
    if (!e) return;
    const bal = S.balance.coins;
    const enough = bal >= e.price;
    const veh = e.rewards.some((r) => r.type === 'vehicle');
    const manual = e.rewards.some((r) => r.type === 'manual');
    openModal(`<h3>Beli ${esc(e.label)}?</h3>
        <div class="tiles">${e.rewards.map(tileHtml).join('')}</div>
        ${veh ? '<p>Kendaraan langsung masuk garasi dekat Balai Kota. Kunci didapat saat kendaraan pertama kali diambil.</p>' : ''}
        ${manual ? '<p>Hadiah manual diserahkan langsung oleh admin. Datangi admin setelah membeli.</p>' : ''}
        <div class="sum"><span>Harga</span><b>${priceHtml(e)}</b></div>
        <div class="sum"><span>Saldo setelah beli</span><b class="${enough ? '' : 't-red'}">${enough ? num(bal - e.price) : 'Saldo tidak cukup'}</b></div>
        <div class="m-btns"><button class="b b-gray b-lg" data-m="close">Batal</button>
        <button class="primary b-lg" id="m-ok" ${enough ? '' : 'disabled'}>Beli</button></div>`);
    $('m-ok').addEventListener('click', async (ev) => {
        ev.currentTarget.disabled = true;
        const res = await post('buy', { id });
        closeModal();
        toast(res.msg, res.ok);
        if (res.ok) {
            setBalance(res.balance);
            S.shop = res.shop;
            renderShop();
        }
    });
}

// =====================================================================
// HARIAN
// =====================================================================
function renderDaily() {
    const d = S.daily;
    $('d-grid').innerHTML = d.days.map((rewards, i) => {
        const day = i + 1;
        const today = day === d.day;
        const done = day < d.day || (today && d.claimed);
        const r0 = rewards[0];
        const extra = rewards.slice(1).map(capt).join(', ');
        return `<div class="dcard ${done ? 'done' : ''} ${today ? 'today' : ''} ${day === d.days.length ? 'big' : ''}">
            <span class="dh">Hari ${day}</span>
            <div class="dm">${media(r0.img)}</div>
            <div class="dl">${esc(capt(r0))}${extra ? `<small>+ ${esc(extra)}</small>` : ''}</div>
            <span class="ds">${done ? icon('check') : today ? '<span class="chip accent">Hari ini</span>' : icon('lock')}</span>
        </div>`;
    }).join('');
    $('d-claim').disabled = d.claimed;
    $('d-claim').textContent = d.claimed ? 'Kembali besok' : `Klaim Hari ${d.day}`;
    $('daily-dot').classList.toggle('hidden', d.claimed);
}

$('d-claim').addEventListener('click', async () => {
    $('d-claim').disabled = true;
    const res = await post('daily');
    toast(res.msg, res.ok);
    if (res.ok) {
        setBalance(res.balance);
        S.daily = res.daily;
    }
    renderDaily();
});

// =====================================================================
// KODE
// =====================================================================
let checkedCode = null;

function codeMsg(text, ok) {
    $('c-msg').textContent = text || '';
    $('c-msg').classList.toggle('ok', !!ok);
    $('c-msg').classList.toggle('hidden', !text);
}

async function checkCode() {
    const code = $('c-input').value.trim().toUpperCase();
    $('c-result').classList.add('hidden');
    if (code.length < 3) return codeMsg('Masukkan kode referral.');
    $('c-check').disabled = true;
    const res = await post('checkCode', { code });
    $('c-check').disabled = false;
    if (!res.ok) return codeMsg(res.msg || 'Kode tidak valid.');
    codeMsg('');
    checkedCode = res.code;
    $('c-tiles').innerHTML = res.rewards.map(tileHtml).join('');
    $('c-exp').innerHTML = `Berakhir dalam <span data-exp="${res.expiresAt}">${fmtLeft(res.expiresAt - nowS())}</span>`;
    $('c-result').classList.remove('hidden');
}

$('c-check').addEventListener('click', checkCode);
$('c-input').addEventListener('keydown', (e) => { if (e.key === 'Enter') checkCode(); });
$('c-input').addEventListener('input', () => {
    $('c-result').classList.add('hidden');
    codeMsg('');
});

$('c-claim').addEventListener('click', async () => {
    if (!checkedCode) return;
    $('c-claim').disabled = true;
    const res = await post('claimCode', { code: checkedCode });
    $('c-claim').disabled = false;
    if (!res.ok) {
        $('c-result').classList.add('hidden');
        return codeMsg(res.msg);
    }
    $('c-result').classList.add('hidden');
    $('c-input').value = '';
    checkedCode = null;
    codeMsg(res.msg, true);
    setBalance(res.balance);
});

// =====================================================================
// ADMIN
// =====================================================================
let A = null;              // { items, vehicles, players }
let itemMap = {}, vehMap = {};
let pane = 'codes';
let rbCode = null, rbShop = null;

async function openAdmin() {
    if (!A) {
        const res = await post('adminBoot');
        if (!res.ok) return toast(res.msg);
        A = res;
        itemMap = Object.fromEntries(A.items.map((i) => [i.name, i]));
        vehMap = Object.fromEntries(A.vehicles.map((v) => [v.model, v]));
        rbCode = new RewardBuilder($('ac-rb'));
        rbShop = new RewardBuilder($('as-rb'));
        newShop();
    }
    setPane(pane);
}

$('a-seg').addEventListener('click', (e) => {
    const b = e.target.closest('[data-a]');
    if (b) setPane(b.dataset.a);
});

function setPane(p) {
    pane = p;
    document.querySelectorAll('#a-seg [data-a]').forEach((b) => b.classList.toggle('active', b.dataset.a === p));
    ['codes', 'shop', 'give', 'winners'].forEach((x) => $(`a-${x}`).classList.toggle('hidden', x !== p));
    if (p === 'codes') loadCodes();
    else if (p === 'shop') loadShopAdmin();
    else if (p === 'give') loadPlayers();
    else if (p === 'winners') loadWinners();
}

// ---------- pembuat daftar hadiah ----------
const rawImg = (r) => ({ item: `item:${r.name}`, vehicle: `veh:${r.model}`, money: 'item:money', coins: 'coin' }[r.type] || 'manual');
function rawLabel(r) {
    if (r.type === 'item') return `${itemMap[r.name]?.label || r.name} x${r.count}`;
    if (r.type === 'vehicle') return vehMap[r.model]?.label || r.model;
    if (r.type === 'money') return `Rp ${num(r.amount)}`;
    if (r.type === 'coins') return `${num(r.amount)} Koin`;
    return r.label;
}
const TYPE_LABEL = { item: 'Item', vehicle: 'Kendaraan · masuk garasi', money: 'Uang ke bank', coins: 'Koin Hadiah', manual: 'Diserahkan admin' };

class RewardBuilder {
    constructor(el) {
        this.list = [];
        this.sel = null;
        el.innerHTML = `<span>Hadiah</span><div class="rb-list"></div>
            <div class="rb-add">
                <select class="rb-type"><option value="item">Item</option><option value="vehicle">Kendaraan</option>
                <option value="money">Uang (bank)</option><option value="coins">Koin</option><option value="manual">Manual (admin)</option></select>
                <div class="rb-pick"><input class="rb-q" autocomplete="off" spellcheck="false"><div class="rb-drop hidden"></div></div>
                <input class="rb-n" type="number" min="1" value="1">
                <button class="b b-tinted b-sm rb-btn">${icon('plus')}</button>
            </div>`;
        this.listEl = el.querySelector('.rb-list');
        this.type = el.querySelector('.rb-type');
        this.q = el.querySelector('.rb-q');
        this.n = el.querySelector('.rb-n');
        this.drop = el.querySelector('.rb-drop');

        this.type.addEventListener('change', () => this.mode());
        this.q.addEventListener('input', () => { this.sel = null; this.search(); });
        this.q.addEventListener('focus', () => this.search());
        this.q.addEventListener('keydown', (e) => { if (e.key === 'Enter') this.add(); });
        this.n.addEventListener('keydown', (e) => { if (e.key === 'Enter') this.add(); });
        this.drop.addEventListener('mousedown', (e) => {
            const b = e.target.closest('[data-k]');
            if (!b) return;
            e.preventDefault();
            this.sel = b.dataset.k;
            this.q.value = b.dataset.l;
            this.drop.classList.add('hidden');
            this.n.focus();
            this.n.select();
        });
        el.querySelector('.rb-btn').addEventListener('click', () => this.add());
        this.listEl.addEventListener('click', (e) => {
            const b = e.target.closest('[data-i]');
            if (!b) return;
            this.list.splice(Number(b.dataset.i), 1);
            this.render();
        });
        this.mode();
        this.render();
    }

    mode() {
        const t = this.type.value;
        this.sel = null;
        this.q.value = '';
        this.drop.classList.add('hidden');
        this.q.disabled = t === 'money' || t === 'coins';
        this.q.placeholder = { item: 'Cari item...', vehicle: 'Cari kendaraan...', money: 'Jumlah Rp →', coins: 'Jumlah koin →', manual: 'Nama hadiah, mis. Rumah' }[t];
        this.n.classList.toggle('hidden', t === 'vehicle' || t === 'manual');
        this.n.value = t === 'money' ? 50000 : t === 'coins' ? 50 : 1;
    }

    search() {
        const t = this.type.value;
        if (t !== 'item' && t !== 'vehicle') return;
        const s = this.q.value.trim().toLowerCase();
        const src = t === 'item' ? A.items : A.vehicles;
        const res = src.filter((x) => !s || x.label.toLowerCase().includes(s) || (x.name || x.model).toLowerCase().includes(s)).slice(0, 40);
        this.drop.innerHTML = res.length ? res.map((x) => {
            const key = x.name || x.model;
            const img = t === 'item' ? media(`item:${key}`, 'dm') : `<span class="dm media">${icon('car')}</span>`;
            return `<button data-k="${esc(key)}" data-l="${esc(x.label)}">${img}${esc(x.label)}<small>${esc(key)}</small></button>`;
        }).join('') : '<div class="empty">Tidak ditemukan</div>';
        this.drop.classList.remove('hidden');
    }

    add() {
        const t = this.type.value;
        const n = Math.floor(Number(this.n.value));
        let r;
        if (t === 'item' || t === 'vehicle') {
            const map = t === 'item' ? itemMap : vehMap;
            const key = this.sel || (map[this.q.value.trim()] ? this.q.value.trim() : null);
            if (!key) return toast(t === 'item' ? 'Pilih item dari daftar.' : 'Pilih kendaraan dari daftar.');
            if (t === 'item' && !(n >= 1)) return toast('Jumlah minimal 1.');
            r = t === 'item' ? { type: 'item', name: key, count: n } : { type: 'vehicle', model: key };
        } else if (t === 'money' || t === 'coins') {
            if (!(n >= 1)) return toast('Jumlah minimal 1.');
            r = { type: t, amount: n };
        } else {
            const label = this.q.value.trim();
            if (!label) return toast('Isi nama hadiah manual.');
            r = { type: 'manual', label };
        }
        this.list.push(r);
        this.render();
        this.mode();
        this.q.focus();
    }

    render() {
        this.listEl.innerHTML = this.list.length ? this.list.map((r, i) => `<div class="rb-row">
            <div class="rm">${media(rawImg(r))}</div>
            <span class="t">${esc(rawLabel(r))}<small>${TYPE_LABEL[r.type]}</small></span>
            <button data-i="${i}" title="Hapus">${icon('x')}</button></div>`).join('')
            : '<small class="t-muted">Belum ada hadiah. Tambahkan di bawah.</small>';
    }

    get() { return this.list.map((r) => ({ ...r })); }
    set(list) { this.list = (list || []).map((r) => ({ ...r })); this.render(); this.mode(); }
}

document.addEventListener('mousedown', (e) => {
    if (!e.target.closest('.rb-pick')) document.querySelectorAll('.rb-drop').forEach((d) => d.classList.add('hidden'));
});

// ---------- kode referral ----------
function renderCodes(codes) {
    const el = $('ac-list');
    const st = el.scrollTop;
    el.innerHTML = codes.length ? codes.map((c) => {
        const expired = c.expiresAt <= nowS();
        return `<div class="arow ${expired ? 'off' : ''}">
            <div class="t"><b class="code">${esc(c.code)}</b>
                <small>${esc(c.rewards.map(capt).join(', '))}</small>
                <small>Dipakai ${c.uses}${c.maxUses ? ` / ${c.maxUses}` : ''} · oleh ${esc(c.createdBy)}</small></div>
            <div class="side">${expired ? '<span class="chip red">Expired</span>'
                : `<span class="chip green">${icon('clock')}<span data-exp="${c.expiresAt}">${fmtLeft(c.expiresAt - nowS())}</span></span>`}
                <button class="del-btn" data-delcode="${esc(c.code)}" title="Hapus">${icon('trash')}</button></div>
        </div>`;
    }).join('') : '<div class="empty">Belum ada kode referral.</div>';
    el.scrollTop = st;
}

async function loadCodes() {
    const res = await post('adminCodes');
    if (res.ok) renderCodes(res.codes);
}

$('ac-list').addEventListener('click', (e) => {
    const b = e.target.closest('[data-delcode]');
    if (!b) return;
    const code = b.dataset.delcode;
    openModal(`<h3>Hapus kode ${esc(code)}?</h3><p>Pemain tidak bisa klaim kode ini lagi. Hadiah yang sudah diklaim tidak ditarik.</p>
        <div class="m-btns"><button class="b b-gray b-lg" data-m="close">Batal</button><button class="b b-red b-lg" id="m-ok">Hapus</button></div>`);
    $('m-ok').addEventListener('click', async () => {
        const res = await post('adminDeleteCode', { code });
        closeModal();
        toast(res.msg, res.ok);
        if (res.ok) renderCodes(res.codes);
    });
});

$('ac-rand').addEventListener('click', () => {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    $('ac-code').value = Array.from({ length: 8 }, () => chars[Math.floor(Math.random() * chars.length)]).join('');
});

document.querySelectorAll('.quick').forEach((q) => q.addEventListener('click', (e) => {
    const b = e.target.closest('[data-v]');
    if (!b) return;
    $(q.dataset.for).value = b.dataset.v;
    q.querySelectorAll('button').forEach((x) => x.classList.toggle('active', x === b));
}));
$('ac-min').addEventListener('input', () => document.querySelectorAll('.quick[data-for="ac-min"] button').forEach((x) => x.classList.remove('active')));

$('ac-save').addEventListener('click', async () => {
    const btn = $('ac-save');
    btn.disabled = true;
    const res = await post('adminSaveCode', {
        code: $('ac-code').value.trim().toUpperCase(),
        rewards: rbCode.get(),
        minutes: Number($('ac-min').value),
        maxUses: Number($('ac-max').value) || 0,
    });
    btn.disabled = false;
    toast(res.msg, res.ok);
    if (!res.ok) return;
    renderCodes(res.codes);
    $('ac-code').value = '';
    rbCode.set([]);
});

// ---------- toko ----------
let shopAdmin = [];
let editId = null;

function renderShopAdmin() {
    const el = $('as-list');
    const box = el.parentElement;
    const st = box.scrollTop;
    el.innerHTML = shopAdmin.length ? shopAdmin.map((e) => {
        const expired = e.expiresAt > 0 && e.expiresAt <= nowS();
        const chip = !e.active ? '<span class="chip">Nonaktif</span>'
            : expired ? '<span class="chip red">Berakhir</span>'
            : e.expiresAt > 0 ? `<span class="chip warn"><span data-exp="${e.expiresAt}">${fmtLeft(e.expiresAt - nowS())}</span></span>`
            : '<span class="chip green">Dijual</span>';
        return `<button class="arow ${e.id === editId ? 'sel' : ''} ${!e.active || expired ? 'off' : ''}" data-edit="${e.id}">
            <div class="am">${media(e.display[0]?.img)}</div>
            <div class="t"><b>${esc(e.label)}</b><small>${CAT[e.category] || e.category} · ${num(e.price)} Koin · batas ${e.limit || 'bebas'}</small>
                <small>${esc(e.display.map(capt).join(', '))}</small></div>
            <div class="side">${chip}</div></button>`;
    }).join('') : '<div class="empty">Toko masih kosong.</div>';
    box.scrollTop = st;
}

async function loadShopAdmin() {
    const res = await post('adminShop');
    if (!res.ok) return;
    shopAdmin = res.shop;
    renderShopAdmin();
}

function newShop() {
    editId = null;
    $('as-title').textContent = 'Barang Baru';
    $('as-label').value = '';
    $('as-desc').value = '';
    $('as-cat').value = 'item';
    $('as-sort').value = 0;
    $('as-price').value = 100;
    $('as-limit').value = 0;
    $('as-min').value = '';
    $('as-min').placeholder = '0 = selamanya';
    $('as-active').classList.add('on');
    $('as-del').classList.add('hidden');
    rbShop.set([]);
    renderShopAdmin();
}

function editShop(id) {
    const e = shopAdmin.find((x) => x.id === id);
    if (!e) return;
    editId = id;
    $('as-title').textContent = `Ubah: ${e.label}`;
    $('as-label').value = e.label;
    $('as-desc').value = e.description;
    $('as-cat').value = e.category;
    $('as-sort').value = e.sort;
    $('as-price').value = e.price;
    $('as-limit').value = e.limit;
    $('as-min').value = '';
    $('as-min').placeholder = e.expiresAt > 0 ? 'kosong = tetap (isi 0 = selamanya)' : 'kosong = tetap selamanya';
    $('as-active').classList.toggle('on', e.active);
    $('as-del').classList.remove('hidden');
    rbShop.set(e.rewards);
    renderShopAdmin();
}

$('as-new').addEventListener('click', newShop);
$('as-list').addEventListener('click', (e) => {
    const b = e.target.closest('[data-edit]');
    if (b) editShop(Number(b.dataset.edit));
});
$('as-active').addEventListener('click', (e) => e.currentTarget.classList.toggle('on'));

$('as-save').addEventListener('click', async () => {
    const minRaw = $('as-min').value.trim();
    const btn = $('as-save');
    btn.disabled = true;
    const res = await post('adminSaveShop', {
        id: editId,
        label: $('as-label').value,
        description: $('as-desc').value,
        category: $('as-cat').value,
        rewards: rbShop.get(),
        price: Number($('as-price').value),
        limit: Number($('as-limit').value) || 0,
        minutes: minRaw === '' ? (editId ? -1 : 0) : Number(minRaw),
        active: $('as-active').classList.contains('on'),
        sort: Number($('as-sort').value) || 0,
    });
    btn.disabled = false;
    toast(res.msg, res.ok);
    if (!res.ok) return;
    shopAdmin = res.shop;
    shopDirty = true;
    editShop(res.id);
});

$('as-del').addEventListener('click', () => {
    const e = shopAdmin.find((x) => x.id === editId);
    if (!e) return;
    openModal(`<h3>Hapus "${esc(e.label)}"?</h3><p>Barang hilang dari toko. Riwayat pembelian barang ini ikut dihapus.</p>
        <div class="m-btns"><button class="b b-gray b-lg" data-m="close">Batal</button><button class="b b-red b-lg" id="m-ok">Hapus</button></div>`);
    $('m-ok').addEventListener('click', async () => {
        const res = await post('adminDeleteShop', { id: e.id });
        closeModal();
        toast(res.msg, res.ok);
        if (!res.ok) return;
        shopAdmin = res.shop;
        shopDirty = true;
        newShop();
    });
});

// ---------- beri koin ----------
async function loadPlayers() {
    const res = await post('adminBoot');
    if (res.ok) A.players = res.players;
    $('ag-players').innerHTML = A.players.length ? A.players.map((p) => `<button class="ag-p" data-id="${p.id}">
        <span class="id">${p.id}</span>${esc(p.name)}<small>${esc(p.cid)}</small></button>`).join('')
        : '<div class="empty">Tidak ada pemain online.</div>';
}

$('ag-players').addEventListener('click', (e) => {
    const b = e.target.closest('[data-id]');
    if (b) $('ag-target').value = b.dataset.id;
});

$('ag-send').addEventListener('click', async () => {
    const btn = $('ag-send');
    btn.disabled = true;
    const res = await post('adminGive', { target: $('ag-target').value.trim(), amount: Number($('ag-amount').value) });
    btn.disabled = false;
    toast(res.msg, res.ok);
    if (res.ok) {
        const st = await post('state'); // saldo sendiri ikut berubah kalau target diri sendiri
        if (st && st.balance) setBalance(st.balance);
    }
});

// ---------- pemenang ----------
let winStatus = 'menunggu';

function fmtDate(ts) {
    return new Date(ts * 1000).toLocaleString('id-ID', { day: '2-digit', month: 'short', hour: '2-digit', minute: '2-digit' });
}

function renderWinners(list) {
    const el = $('aw-list');
    const st = el.scrollTop;
    el.innerHTML = list.length ? list.map((w) => {
        const chip = w.status === 'menunggu' ? '<span class="chip orange">Menunggu admin</span>'
            : w.status === 'selesai' ? '<span class="chip green">Sudah diberikan</span>' : '<span class="chip blue">Otomatis</span>';
        const rar = w.rarity ? ` · <span class="r-${esc(w.rarity)}" style="color:rgb(var(--r))">${esc(rarLabel[w.rarity] || w.rarity)}</span>` : '';
        return `<div class="arow">
            <div class="t"><b>${esc(w.reward)}</b>
                <small>${esc(w.name)} · ${esc(w.citizenid)} · ${SRC[w.source] || esc(w.source)}${rar}</small>
                <small>${esc(w.detail)} · ${fmtDate(w.created_at)}${w.handled_by ? ` · diurus ${esc(w.handled_by)}` : ''}</small></div>
            <div class="side">${chip}${w.status === 'menunggu' ? `<button class="b b-green-tint b-sm" data-mark="${w.id}">Tandai sudah diberikan</button>` : ''}</div>
        </div>`;
    }).join('') : `<div class="empty">${winStatus === 'menunggu' ? 'Tidak ada hadiah yang menunggu.' : 'Belum ada catatan.'}</div>`;
    el.scrollTop = st;
}

async function loadWinners() {
    const res = await post('adminWinners', { status: winStatus });
    if (!res.ok) return;
    renderWinners(res.winners);
    const full = res.weekAssets >= res.weekCap;
    $('aw-week').textContent = `Aset gacha minggu ini: ${res.weekAssets}/${res.weekCap}${full ? ' · kuota habis' : ''}`;
    $('aw-week').className = `chip ${full ? 'orange' : 'green'}`;
}

$('aw-filter').addEventListener('click', (e) => {
    const b = e.target.closest('[data-v]');
    if (!b) return;
    winStatus = b.dataset.v;
    $('aw-filter').querySelectorAll('button').forEach((x) => x.classList.toggle('active', x === b));
    $('aw-list').scrollTop = 0;
    loadWinners();
});

$('aw-list').addEventListener('click', async (e) => {
    const b = e.target.closest('[data-mark]');
    if (!b) return;
    b.disabled = true;
    const res = await post('adminMarkWinner', { id: Number(b.dataset.mark), status: winStatus });
    toast(res.msg, res.ok);
    if (res.ok) renderWinners(res.winners);
    else b.disabled = false;
});
