// Mockup f_claimreward: mensimulasikan server dengan data tiruan supaya NUI asli bisa dicoba di browser.
// Buka _design/claimreward-mockup/index.html di Chrome/Edge. Gambar item ox_inventory tidak ada di luar game (tampil ikon).
window.GetParentResourceName = () => 'f_claimreward';
document.body.style.background = 'radial-gradient(circle at 30% 20%, #4b5d6e, #1d2630 70%)';

const now = () => Math.floor(Date.now() / 1000);
const it = (name, label, count) => ({ type: 'item', name, label, count, img: 'item:' + name });
const veh = (model, label) => ({ type: 'vehicle', model, label, img: 'veh:' + model });
const coins = (n) => ({ type: 'coins', amount: n, label: n + ' Koin', img: 'coin' });
const money = (n) => ({ type: 'money', amount: n, label: 'Rp ' + n.toLocaleString('id-ID'), img: 'item:money' });
const manual = { type: 'manual', label: 'Rumah', note: 'Datang ke admin untuk serah terima rumah.', img: 'manual' };
const clone = (o) => JSON.parse(JSON.stringify(o));

const pool = {
    common: [it('water', 'Air', 3), it('burger', 'Burger', 2), it('bandage', 'Perban', 2), money(15000), coins(3)],
    uncommon: [it('firstaid', 'P3K', 1), it('repairkit', 'Kit Reparasi', 1), it('cafe_burger', 'Burger Kafe', 3), money(50000), coins(8)],
    rare: [it('armour', 'Rompi Pelindung', 1), it('repairkit', 'Kit Reparasi', 3), money(150000), coins(25)],
    epic: [it('goldbar', 'Emas Batangan', 1), it('diamond', 'Berlian', 1), money(500000), coins(80)],
    legendary: [{ ...veh('sultan', 'Karin Sultan'), w: 10 }, { ...veh('bati', 'Pegassi Bati 801'), w: 10 }, { ...manual, w: 5 }, { ...coins(150), w: 30 }, { ...money(1000000), w: 20 }, { ...it('goldbar', 'Emas Batangan', 3), w: 15 }, { ...it('diamond', 'Berlian', 2), w: 10 }],
};
const rarities = [
    { id: 'common', label: 'Biasa', chance: 60 }, { id: 'uncommon', label: 'Tidak Biasa', chance: 25 },
    { id: 'rare', label: 'Langka', chance: 10 }, { id: 'epic', label: 'Epik', chance: 4 }, { id: 'legendary', label: 'Legendaris', chance: 1 },
];
const rank = { common: 1, uncommon: 2, rare: 3, epic: 4, legendary: 5 };

const me = { name: 'Budi Santoso', cid: 'F1234567' };
const state = {
    balance: { coins: 1385, pity: 57 },
    now: now(),
    admin: true,
    daily: { day: 4, claimed: false, days: [[coins(15)], [coins(15)], [coins(20), it('water', 'Air', 3)], [coins(15)], [coins(15)], [coins(20), it('burger', 'Burger', 3)], [coins(60), it('firstaid', 'P3K', 1)]] },
    gacha: {
        title: 'Banner Musim 1', subtitle: 'Kendaraan & rumah menanti. Jaminan Legendary setiap 80 tarikan.', costOne: 15, costTen: 135,
        hard: 80, softStart: 65, guarantee: 'Langka',
        rarities: rarities.map((r) => ({ id: r.id, label: r.label })),
        featured: [
            { ...veh('sultan', 'Karin Sultan'), rarity: 'legendary', featured: true },
            { ...veh('bati', 'Pegassi Bati 801'), rarity: 'legendary' },
            { ...manual, rarity: 'legendary' },
            ...[coins(150), money(1000000), it('goldbar', 'Emas Batangan', 3), it('diamond', 'Berlian', 2)].map((x) => ({ ...x, rarity: 'legendary' })),
            ...pool.epic.map((x) => ({ ...x, rarity: 'epic' })),
        ],
    },
    shop: [
        { id: 1, label: 'Paket Halloween', description: 'Bundle event terbatas: P3K, kit reparasi, makan & minum.', category: 'bundle', rewards: [it('firstaid', 'P3K', 2), it('repairkit', 'Kit Reparasi', 1), it('water', 'Air', 5), it('burger', 'Burger', 5)], price: 120, limit: 1, bought: 0, expiresAt: now() + 3 * 86400 + 5000 },
        { id: 2, label: 'Shitzu PCJ 600', description: 'Motor lincah untuk keliling kota.', category: 'vehicle', rewards: [veh('pcj', 'Shitzu PCJ 600')], price: 700, limit: 1, bought: 0, expiresAt: 0 },
        { id: 3, label: 'Karin Kuruma', description: 'Sedan sport andalan sehari-hari.', category: 'vehicle', rewards: [veh('kuruma', 'Karin Kuruma')], price: 1400, limit: 1, bought: 0, expiresAt: 0 },
        { id: 4, label: 'Karin Sultan', description: 'Sedan sport cepat dan stabil.', category: 'vehicle', rewards: [veh('sultan', 'Karin Sultan')], price: 2800, limit: 1, bought: 0, expiresAt: 0 },
        { id: 5, label: 'Rumah', description: 'Serah terima rumah langsung oleh admin.', category: 'other', rewards: [manual], price: 4000, limit: 1, bought: 0, expiresAt: 0 },
        { id: 6, label: 'P3K', description: 'Kotak pertolongan pertama.', category: 'item', rewards: [it('firstaid', 'P3K', 1)], price: 25, limit: 0, bought: 0, expiresAt: 0 },
        { id: 7, label: 'Kit Reparasi', description: 'Perbaiki kendaraan di jalan.', category: 'item', rewards: [it('repairkit', 'Kit Reparasi', 1)], price: 40, limit: 0, bought: 0, expiresAt: 0 },
    ],
};

