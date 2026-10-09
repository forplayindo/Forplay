// Panel "Cek Pasien". Data & semua keputusan dari server; di sini hanya tampilan.
const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'f_ambulancejob';
const post = (name, data) => fetch(`https://${RES}/${name}`, { method: 'POST', body: JSON.stringify(data || {}) })
    .then(r => r.json()).catch(() => null);

const ITEMS = {
    bandage:     { label: 'Bandage',          ico: '🩹' },
    hemostatic:  { label: 'Hemostatic Gauze', ico: '🧻' },
    splint:      { label: 'Splint',           ico: '🦴' },
    suture:      { label: 'Suture Kit',       ico: '🧵' },
    firstaid:    { label: 'First Aid Kit',    ico: '🧰' },
    painkillers: { label: 'Painkillers',      ico: '💊' },
    bloodBag:    { label: 'Blood Bag',        ico: '🩸' },
    crutch:      { label: 'Crutch',           ico: '🦯' },
};
const EFFECT = {
    skin: ['', 'Nyeri ringan', 'Nyeri, kadang pandangan kabur', 'Luka terbuka, pandangan kabur', 'Luka dalam, bisa pingsan'],
    limb: ['', 'Nyeri ringan', 'Gerak sedikit terganggu', 'Kemungkinan retak', 'Patah, tidak bisa dipakai normal'],
};

let cfg = null;       // dari Lua: bodyParts, severityLabels, bleedLabels, heavyBleed, critical
let st = null;        // status pasien dari server
let sel = null;       // area terpilih / 'BLEED'
let timer = null;
let tab = 'care';     // 'care' | 'bill'
let bill = null;      // { pending: [...], unpaid: [...] } dari server
let billSel = {};     // id layanan -> { on, price }
let billMsg = null;   // { ok, text }
let billMode = 'direct'; // 'direct' (invoice HP) | 'kasir' (bayar di kasir)
const rp = n => 'Rp ' + Number(n || 0).toLocaleString('id-ID');

const $ = id => document.getElementById(id);
const sevLabel = s => s ? cfg.severityLabels[s - 1] : 'Sehat';
const bleedLabel = l => l ? cfg.bleedLabels[l - 1] : 'Tidak berdarah';
const partLabel = p => (cfg.bodyParts[p] || {}).label || p;
const fmt = s => `${String(Math.floor(s / 60)).padStart(2, '0')}:${String(s % 60).padStart(2, '0')}`;

function injuryMap() {
    const m = {};
    (st.injuries || []).forEach(i => { m[i.part] = i; });
    return m;
}
function needFor(part, sev) {
    if (!sev) return null;
    if (sev <= 2) return 'bandage';
    return (cfg.bodyParts[part] || {}).kind === 'limb' ? 'splint' : 'suture';
}
const bleedNeed = () => !st.bleed ? null : (st.bleed >= cfg.heavyBleed ? 'hemostatic' : 'bandage');
// stok obat = Stok Gudang; tanpa Emergency Bag yang berlaku tidak ada yang bisa dipakai
const have = k => (st.bag && st.stock && st.stock[k]) || 0;
const bagMsg = () => st.bag ? '' : '<div class="msg">🎒 Kamu tidak membawa <b>Emergency Bag</b> yang masih berlaku. Ambil di Armory untuk bisa menangani pasien.</div>';
const lackText = k => st.bag ? `Stok ${ITEMS[k].label} di gudang habis` : 'Butuh Emergency Bag';

