// f_customs NUI: warga memilih modifikasi sendiri (preview langsung di kendaraan), lalu
// "Selesai Modifikasi" -> tagihan ke kasir bengkel. Harga di sini PERKIRAAN; harga final dari server.
(() => {
    const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'f_customs';
    const post = (name, data) => fetch(`https://${RES}/${name}`, { method: 'POST', body: JSON.stringify(data || {}) })
        .then(r => r.json()).catch(() => null);
    const $ = id => document.getElementById(id);
    const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const money = n => 'Rp ' + Number(n || 0).toLocaleString('id-ID');
    const clone = v => JSON.parse(JSON.stringify(v ?? null));
    const same = (a, b) => JSON.stringify(a ?? null) === JSON.stringify(b ?? null);
    const rgbCss = c => c ? `rgb(${c.r},${c.g},${c.b})` : 'transparent';

    let I = null, C = null, O = null, cur = null;
    const cart = new Map();
    let cat = 'perf', sub = null, paintTab = 'color1', paintGroup = 'Classic', wheelType = null, wheelOpts = null;

    const CATS = [
        ['perf', '⚙️', 'Performa'], ['body', '🚗', 'Bodi'], ['paint', '🎨', 'Cat'], ['wheel', '🛞', 'Velg'],
        ['light', '💡', 'Lampu'], ['interior', '💺', 'Interior'], ['misc', '✨', 'Lainnya'],
    ];
    const PAINT_TABS = [['color1', 'Utama'], ['color2', 'Kedua'], ['pearlescentColor', 'Pearl'], ['wheelColor', 'Velg'], ['interiorColor', 'Interior'], ['dashboardColor', 'Dashboard']];
    const GROUP_LABEL = { Classic: 'Metalik', Matte: 'Matte', Metal: 'Metal', Worn: 'Kusam', Chameleon: 'Chameleon' };
    const LEVELS = ['modEngine', 'modBrakes', 'modTransmission', 'modSuspension', 'modArmor'];

    const locked = () => !!(I.active && !I.free);
    const canSelect = () => !locked();

    // ------------------------------------------------------------ harga perkiraan (cermin server)
    const paintCode = v => v >= I.chameleonFrom ? 'paint:Chameleon' : 'paint:' + (I.paint[String(v)] || 'Classic');
    function est(id, p) {
        const P = I.prices;
        if (LEVELS.includes(id)) { const v = p[id]; return v < 0 ? 0 : (P[`${id}:${Math.min(v + 1, I.maxLevel[id] || 1)}`] || 0); }
        if (id === 'modTurbo') return p.modTurbo ? (P.modTurbo || 0) : 0;
        if (id.startsWith('extra:')) return P.extra || 0;
        if (id === 'color1' || id === 'color2') return P[paintCode(p[id])] || 0;
        if (I.codes[id]) { const v = p[id]; if (id !== 'windowTint' && typeof v === 'number' && v < 0) return 0; return P[I.codes[id]] || 0; }
        if (id === 'wheels') return ['modFrontWheels', 'modBackWheels'].every(k => p[k] === undefined || p[k] < 0) ? 0 : (P.wheels || 0);
        if (id === 'tires') return Object.values(p).some(v => v) ? (P.customTires || 0) : 0;
        if (id === 'smoke') return (p.modSmokeEnabled ?? O.modSmokeEnabled) ? (P.tyreSmoke || 0) : 0;
        if (id === 'xenon') return (p.modXenon ?? O.modXenon) ? (P.xenon || 0) : 0;
        if (id === 'neon') {
            let c = 0;
            const was = O.neonEnabled || [];
            (p.neonEnabled || []).forEach((v, i) => { if (v && !was[i]) c += P.neon || 0; });
            if (p.neonColor && !same(p.neonColor, O.neonColor)) c += P.neonColor || 0;
            return c;
        }
        return 0;
    }

    // ------------------------------------------------------------ keranjang & preview
    function origOf(props) {
        const r = {};
        for (const k in props) {
            if (k === 'extras') { r.extras = {}; for (const e in props.extras) r.extras[e] = (O.extras || {})[e] ?? 0; }
            else r[k] = clone(O[k]);
        }
        return r;
    }

    function applyCur(props) {
        for (const k in props) {
            if (k === 'extras') { cur.extras = cur.extras || {}; Object.assign(cur.extras, props.extras); }
            else cur[k] = clone(props[k]);
        }
    }

    function setLine(id, label, props, desc) {
        if (!canSelect()) return;
        applyCur(props);
        post('preview', { props });
        if (same(origOf(props), props)) cart.delete(id);
        else cart.set(id, { id, label, desc, props: clone(props), price: est(id, props) });
        renderList(); renderCart();
    }

    function removeLine(id) {
        const line = cart.get(id);
        if (!line) return;
        const back = origOf(line.props);
        applyCur(back);
        post('preview', { props: back });
        cart.delete(id);
        if (id === 'wheels') wheelType = null;
        renderList(); renderCart();
    }

    // ------------------------------------------------------------ panel kiri
    function renderCats() {
        $('cats').innerHTML = CATS.map(([id, ic, name]) => `<button class="cat ${id === cat ? 'on' : ''}" data-c="${id}"><span>${ic}</span>${name}</button>`).join('');
        document.querySelectorAll('.cat').forEach(b => b.onclick = () => { cat = b.dataset.c; sub = null; wheelType = null; renderCats(); renderList(); });
    }

    const optLabel = (m, v) => (m.opts.find(o => o.v === v) || { l: v < 0 ? 'Standar' : `Varian ${v + 1}` }).l;
    const priceTxt = n => n ? money(n) : 'Gratis';

    function modRows(list) {
        return list.filter(m => !I.disabled[m.key]).map(m => {
            const inCart = cart.has(m.key);
            const val = m.toggle ? (cur[m.key] ? 'Aktif' : 'Mati') : optLabel(m, cur[m.key] ?? -1);
            return `<button class="row ${inCart ? 'sel' : ''}" data-m="${m.key}" ${!canSelect() && m.toggle ? 'disabled' : ''}>
                <span class="ic">${m.icon || '🔧'}</span><span class="tx"><b>${esc(m.label)}</b><small>${esc(val)}</small></span>
                ${inCart ? '<span class="dot"></span>' : ''}${m.toggle ? `<span class="pr">${priceTxt(est(m.key, { [m.key]: true }))}</span>` : '<span class="chev">›</span>'}</button>`;
        }).join('');
    }

    function bindModRows(el, list) {
        el.querySelectorAll('[data-m]').forEach(b => b.onclick = () => {
            const m = list.find(x => x.key === b.dataset.m);
            if (m.toggle) { const v = !cur[m.key]; return setLine(m.key, m.label, { [m.key]: v }, v ? 'Aktif' : 'Mati'); }
            sub = m; renderList();
        });
    }

    function renderOptions(el, m) {
        const was = O[m.key] ?? -1;
        el.innerHTML = m.opts.map(o => {
            const isCur = (cur[m.key] ?? -1) === o.v;
            const bars = m.level && o.v >= 0 ? `<span class="lvl">${m.opts.slice(1).map((_, k) => `<i class="${k <= o.v ? 'f' : ''}"></i>`).join('')}</span>` : '';
            return `<button class="row ${isCur ? 'sel' : ''}" data-v="${o.v}" ${canSelect() ? '' : 'disabled'}>
                <span class="tx"><b>${esc(o.l)} ${o.v === was ? '<span class="cur">· terpasang</span>' : ''}</b>${bars}</span>
                <span class="pr">${o.v === was ? '' : priceTxt(est(m.key, { [m.key]: o.v }))}</span></button>`;
        }).join('');
        el.querySelectorAll('[data-v]').forEach(b => b.onclick = () => {
            const v = Number(b.dataset.v);
            setLine(m.key, m.label, { [m.key]: v }, optLabel(m, v));
        });
    }

    function simpleList(el, key, label, items, idOf, nameOf) {
        const was = O[key];
        el.innerHTML = items.map(it => {
            const v = idOf(it), isCur = cur[key] === v;
            return `<button class="row ${isCur ? 'sel' : ''}" data-v="${v}" ${canSelect() ? '' : 'disabled'}>
                <span class="tx"><b>${esc(nameOf(it))} ${v === was ? '<span class="cur">· terpasang</span>' : ''}</b></span>
                <span class="pr">${v === was ? '' : priceTxt(est(key, { [key]: v }))}</span></button>`;
        }).join('');
        el.querySelectorAll('[data-v]').forEach(b => b.onclick = () => {
            const v = Number(b.dataset.v);
            setLine(key, label, { [key]: v }, nameOf(items.find(it => idOf(it) === v)));
        });
    }

    function renderList() {
        const el = $('list');
        const catName = CATS.find(c => c[0] === cat)[2];
        $('back').classList.toggle('hidden', !sub);
        $('crumb').textContent = sub ? `${catName} / ${sub.label}` : catName;
        if (sub && sub.render) return sub.render(el);
        if (sub) return renderOptions(el, sub);

        if (cat === 'perf' || cat === 'body' || cat === 'interior') {
            const list = C.mods[cat];
            el.innerHTML = modRows(list) || '<div class="note">Kendaraan ini tidak punya modifikasi di kategori ini.</div>';
            return bindModRows(el, list);
        }
        if (cat === 'paint') return renderPaint(el);
        if (cat === 'wheel') return renderWheel(el);
        if (cat === 'light') return renderLight(el);
        if (cat === 'misc') return renderMisc(el);
    }

    function renderPaint(el) {
        const key = paintTab;
        const main = key === 'color1' || key === 'color2';
        const groups = main ? Object.keys(C.paints) : (key === 'pearlescentColor' ? ['Classic', 'Chameleon'] : ['Classic']);
        if (!groups.includes(paintGroup)) paintGroup = groups[0];
        const tabLabel = PAINT_TABS.find(t => t[0] === key)[1];
        const was = O[key];
        el.innerHTML = `
            <div class="sub-tabs">${PAINT_TABS.map(([k, l]) => `<button class="${k === key ? 'on' : ''}" data-t="${k}">${l}</button>`).join('')}</div>
            ${groups.length > 1 ? `<div class="lbl"><span>Jenis</span></div><div class="sub-tabs">${groups.map(g => `<button class="${g === paintGroup ? 'on' : ''}" data-g="${g}">${GROUP_LABEL[g] || g}</button>`).join('')}</div>` : ''}
            <div class="lbl"><span>Warna ${tabLabel}</span><span>${priceTxt(est(key, { [key]: (C.paints[paintGroup][0] || {}).id ?? 0 }))}</span></div>
            <div class="chips">${C.paints[paintGroup].map(p => `<button class="chip ${cur[key] === p.id ? 'on' : ''}" data-p="${p.id}" ${canSelect() ? '' : 'disabled'}>
                ${esc(p.label)}${p.id === was ? ' ✓' : ''}</button>`).join('')}</div>`;
        el.querySelectorAll('[data-t]').forEach(b => b.onclick = () => { paintTab = b.dataset.t; renderList(); });
        el.querySelectorAll('[data-g]').forEach(b => b.onclick = () => { paintGroup = b.dataset.g; renderList(); });
        el.querySelectorAll('[data-p]').forEach(b => b.onclick = () => {
            const id = Number(b.dataset.p);
            const p = C.paints[paintGroup].find(x => x.id === id);
            setLine(key, `Warna ${tabLabel}`, { [key]: id }, `${GROUP_LABEL[paintGroup] || paintGroup} · ${p.label}`);
        });
    }

    function renderWheel(el) {
        const smokeOn = !!cur.modSmokeEnabled;
        const sc = cur.tyreSmokeColor || [255, 255, 255];
        el.innerHTML = `
            <div class="lbl"><span>Tipe Velg</span><span>${priceTxt(I.prices.wheels)}</span></div>
            <div class="chips">${C.wheelTypes.map(t => `<button class="chip ${wheelType === t.id ? 'on' : ''}" data-w="${t.id}">${esc(t.label)}${cur.wheels === t.id ? ' ✓' : ''}</button>`).join('')}</div>
            <div id="wlist"></div>
            <div class="lbl"><span>Ban</span></div>
            <div class="toggles">
                <div class="tg ${cur.modCustomTiresF ? 'on' : ''}" data-tg="tires"><span>Ban Custom</span><span class="sw-tg"></span></div>
                <div class="tg ${smokeOn ? 'on' : ''}" data-tg="smoke"><span>Asap Ban</span><span class="sw-tg"></span></div>
            </div>
            ${smokeOn ? `<div class="lbl"><span>Warna Asap</span></div><div class="chips">${C.smokes.map((s, i) => `<button class="chip ${same([s.r, s.g, s.b], sc) ? 'on' : ''}" data-s="${i}" ${canSelect() ? '' : 'disabled'}><i style="background:${rgbCss(s)}"></i>${esc(s.label)}</button>`).join('')}</div>` : ''}`;
        el.querySelectorAll('[data-w]').forEach(b => b.onclick = async () => {
            wheelType = Number(b.dataset.w);
            wheelOpts = await post('wheelList', { type: wheelType });
            renderList();
        });
        el.querySelector('[data-tg="tires"]').onclick = () => {
            if (!canSelect()) return;
            const v = !cur.modCustomTiresF;
            const p = C.bike ? { modCustomTiresF: v, modCustomTiresR: v } : { modCustomTiresF: v };
            setLine('tires', 'Ban Custom', p, v ? 'Aktif' : 'Mati');
        };
        el.querySelector('[data-tg="smoke"]').onclick = () => {
            if (!canSelect()) return;
            const v = !smokeOn;
            setLine('smoke', 'Asap Ban', { modSmokeEnabled: v, tyreSmokeColor: sc }, v ? 'Aktif' : 'Mati');
        };
        el.querySelectorAll('[data-s]').forEach(b => b.onclick = () => {
            const s = C.smokes[Number(b.dataset.s)];
            setLine('smoke', 'Asap Ban', { modSmokeEnabled: true, tyreSmokeColor: [s.r, s.g, s.b] }, s.label);
        });

        if (wheelType !== null && Array.isArray(wheelOpts)) {
            const wl = $('wlist');
            const typeLabel = (C.wheelTypes.find(t => t.id === wheelType) || {}).label || '';
            wl.innerHTML = `<div class="lbl"><span>${esc(typeLabel)}</span><span>${wheelOpts.length - 1} model</span></div>` + wheelOpts.map(o => {
                const isCur = cur.wheels === wheelType && (cur.modFrontWheels ?? -1) === o.v;
                const was = O.wheels === wheelType && (O.modFrontWheels ?? -1) === o.v;
                return `<button class="row ${isCur ? 'sel' : ''}" data-o="${o.v}" ${canSelect() ? '' : 'disabled'} style="margin-top:5px">
                    <span class="tx"><b>${esc(o.l)} ${was ? '<span class="cur">· terpasang</span>' : ''}</b></span>
                    <span class="pr">${was ? '' : priceTxt(o.v < 0 ? 0 : I.prices.wheels)}</span></button>`;
            }).join('');
            wl.querySelectorAll('[data-o]').forEach(b => b.onclick = () => {
                const v = Number(b.dataset.o);
                const p = { wheels: wheelType, modFrontWheels: v };
                if (C.bike) p.modBackWheels = v;
                setLine('wheels', 'Velg', p, `${typeLabel} · ${wheelOpts.find(o => o.v === v).l}`);
            });
        }
    }

    function renderLight(el) {
        const neon = (cur.neonEnabled || [false, false, false, false]).slice(0, 4);
        while (neon.length < 4) neon.push(false);
        const nc = cur.neonColor || [255, 0, 255];
        const xc = cur.xenonColor ?? 255;
        const sides = ['Kiri', 'Kanan', 'Depan', 'Belakang'];
        el.innerHTML = `
            <div class="lbl"><span>Lampu Xenon</span><span>${priceTxt(I.prices.xenon)}</span></div>
            <div class="toggles"><div class="tg ${cur.modXenon ? 'on' : ''}" data-x><span>Xenon</span><span class="sw-tg"></span></div></div>
            ${cur.modXenon ? `<div class="lbl"><span>Warna Xenon</span></div><div class="chips">${C.xenons.map(x => {
                const id = x.id < 0 ? 255 : x.id;
                return `<button class="chip ${xc === id ? 'on' : ''}" data-xc="${id}" ${canSelect() ? '' : 'disabled'}>${esc(x.label)}</button>`;
            }).join('')}</div>` : ''}
            <div class="lbl"><span>Neon</span><span>${priceTxt(I.prices.neon)} / sisi</span></div>
            <div class="toggles">${sides.map((s, i) => `<div class="tg ${neon[i] ? 'on' : ''}" data-n="${i}"><span>${s}</span><span class="sw-tg"></span></div>`).join('')}</div>
            <div class="lbl"><span>Warna Neon</span><span>${priceTxt(I.prices.neonColor)}</span></div>
            <div class="chips">${C.neonColors.map((c, i) => `<button class="chip ${same([c.r, c.g, c.b], nc) ? 'on' : ''}" data-nc="${i}" ${canSelect() ? '' : 'disabled'}><i style="background:${rgbCss(c)}"></i>${esc(c.label)}</button>`).join('')}</div>`;
        const xenonDesc = (on, id) => on ? ((C.xenons.find(x => (x.id < 0 ? 255 : x.id) === id) || { label: 'Aktif' }).label) : 'Mati';
        el.querySelector('[data-x]').onclick = () => {
            if (!canSelect()) return;
            const on = !cur.modXenon;
            setLine('xenon', 'Lampu Xenon', { modXenon: on, xenonColor: xc }, xenonDesc(on, xc));
        };
        el.querySelectorAll('[data-xc]').forEach(b => b.onclick = () => {
            const id = Number(b.dataset.xc);
            setLine('xenon', 'Lampu Xenon', { modXenon: true, xenonColor: id }, xenonDesc(true, id));
        });
        const neonDesc = (arr, color) => {
            const on = sides.filter((_, i) => arr[i]);
            const cl = (C.neonColors.find(c => same([c.r, c.g, c.b], color)) || {}).label;
            return on.length ? `${on.join(', ')}${cl ? ' · ' + cl : ''}` : 'Mati';
        };
        el.querySelectorAll('[data-n]').forEach(b => b.onclick = () => {
            if (!canSelect()) return;
            const arr = neon.slice(); arr[Number(b.dataset.n)] = !arr[Number(b.dataset.n)];
            setLine('neon', 'Neon', { neonEnabled: arr, neonColor: nc }, neonDesc(arr, nc));
        });
        el.querySelectorAll('[data-nc]').forEach(b => b.onclick = () => {
            const c = C.neonColors[Number(b.dataset.nc)];
            const col = [c.r, c.g, c.b];
            setLine('neon', 'Neon', { neonEnabled: neon, neonColor: col }, neonDesc(neon, col));
        });
    }

    function renderMisc(el) {
        const list = C.mods.misc;
        const tintName = v => (C.tints.find(t => t.id === v) || { label: v < 0 ? 'Tanpa' : `Tipe ${v}` }).label;
        const plateName = v => (C.plates.find(p => p.id === v) || { label: `Gaya ${v}` }).label;
        const extras = C.extras;
        el.innerHTML = `
            <button class="row ${cart.has('windowTint') ? 'sel' : ''}" data-sub="tint"><span class="ic">🕶️</span><span class="tx"><b>Kaca Film</b><small>${esc(tintName(cur.windowTint ?? -1))}</small></span><span class="chev">›</span></button>
            <button class="row ${cart.has('plateIndex') ? 'sel' : ''}" data-sub="plate"><span class="ic">🔖</span><span class="tx"><b>Gaya Plat</b><small>${esc(plateName(cur.plateIndex ?? 0))}</small></span><span class="chev">›</span></button>
            ${modRows(list)}
            ${extras.length ? `<div class="lbl"><span>Extra</span><span>${priceTxt(I.prices.extra)} / item</span></div>
                <div class="toggles">${extras.map(id => {
                    const on = ((cur.extras || {})[String(id)] ?? 1) === 0;
                    return `<div class="tg ${on ? 'on' : ''}" data-e="${id}"><span>Extra ${id}</span><span class="sw-tg"></span></div>`;
                }).join('')}</div>` : ''}`;
        bindModRows(el, list);
        el.querySelector('[data-sub="tint"]').onclick = () => {
            sub = { label: 'Kaca Film', render: e => simpleList(e, 'windowTint', 'Kaca Film', C.tints, t => t.id, t => t.label) };
            renderList();
        };
        el.querySelector('[data-sub="plate"]').onclick = () => {
            sub = { label: 'Gaya Plat', render: e => simpleList(e, 'plateIndex', 'Gaya Plat', C.plates, p => p.id, p => p.label) };
            renderList();
        };
        el.querySelectorAll('[data-e]').forEach(b => b.onclick = () => {
            if (!canSelect()) return;
            const id = b.dataset.e;
            const on = ((cur.extras || {})[id] ?? 1) === 0;
            setLine(`extra:${id}`, `Extra ${id}`, { extras: { [id]: on ? 1 : 0 } }, on ? 'Dilepas' : 'Dipasang');
        });
    }

    // ------------------------------------------------------------ panel kanan
    function statusHtml() {
        if (I.admin) return '<div class="status on">🛡️<div>Mode admin<small>Gratis & langsung terpasang</small></div></div>';
        if (I.free) return '<div class="status on">🔧<div>Fasilitas mekanik<small>Kendaraan milikmu · gratis & langsung terpasang</small></div></div>';
        if (I.active) return `<div class="status warn">⚠<div>Order kustom #${I.active.id} belum selesai<small>Selesaikan di kasir. Untuk membatalkan, minta mekanik menghapus tagihannya.</small></div></div>`;
        if (!I.owned) return '<div class="status off">🔴<div>Bukan kendaraan pribadi<small>Hanya kendaraan milik pribadi yang bisa dikustom</small></div></div>';
        if (I.mechanics > 0) return `<div class="status on">🟢<div>${I.mechanics} mekanik sedang bertugas<small>Setelah bayar di kasir, mekanik memasang modifikasimu</small></div></div>`;
        return '<div class="status off">🔴<div>Tidak ada mekanik bertugas<small>Kamu tetap bisa mencoba modifikasi, tapi belum bisa diproses</small></div></div>';
    }

    function blockReason() {
        if (I.free) return '';
        if (I.active) return 'Order kustom sebelumnya belum selesai';
        if (!I.owned) return 'Hanya kendaraan milik pribadi';
        if (I.mechanics <= 0) return 'Tombol aktif jika ada mekanik bertugas';
        return '';
    }

    function renderCart() {
        const items = [...cart.values()];
        $('count').textContent = `${items.length} item dipilih`;
        $('status').innerHTML = statusHtml();
        $('cart').innerHTML = items.length ? items.map(it => `
            <div class="ci"><div class="tx"><b>${esc(it.label)}</b><small>${esc(it.desc)}</small></div>
                <span class="pr">${priceTxt(it.price)}</span><button class="x" data-k="${esc(it.id)}" title="Hapus">✕</button></div>`).join('')
            : `<div class="empty"><span>🧰</span>${locked() ? 'Belum bisa memodifikasi.' : 'Belum ada modifikasi.'}<br><small>Pilih modifikasi di panel kiri, hasilnya langsung terlihat di kendaraan.</small></div>`;
        document.querySelectorAll('.ci .x').forEach(b => b.onclick = () => removeLine(b.dataset.k));
        const total = items.reduce((a, b) => a + b.price, 0);
        $('total').innerHTML = I.free ? `<s style="color:var(--muted);font-weight:400;font-size:13px">${money(total)}</s> Rp 0` : money(total);
        const why = blockReason();
        $('submit').textContent = I.free ? 'Pasang Sekarang (Gratis)' : 'Selesai Modifikasi';
        $('submit').disabled = !!why || !items.length;
        $('why').textContent = why;
        $('why').classList.toggle('hidden', !why);
    }

    // ------------------------------------------------------------ submit
    const linesPayload = () => [...cart.values()].map(l => ({ id: l.id, props: l.props, desc: l.desc }));
    const modal = html => { $('modal').innerHTML = html; $('ov').classList.remove('hidden'); };
    const closeModal = () => $('ov').classList.add('hidden');

    async function submit() {
        $('submit').disabled = true;
        const q = await post('submit', { lines: linesPayload(), dry: true });
        renderCart();
        if (!q || q.error) return modal(`<div class="big">⚠️</div><h2>Tidak bisa diproses</h2><p>${esc((q && q.error) || 'Gagal')}</p><button class="btn ghost" id="mOk">Kembali</button>`), ($('mOk').onclick = closeModal);
        const box = `<div class="box">${q.lines.map(l => `<div><span>${esc(l.label)} <small>· ${esc(l.desc)}</small></span><b>${priceTxt(l.price)}</b></div>`).join('')}
            <div style="border-top:1px solid var(--line);margin-top:6px;padding-top:8px"><b>Total</b><b style="color:var(--accent)">${q.free ? 'Rp 0' : money(q.total)}</b></div></div>`;
        modal(q.free
            ? `<div class="big">🔧</div><h2>Pasang sekarang?</h2><p>Modifikasi langsung terpasang di kendaraan, gratis.</p>${box}
               <div class="row2"><button class="btn ghost" id="mNo">Kembali</button><button class="btn primary" id="mYes">Pasang</button></div>`
            : `<div class="big">🧾</div><h2>Kirim ke kasir?</h2><p>Kendaraan kembali ke tampilan semula. Modifikasi dipasang mekanik setelah tagihan lunas.</p>${box}
               <div class="row2"><button class="btn ghost" id="mNo">Kembali</button><button class="btn primary" id="mYes">Kirim Tagihan</button></div>`);
        $('mNo').onclick = closeModal;
        $('mYes').onclick = async () => {
            $('mYes').disabled = true;
            const res = await post('submit', { lines: linesPayload() });
            if (!res || res.error) {
                modal(`<div class="big">⚠️</div><h2>Gagal</h2><p>${esc((res && res.error) || 'Gagal')}</p><button class="btn ghost" id="mOk">Kembali</button>`);
                $('mOk').onclick = closeModal;
                return;
            }
            if (res.applied) {
                modal(`<div class="big">✅</div><h2>Modifikasi terpasang</h2><p>${cart.size} item sudah dipasang di kendaraanmu.</p><button class="btn primary" id="mOk">Selesai</button>`);
                $('mOk').onclick = () => { cart.clear(); post('done', { keep: true }); };
            } else {
                modal(`<div class="big">✅</div><h2>Tagihan terkirim</h2>
                    <p>Order #${res.id}. Silakan menuju <b style="color:var(--text)">Kasir Bengkel</b> untuk membayar <b style="color:var(--accent)">${money(res.total)}</b>.<br>
                    Bayar cash atau transfer, lalu tunggu mekanik memasang modifikasimu.</p><button class="btn primary" id="mOk">Mengerti</button>`);
                $('mOk').onclick = () => { cart.clear(); post('done', { keep: false }); };
            }
        };
    }

    $('submit').onclick = submit;
    $('reset').onclick = () => { [...cart.keys()].forEach(removeLine); };
    $('exit').onclick = () => post('close');
    $('back').onclick = () => { sub = null; renderList(); };
    document.querySelectorAll('[data-cam]').forEach(b => b.onclick = () => {
        document.querySelectorAll('[data-cam]').forEach(x => x.classList.toggle('on', x === b));
        post('cam', { preset: b.dataset.cam });
    });

    // ------------------------------------------------------------ kamera: geser & zoom di area kosong
    const drag = $('drag');
    let dragging = false, acc = { dx: 0, dy: 0 }, pending = false;
    const flush = () => { pending = false; if (acc.dx || acc.dy) { post('cam', acc); acc = { dx: 0, dy: 0 }; } };
    drag.addEventListener('mousedown', () => { dragging = true; drag.classList.add('on'); });
    window.addEventListener('mouseup', () => { dragging = false; drag.classList.remove('on'); });
    window.addEventListener('mousemove', e => {
        if (!dragging) return;
        acc.dx += e.movementX; acc.dy += e.movementY;
        if (!pending) { pending = true; setTimeout(flush, 33); }
    });
    drag.addEventListener('wheel', e => post('cam', { dx: 0, dy: 0, zoom: Math.sign(e.deltaY) }), { passive: true });

    document.addEventListener('keyup', e => {
        if (e.key !== 'Escape' || $('app').classList.contains('hidden')) return;
        if (!$('ov').classList.contains('hidden')) return closeModal();
        post('close');
    });

    window.addEventListener('message', e => {
        const d = e.data || {};
        if (d.action === 'open') {
            I = d.info; C = d.catalog; O = d.orig || {}; cur = clone(O);
            cart.clear(); cat = 'perf'; sub = null; paintTab = 'color1'; paintGroup = 'Classic'; wheelType = null; wheelOpts = null;
            $('vname').textContent = d.vehicle.name;
            $('vplate').textContent = d.vehicle.plate;
            document.querySelectorAll('[data-cam]').forEach(x => x.classList.toggle('on', x.dataset.cam === 'free'));
            closeModal();
            $('app').classList.remove('hidden');
            renderCats(); renderList(); renderCart();
        } else if (d.action === 'close') {
            $('app').classList.add('hidden');
            closeModal();
            I = null;
        }
    });
})();