const codes = [
    { code: 'HALLOWEEN2026', rewards: [coins(100), it('firstaid', 'P3K', 2), veh('kuruma', 'Karin Kuruma')], expiresAt: now() + 3600, maxUses: 50, uses: 12, createdBy: 'Admin (F0000001)' },
    { code: 'HALLOWEEN2025', rewards: [coins(50)], expiresAt: now() - 3600 * 24 * 300, maxUses: 0, uses: 87, createdBy: 'Admin (F0000001)' },
];
const claimed = new Set();
const winners = [
    { id: 2, citizenid: 'F7654321', name: 'Siti Aminah', reward: 'Karin Sultan', detail: 'Plat F 4821 R · garasi motelgarage', source: 'shop', rarity: '', status: 'otomatis', handled_by: '', created_at: now() - 7200 },
    { id: 1, citizenid: 'F5550123', name: 'Andi Wijaya', reward: 'Rumah', detail: 'Datang ke admin untuk serah terima rumah.', source: 'gacha', rarity: 'legendary', status: 'selesai', handled_by: 'Admin (F0000001)', created_at: now() - 86400, handled_at: now() - 80000 },
];
let winnerId = 3;

let weekAssets = 0, assetTier = 0; // simulasi kuota aset mingguan (1) & tingkat karakter
const pick = (list) => { let n = Math.random() * list.reduce((s, x) => s + (x.w || 1), 0); for (const x of list) { n -= x.w || 1; if (n < 0) { const { w, ...r } = x; return r; } } return list[0]; };
function rollRarity(pity) {
    if (pity >= 80) return 'legendary';
    const leg = Math.min(100, 1 + Math.max(0, pity - 65) * 6);
    if (Math.random() * 100 < leg) return 'legendary';
    let n = Math.random() * 99;
    for (const r of rarities) {
        if (r.id === 'legendary') continue;
        n -= r.chance;
        if (n < 0) return r.id;
    }
    return 'common';
}
function addWinner(r, source, rarity) {
    winners.unshift({ id: winnerId++, citizenid: me.cid, name: me.name, reward: r.label, detail: r.type === 'vehicle' ? 'Plat F 1234 R · garasi motelgarage' : r.type === 'manual' ? r.note : 'Masuk tas', source, rarity: rarity || '', status: r.type === 'manual' ? 'menunggu' : 'otomatis', handled_by: '', created_at: now() });
}
function receive(rewards, source, rarity) {
    rewards.forEach((r) => {
        if (r.type === 'coins') state.balance.coins += r.amount;
        if (r.type === 'vehicle' || r.type === 'manual' || rarity === 'legendary') addWinner(r, source, rarity);
    });
}