// ---------------------------------------------------------------- peta tubuh
// Gambar anatomi body.png (459x612); poligon area di-mask siluet body-mask.png.
(function buildBody() {
    const NS = 'http://www.w3.org/2000/svg';
    const W = 459, H = 612, CX = 229.5;
    const CENTER = {
        HEAD: [[180,-40],[279,-40],[279,116],[180,116]],
        NECK: [[190,116],[269,116],[269,134],[190,134]],
        UPPER_BODY: [[200,126],[259,126],[290,138],[281,198],[278,262],[181,262],[178,198],[169,138]],
        LOWER_BODY: [[181,262],[278,262],[292,330],[229.5,345],[167,330]],
    };
    const SIDE = {
        LEG: [[150,320],[167,330],[229.5,345],[229.5,555],[150,555]],
        FOOT: [[140,555],[229.5,555],[229.5,620],[140,620]],
        ARM: [[-20,120],[205,120],[178,198],[140,306],[-20,306]],
        HAND: [[-20,306],[170,306],[170,336],[-20,336]],
        FINGER: [[-20,336],[170,336],[170,380],[-20,380]],
    };
    const SPINE = [[225,134],[234,134],[234,330],[225,330]];

    const svg = $('body');
    svg.setAttribute('viewBox', '78 22 303 580');
    const el = (tag, attrs, parent) => {
        const e = document.createElementNS(NS, tag);
        for (const k in attrs) e.setAttribute(k, attrs[k]);
        (parent || svg).appendChild(e);
        return e;
    };
    const pts = p => p.map(q => q.join(',')).join(' ');
    const mir = p => p.map(([x, y]) => [CX * 2 - x, y]);

    const defs = el('defs', {});
    const mask = el('mask', { id: 'bodyMask', maskUnits: 'userSpaceOnUse', x: 0, y: 0, width: W, height: H, style: 'mask-type:alpha' }, defs);
    el('image', { href: 'body-mask.png', x: 0, y: 0, width: W, height: H }, mask);

    el('image', { href: 'body.png', x: 0, y: 0, width: W, height: H, style: 'pointer-events:none' });
    el('text', { class: 'slabel', x: 100, y: 120 }).textContent = 'KA';
    el('text', { class: 'slabel', x: 359, y: 120 }).textContent = 'KI';

    // warna luka di atas gambar (blend) supaya detail organ tetap terlihat; kiri layar = kanan pasien
    const regions = el('g', { mask: 'url(#bodyMask)', class: 'regions' });
    const add = (p, poly) => el('polygon', { class: 'part', 'data-p': p, points: pts(poly) }, regions);
    ['LEG', 'FOOT', 'ARM', 'HAND', 'FINGER'].forEach(k => { add('R' + k, SIDE[k]); add('L' + k, mir(SIDE[k])); });
    ['LOWER_BODY', 'UPPER_BODY', 'NECK', 'HEAD'].forEach(k => add(k, CENTER[k]));
    add('SPINE', SPINE);
    el('g', { id: 'selLayer', mask: 'url(#bodyMask)', style: 'pointer-events:none' });

    svg.querySelectorAll('.part').forEach(p => {
        p.addEventListener('click', () => select(p.dataset.p));
        p.addEventListener('mouseenter', () => {
            if (!st) return;
            const inj = injuryMap()[p.dataset.p];
            $('hover').textContent = `${partLabel(p.dataset.p)} · ${sevLabel(inj ? inj.severity : 0)}`;
        });
        p.addEventListener('mouseleave', () => { $('hover').innerHTML = '&nbsp;'; });
    });
})();

// ---------------------------------------------------------------- render
function render() {
    if (!st || !cfg) return;
    const inj = injuryMap();

    document.querySelectorAll('#body .part').forEach(el => {
        const sev = inj[el.dataset.p] ? inj[el.dataset.p].severity : 0;
        el.setAttribute('fill', sev ? `var(--s${sev})` : 'transparent');
        el.classList.toggle('hurt', sev > 0);
        el.classList.toggle('s4', sev === 4);
    });
    const selLayer = $('selLayer');
    selLayer.innerHTML = '';
    document.querySelectorAll(`#body .part[data-p="${sel}"]`).forEach(el => {
        const o = el.cloneNode(); o.setAttribute('class', 'selo'); selLayer.appendChild(o);
    });

    $('sub').textContent = `${st.name} · ID ${st.id}`;
    renderState();

    const count = (st.injuries || []).length;
    $('vitals').innerHTML = [
        ['Kesadaran', st.down ? 'Tidak sadar' : 'Sadar', st.down ? 'bad' : 'good'],
        ['Pendarahan', bleedLabel(st.bleed), st.bleed >= cfg.heavyBleed ? 'bad' : st.bleed ? 'warn' : 'good'],
        ['Darah', st.down ? (st.transfused ? 'Ditransfusi' : 'Kritis') : st.blood + '%',
            st.down ? (st.transfused ? 'good' : 'bad') : st.blood < cfg.critical ? 'bad' : st.blood < 60 ? 'warn' : 'good'],
        ['Luka', count ? count + ' area' : 'Tidak ada', count ? 'warn' : 'good'],
    ].map(([k, v, c]) => `<div class="vital ${c}"><small>${k}</small><b>${v}</b></div>`).join('');

    const tb = document.querySelector('.tabs [data-tab="bill"]');
    tb.innerHTML = '🧾 Tagihan' + (st.pendingBill ? `<span class="badge">${st.pendingBill}</span>` : '');

    if (tab !== 'care') return;
    if (sel === 'BLEED') renderBleed();
    else if (sel) renderDetail(sel);
    else renderSummary();
    renderFooter();
}

// ---------------------------------------------------------------- tab Tagihan
function setTab(t) {
    tab = t;
    document.querySelectorAll('.tabs button').forEach(b => b.classList.toggle('on', b.dataset.tab === t));
    $('vitals').classList.toggle('hidden', t !== 'care');
    $('content').classList.toggle('hidden', t !== 'care');
    $('care-footer').classList.toggle('hidden', t !== 'care');
    $('billing').classList.toggle('hidden', t !== 'bill');
    if (t === 'bill') { billMsg = null; loadBilling(); } else render();
}

async function loadBilling() {
    $('billing').innerHTML = '<div class="note">Memuat tagihan...</div>';
    applyBilling(await post('billingGet'));
}

function applyBilling(res) {
    if (!res || res.error) {
        billMsg = { ok: false, text: (res && res.error) || 'Gagal memuat tagihan' };
        if (!bill) bill = { pending: [], unpaid: [] };
    } else {
        bill = res;
        const next = {};
        (bill.pending || []).forEach(s => { next[s.id] = billSel[s.id] || { on: true, price: s.price }; });
        billSel = next;
        if (res.sent) billMsg = { ok: true, text: res.mode === 'kasir'
            ? `Tagihan ${rp(res.sent)} masuk Kasir. Arahkan pasien membayar di kasir rumah sakit.`
            : `Tagihan ${rp(res.sent)} dikirim ke HP pasien (Bank > Invoices).` };
    }
    renderBilling();
}

const timeOf = ts => { const d = new Date(ts * 1000); return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`; };
const dateOf = ts => { const d = new Date(ts * 1000); return `${d.getDate()}/${d.getMonth() + 1} ${timeOf(ts)}`; };

function billTotal() {
    return (bill.pending || []).reduce((sum, s) => sum + (billSel[s.id] && billSel[s.id].on ? billSel[s.id].price : 0), 0);
}

function renderBilling() {
    if (tab !== 'bill' || !bill) return;
    const pend = bill.pending || [];
    let h = '';
    if (billMsg) h += `<div class="${billMsg.ok ? 'empty' : 'msg'}">${billMsg.text}</div>`;

    h += '<h3>Layanan belum ditagih</h3>';
    if (!pend.length) {
        h += '<div class="note">Belum ada layanan baru. Setiap tindakan di tab Perawatan otomatis tercatat di sini.</div>';
    } else {
        pend.forEach(s => {
            const v = billSel[s.id];
            h += `<div class="bill-row ${v.on ? '' : 'off'}">
                <input type="checkbox" data-chk="${s.id}" ${v.on ? 'checked' : ''}>
                <div class="name"><b>${s.label}</b><span>${s.emsName} · ${timeOf(s.at)} · normal ${rp(s.price)}</span></div>
                <div class="price">Rp <input type="number" min="0" max="${s.price}" step="1" value="${v.price}" data-price="${s.id}"></div>
                <button class="del" title="Hapus dari tagihan" data-del="${s.id}">✕</button></div>`;
        });
        h += `<div class="bill-total"><span>Total</span><strong id="bill-total">${rp(billTotal())}</strong></div>
            <div class="choose">
                ${bill.transfer ? `<button data-mode="direct" class="${billMode === 'direct' ? 'on' : ''}"><b>📱 Bayar Langsung</b><span>Invoice langsung ke HP pasien</span></button>` : ''}
                <button data-mode="kasir" class="${billMode === 'kasir' || !bill.transfer ? 'on' : ''}"><b>🧾 Bayar di Kasir</b><span>Tagihan muncul di Kasir rumah sakit</span></button>
            </div>
            <button class="primary" id="bill-send">Kirim Tagihan</button>
            <div class="note">Harga boleh diturunkan (diskon), tidak bisa lebih dari harga normal.</div>`;
    }

    const unpaid = bill.unpaid || [];
    if (unpaid.length) {
        h += '<h3>Tagihan pasien yang belum dibayar</h3>';
        unpaid.forEach(u => { h += `<div class="unpaid-row"><span>#${u.id} · ${dateOf(u.created_at)}</span><b>${rp(u.total)}</b></div>`; });
        h += '<div class="note">Bisa ditagih paksa dari bank pasien lewat Kasir EMS atau MDT > Tagihan.</div>';
    }

    const el = $('billing');
    el.innerHTML = h;
    el.querySelectorAll('[data-chk]').forEach(c => c.onchange = () => {
        billSel[c.dataset.chk].on = c.checked;
        c.closest('.bill-row').classList.toggle('off', !c.checked);
        $('bill-total').textContent = rp(billTotal());
    });
    el.querySelectorAll('[data-price]').forEach(inp => inp.oninput = () => {
        const s = pend.find(x => String(x.id) === inp.dataset.price);
        let n = Math.floor(Number(inp.value));
        if (!Number.isFinite(n) || n < 0) n = 0;
        if (n > s.price) { n = s.price; inp.value = n; }
        billSel[s.id].price = n;
        $('bill-total').textContent = rp(billTotal());
    });
    el.querySelectorAll('[data-del]').forEach(b => b.onclick = async () => {
        billMsg = null;
        applyBilling(await post('billingDiscard', { id: Number(b.dataset.del) }));
    });
    el.querySelectorAll('[data-mode]').forEach(b => b.onclick = () => { billMode = b.dataset.mode; renderBilling(); });
    const send = $('bill-send');
    if (send) send.onclick = async () => {
        const lines = pend.filter(s => billSel[s.id].on).map(s => ({ id: s.id, price: billSel[s.id].price }));
        if (!lines.length) { billMsg = { ok: false, text: 'Pilih minimal satu layanan' }; return renderBilling(); }
        send.disabled = true;
        billMsg = null;
        applyBilling(await post('billingSend', { lines, mode: bill.transfer ? billMode : 'kasir' }));
    };
}