const items = [['water', 'Air'], ['burger', 'Burger'], ['firstaid', 'P3K'], ['repairkit', 'Kit Reparasi'], ['armour', 'Rompi Pelindung'], ['bandage', 'Perban'], ['goldbar', 'Emas Batangan'], ['diamond', 'Berlian'], ['phone', 'Telepon'], ['lockpick', 'Lockpick']].map(([name, label]) => ({ name, label }));
const vehicles = [['sultan', 'Karin Sultan'], ['kuruma', 'Karin Kuruma'], ['pcj', 'Shitzu PCJ 600'], ['bati', 'Pegassi Bati 801'], ['comet2', 'Pfister Comet'], ['elegy2', 'Annis Elegy RH8']].map(([model, label]) => ({ model, label }));
const toDisplay = (r) => {
    if (r.type === 'item') return it(r.name, items.find((x) => x.name === r.name)?.label || r.name, r.count);
    if (r.type === 'vehicle') return veh(r.model, vehicles.find((x) => x.model === r.model)?.label || r.model);
    if (r.type === 'money') return money(r.amount);
    if (r.type === 'coins') return coins(r.amount);
    return { ...manual, label: r.label };
};
const adminShop = () => state.shop.map((e) => ({ ...clone(e), display: e.rewards, active: true, sort: e.id }));
const bal = () => clone(state.balance);