function renderState() {
    const s = $('state');
    s.className = 'state-pill ' + (st.down ? 'down' : 'ok');
    s.textContent = st.down ? (st.remaining != null ? `Tergeletak · ${fmt(st.remaining)}` : 'Tergeletak') : 'Sadar';
}

function needHtml(key) {
    const it = ITEMS[key], n = have(key);
    return `<div class="item-need ${n < 1 ? 'none' : ''}">
        <div class="ico">${it.ico}</div>
        <div class="name"><b>${it.label}</b> ×1<br><small>Stok gudang</small></div>
        <div class="stock">${n}</div></div>`;
}

function recoveryHtml() {
    if (!st.recovery) return '';
    const mins = Math.max(1, Math.ceil(st.recovery / 60));
    const btn = st.hasCrutch ? ''
        : `<button class="primary small" id="give-crutch" ${have('crutch') ? '' : 'disabled'}>
            ${have('crutch') ? `Beri Crutch (stok ${have('crutch')})` : lackText('crutch')}</button>`;
    return `<div class="recovery">
        <div class="rec-top"><span class="rec-ico">🦯</span>
            <div class="name"><b>Masa pemulihan · ${mins} menit lagi</b>
            <span>${st.hasCrutch ? 'Pasien sudah punya Crutch' : 'Pasien belum punya Crutch (wajib selama pemulihan)'}</span></div></div>
        ${btn}</div>`;
}

function renderSummary() {
    let h = bagMsg() + recoveryHtml() + '<h3>Ringkasan</h3>';
    if (st.bleed) {
        const n = bleedNeed();
        h += `<button class="row" data-sel="BLEED"><span class="dot" style="background:var(--s${Math.min(4, st.bleed + 1)})"></span>
            <span class="name">🩸 ${bleedLabel(st.bleed)}<span>Darah terus berkurang, tangani dulu</span></span>
            <span class="need">Butuh<br><b>${ITEMS[n].ico} ${ITEMS[n].label}</b></span></button>`;
    }
    const list = [...(st.injuries || [])].sort((a, b) => b.severity - a.severity);
    if (!list.length && !st.bleed) h += '<div class="empty">✔ Pasien tidak memiliki luka</div>';
    list.forEach(i => {
        const n = needFor(i.part, i.severity), def = cfg.bodyParts[i.part] || {};
        const tag = i.surgery ? (i.stabilized ? ' · <b style="color:var(--red)">distabilkan, perlu operasi</b>' : ' · <b style="color:var(--red)">perlu operasi</b>') : '';
        const need = i.surgery && i.stabilized
            ? '<span class="need">Butuh<br><b>⚕️ Operasi</b></span>'
            : `<span class="need">${i.surgery ? 'Stabilkan' : 'Butuh'}<br><b>${ITEMS[n].ico} ${ITEMS[n].label}</b></span>`;
        h += `<button class="row" data-sel="${i.part}"><span class="dot" style="background:var(--s${i.severity})"></span>
            <span class="name">${partLabel(i.part)} · ${sevLabel(i.severity)}<span>Penyebab: ${i.cause}${def.limp && i.severity >= 2 ? ' · bikin pincang' : ''}${tag}</span></span>
            ${need}</button>`;
    });
    $('content').innerHTML = h;
    $('content').querySelectorAll('[data-sel]').forEach(b => b.addEventListener('click', () => select(b.dataset.sel)));
    const gc = $('give-crutch');
    if (gc) gc.onclick = () => post('action', { action: 'crutch' });
}

function sevBar(n, color) {
    return `<div class="sev-bar">${[1, 2, 3, 4].map(i => `<div style="${i <= n ? `background:${color}` : ''}"></div>`).join('')}</div>`;
}

function renderBleed() {
    const n = bleedNeed();
    if (!n) { sel = null; return renderSummary(); }
    $('content').innerHTML = bagMsg() + `<div class="detail">
        <div class="top"><h2>🩸 Pendarahan</h2><button class="back" id="back">← Ringkasan</button></div>
        ${sevBar(st.bleed, `var(--s${Math.min(4, st.bleed + 1)})`)}
        <div class="kv"><span>Tingkat</span><b>${bleedLabel(st.bleed)}</b></div>
        <div class="kv"><span>Efek</span><b>${st.bleed >= cfg.heavyBleed ? 'Darah cepat habis, bisa pingsan' : 'Darah berkurang perlahan'}</b></div>
        <h3>Penanganan</h3>${needHtml(n)}
        ${have(n) ? '' : `<div class="msg">${lackText(n)}</div>`}
        <button class="primary" id="do" ${have(n) ? '' : 'disabled'}>Hentikan Pendarahan</button></div>`;
    $('back').onclick = () => select(null);
    $('do').onclick = () => post('action', { action: 'bleed' });
}

function renderDetail(part) {
    const i = injuryMap()[part], sev = i ? i.severity : 0, def = cfg.bodyParts[part] || {};
    let h = bagMsg() + `<div class="detail">
        <div class="top"><h2>${partLabel(part)}</h2><button class="back" id="back">← Ringkasan</button></div>
        ${sevBar(sev, `var(--s${sev})`)}
        <div class="kv"><span>Kondisi</span><b>${sevLabel(sev)}</b></div>`;
    if (!sev) {
        $('content').innerHTML = h + '<div class="empty">✔ Tidak ada luka di area ini</div></div>';
        $('back').onclick = () => select(null);
        return;
    }
    const n = needFor(part, sev);
    h += `<div class="kv"><span>Penyebab</span><b>${i.cause}</b></div>
        <div class="kv"><span>Efek</span><b>${EFFECT[def.kind || 'skin'][sev]}${def.limp && sev >= 2 ? ' · pincang' : ''}</b></div>`;
    if (i.surgery && i.stabilized) {
        $('content').innerHTML = h + `<div class="msg">⚕️ Luka ini sudah distabilkan dan <b>perlu operasi</b> oleh Dokter di meja operasi.
            Sampai dioperasi, darah pasien maksimal 60% dan luka bisa berdarah lagi.</div></div>`;
        $('back').onclick = () => select(null);
        return;
    }
    h += `<h3>Penanganan</h3>${needHtml(n)}
        ${i.surgery ? '<div class="msg">⚕️ Luka ini <b>perlu operasi</b>. Item ini hanya menstabilkan, lalu bawa pasien ke meja operasi.</div>' : ''}
        ${!i.surgery && n === 'splint' && def.limp ? '<div class="note">🦯 Setelah dipasang Splint, pasien masuk masa pemulihan dan wajib memakai Crutch.</div>' : ''}
        ${have(n) ? '' : `<div class="msg">${lackText(n)}</div>`}
        <button class="primary" id="do" ${have(n) ? '' : 'disabled'}>${i.surgery ? 'Stabilkan' : 'Obati'} ${partLabel(part)}</button></div>`;
    $('content').innerHTML = h;
    $('back').onclick = () => select(null);
    $('do').onclick = () => post('action', { action: 'part', part });
}