const api = {
    state: () => ({ ...clone(state), now: now() }),
    pull: ({ count }) => {
        const cost = count === 10 ? 135 : 15;
        if (state.balance.coins < cost) return { ok: false, msg: `Koin tidak cukup (butuh ${cost}).` };
        state.balance.coins -= cost;
        let pity = state.balance.pity;
        const results = [];
        for (let i = 0; i < count; i++) {
            pity += 1;
            const rid = rollRarity(pity);
            if (rid === 'legendary') pity = 0;
            let reward;
            if (rid === 'legendary') {
                const assets = pool.legendary.filter((x) => x.type === 'vehicle' || x.type === 'manual');
                const others = pool.legendary.filter((x) => !(x.type === 'vehicle' || x.type === 'manual'));
                if (weekAssets < 1 && Math.random() * 100 < [100, 50, 25][assetTier]) { weekAssets += 1; assetTier = Math.min(2, assetTier + 1); reward = pick(assets); } else reward = pick(others);
            } else reward = pick(pool[rid]);
            results.push({ ...reward, rarity: rid });
        }
        if (count === 10 && !results.some((r) => rank[r.rarity] >= 3)) results[9] = { ...pick(pool.rare), rarity: 'rare' };
        state.balance.pity = pity;
        results.forEach((r) => receive([r], 'gacha', r.rarity));
        return { ok: true, results, balance: bal() };
    },
    buy: ({ id }) => {
        const e = state.shop.find((x) => x.id === id);
        if (state.balance.coins < e.price) return { ok: false, msg: 'Koin tidak cukup.' };
        state.balance.coins -= e.price;
        e.bought += 1;
        receive(e.rewards, 'shop');
        return { ok: true, msg: `${e.label} berhasil dibeli!`, balance: bal(), shop: clone(state.shop) };
    },
    daily: () => {
        if (state.daily.claimed) return { ok: false, msg: 'Hadiah hari ini sudah diklaim. Kembali besok!' };
        state.daily.claimed = true;
        receive(state.daily.days[state.daily.day - 1], 'daily');
        return { ok: true, msg: `Hadiah Hari ${state.daily.day} diklaim!`, balance: bal(), daily: clone(state.daily) };
    },
    checkCode: ({ code }) => {
        const c = codes.find((x) => x.code === code.toUpperCase().replace(/\s/g, ''));
        if (!c) return { ok: false, msg: 'Kode referral tidak ditemukan.' };
        if (c.expiresAt <= now()) return { ok: false, msg: 'Kode referral expired.', status: 'expired' };
        if (claimed.has(c.code)) return { ok: false, msg: 'Kode ini sudah kamu klaim.', status: 'claimed' };
        if (c.maxUses && c.uses >= c.maxUses) return { ok: false, msg: 'Kuota kode ini sudah habis.' };
        return { ok: true, code: c.code, rewards: c.rewards, expiresAt: c.expiresAt };
    },
    claimCode: ({ code }) => {
        const res = api.checkCode({ code });
        if (!res.ok) return res;
        const c = codes.find((x) => x.code === code);
        claimed.add(c.code);
        c.uses += 1;
        receive(c.rewards, 'code');
        return { ok: true, msg: 'Hadiah berhasil diklaim!', balance: bal() };
    },
    adminBoot: () => ({ ok: true, items, vehicles, players: [{ id: 1, name: me.name, cid: me.cid }, { id: 4, name: 'Siti Aminah', cid: 'F7654321' }, { id: 9, name: 'Andi Wijaya', cid: 'F5550123' }] }),
    adminCodes: () => ({ ok: true, codes: clone(codes) }),
    adminSaveCode: ({ code, rewards, minutes, maxUses }) => {
        code = (code || '').toUpperCase().replace(/\s/g, '');
        if (!/^[A-Z0-9_-]{3,24}$/.test(code)) return { ok: false, msg: 'Kode 3-24 karakter: huruf, angka, - atau _.' };
        if (!rewards.length) return { ok: false, msg: 'Hadiah masih kosong.' };
        if (!(minutes >= 1)) return { ok: false, msg: 'Masa berlaku tidak valid.' };
        const old = codes.findIndex((x) => x.code === code);
        if (old >= 0 && codes[old].expiresAt > now()) return { ok: false, msg: 'Kode ini masih aktif. Hapus dulu atau pakai kode lain.' };
        if (old >= 0) { codes.splice(old, 1); claimed.delete(code); }
        codes.unshift({ code, rewards: rewards.map(toDisplay), expiresAt: now() + minutes * 60, maxUses, uses: 0, createdBy: 'Admin (F0000001)' });
        return { ok: true, msg: `Kode ${code} dibuat, berlaku ${minutes} menit.`, codes: clone(codes) };
    },
    adminDeleteCode: ({ code }) => {
        codes.splice(codes.findIndex((x) => x.code === code), 1);
        return { ok: true, msg: `Kode ${code} dihapus.`, codes: clone(codes) };
    },
    adminShop: () => ({ ok: true, shop: adminShop() }),
    adminSaveShop: (d) => {
        if (!d.label.trim()) return { ok: false, msg: 'Nama barang kosong.' };
        if (!d.rewards.length) return { ok: false, msg: 'Hadiah masih kosong.' };
        let e = state.shop.find((x) => x.id === d.id);
        if (!e) { e = { id: Math.max(...state.shop.map((x) => x.id)) + 1, bought: 0 }; state.shop.push(e); }
        Object.assign(e, { label: d.label, description: d.description, category: d.category, rewards: d.rewards.map(toDisplay), price: d.price, limit: d.limit,
            expiresAt: d.minutes > 0 ? now() + d.minutes * 60 : d.minutes < 0 ? e.expiresAt || 0 : 0 });
        return { ok: true, msg: `"${d.label}" disimpan.`, id: e.id, shop: adminShop() };
    },
    adminDeleteShop: ({ id }) => {
        state.shop.splice(state.shop.findIndex((x) => x.id === id), 1);
        return { ok: true, msg: 'Barang dihapus.', shop: adminShop() };
    },
    adminGive: ({ target, amount }) => {
        if (!amount) return { ok: false, msg: 'Jumlah tidak valid.' };
        if (target === '1' || target.toUpperCase() === me.cid) state.balance.coins = Math.max(0, state.balance.coins + amount);
        return { ok: true, msg: `${amount > 0 ? '+' : ''}${amount} Koin untuk ${target || '?'}.` };
    },
    adminWinners: ({ status }) => ({ ok: true, weekAssets, weekCap: 1, winners: clone(status === 'menunggu' ? winners.filter((w) => w.status === 'menunggu') : winners) }),
    adminMarkWinner: ({ id, status }) => {
        const w = winners.find((x) => x.id === id);
        Object.assign(w, { status: 'selesai', handled_by: 'Admin (F0000001)' });
        return { ok: true, msg: 'Ditandai sudah diberikan.', ...api.adminWinners({ status }) };
    },
};

window.fetch = async (url, opts) => {
    const name = url.split('/').pop();
    const body = opts && opts.body ? JSON.parse(opts.body) : {};
    if (name === 'close') setTimeout(() => reopen.classList.remove('hidden'), 50);
    const res = api[name] ? api[name](body) : { ok: true };
    await new Promise((r) => setTimeout(r, 120)); // jeda seperti server
    return { json: async () => res };
};

const reopen = document.createElement('button');
reopen.className = 'primary b-lg hidden';
reopen.textContent = '/hadiah';
reopen.style.cssText = 'position:fixed;left:50%;top:50%;transform:translate(-50%,-50%);width:200px';
reopen.onclick = () => { reopen.classList.add('hidden'); window.postMessage({ action: 'open', data: api.state() }, '*'); };
document.body.appendChild(reopen);

const note = document.createElement('div');
note.textContent = 'MOCKUP · data tiruan · coba kode HALLOWEEN2026 (aktif) / HALLOWEEN2025 (expired)';
note.style.cssText = 'position:fixed;left:12px;bottom:10px;font:600 12px Inter,sans-serif;color:#fff;opacity:.7';
document.body.appendChild(note);

window.postMessage({ action: 'open', data: api.state() }, '*');