function allCost() {
    const cost = {};
    const add = k => { if (k) cost[k] = (cost[k] || 0) + 1; };
    add(bleedNeed());
    (st.injuries || []).forEach(i => { if (!(i.surgery && i.stabilized)) add(needFor(i.part, i.severity)); });
    return cost;
}

function renderFooter() {
    const pk = $('btn-pk'), all = $('btn-all'), rev = $('btn-rev');

    pk.disabled = st.down || !have('painkillers');
    $('pk-sub').textContent = st.down ? 'Pasien tidak sadar' : !st.bag ? 'Butuh Emergency Bag' : `Tahan nyeri · stok ${have('painkillers')}`;

    const cost = allCost(), keys = Object.keys(cost);
    const enough = keys.every(k => have(k) >= cost[k]);
    all.disabled = !keys.length || !enough;
    $('all-sub').textContent = !keys.length ? 'Tidak ada yang diobati'
        : keys.map(k => `${ITEMS[k].ico}${cost[k]}`).join(' ') + (enough ? '' : st.bag ? ' · stok kurang' : ' · butuh tas');

    const tf = $('btn-tf');
    const needBlood = st.down ? !st.transfused : st.blood < cfg.critical;
    tf.disabled = !needBlood || !have('bloodBag');
    $('tf-sub').textContent = st.transfused ? 'Sudah ditransfusi'
        : !needBlood ? `Darah ≥ ${cfg.critical}%` : !have('bloodBag') ? lackText('bloodBag') : `🩸 ×1 · stok ${have('bloodBag')}`;

    const heavy = st.bleed >= cfg.heavyBleed;
    rev.disabled = !st.down || !have('firstaid') || heavy;
    $('rev-sub').textContent = !st.down ? 'Pasien sadar'
        : heavy ? 'Hentikan pendarahan dulu' : !have('firstaid') ? lackText('firstaid') : `🧰 First Aid Kit ×1 · stok ${have('firstaid')}`;
}

function select(p) { sel = p; render(); }

// ---------------------------------------------------------------- tombol
$('btn-pk').onclick = () => post('action', { action: 'painkiller' });
$('btn-all').onclick = () => post('action', { action: 'all' });
$('btn-tf').onclick = () => post('action', { action: 'transfusion' });
$('btn-rev').onclick = () => post('action', { action: 'revive' });
$('close').onclick = () => post('close');
document.querySelectorAll('.tabs button').forEach(b => b.onclick = () => setTab(b.dataset.tab));
document.addEventListener('keyup', e => { if (e.key === 'Escape' && !$('app').classList.contains('hidden')) post('close'); });

// countdown tergeletak berjalan di sini; nilai asli disegarkan server tiap 2 detik
function startTimer() {
    clearInterval(timer);
    timer = setInterval(() => {
        if (st && st.down && st.remaining > 0) { st.remaining--; renderState(); }
    }, 1000);
}

window.addEventListener('message', e => {
    const d = e.data || {};
    if (d.action === 'open') {
        if (d.config) cfg = d.config;
        let fresh = false;
        if (d.status) {
            if (!st || st.id !== d.status.id) { sel = null; fresh = true; }
            st = d.status;
        }
        if (!st || !cfg) return;
        $('app').classList.remove('hidden');
        if (fresh) { bill = null; billSel = {}; setTab('care'); } else render();
        if (tab === 'bill') loadBilling(); // tindakan baru bisa menambah layanan
        startTimer();
    } else if (d.action === 'update') {
        if (!d.status) return;
        st = d.status;
        render();
    } else if (d.action === 'hide') {
        $('app').classList.add('hidden');
    } else if (d.action === 'close') {
        $('app').classList.add('hidden');
        clearInterval(timer);
        st = null; sel = null; bill = null; billSel = {}; tab = 'care';
    }
});
