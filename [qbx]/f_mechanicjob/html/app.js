// Panel "Periksa Kendaraan": gambar kendaraan + titik penunjuk, cairan, daftar kerusakan, tab Tagihan.
// Semua keputusan di server; halaman ini hanya menampilkan & mengirim pilihan mekanik.
(() => {
    const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'f_mechanicjob';
    const post = (name, data) => fetch(`https://${RES}/${name}`, { method: 'POST', body: JSON.stringify(data || {}) })
        .then(r => r.json()).catch(() => null);
    const $ = id => document.getElementById(id);
    const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

    let S = null;    // status dari server
    let C = null;    // config
    let tab = 'cond';
    let bill = null; // data tab tagihan
    let billMsg = null;
    let custom = null; // data tab kustom
    let customMsg = null;
    let lastImgKey = null;

    // titik penunjuk (pecahan kotak gambar). Gambar: 3/4 depan, moncong di kiri.
    const ANCHOR = {
        car: { radiator: [.07, .64], engine: [.2, .46], sparkplugs: [.28, .43], airfilter: [.13, .42], brakes: [.32, .8], TYRES: [.87, .64],
               body: [.6, .3], clutch: [.42, .6], axle: [.62, .74], suspension: [.82, .5], tank: [.86, .4] },
        bike: { radiator: [.42, .44], engine: [.5, .62], sparkplugs: [.47, .5], airfilter: [.56, .44], brakes: [.13, .8], TYRES: [.86, .8],
                body: [.75, .3], clutch: [.44, .7], axle: [.72, .72], suspension: [.2, .42], tank: [.62, .3] },
    };
    const CALLOUTS = { left: ['airfilter', 'sparkplugs', 'engine', 'radiator', 'clutch', 'brakes'], right: ['body', 'tank', 'suspension', 'TYRES', 'axle'] };

    const FALLBACK = `<svg viewBox="30 48 552 196"><g transform="translate(612,0) scale(-1,1)">
      <path class="fb-body" d="M42,186 L38,158 C38,140 46,128 62,124 L128,116 C156,112 178,106 198,96 L240,70 C262,60 302,56 334,58 C362,60 384,70 404,90 L420,104 C468,110 516,114 548,124 C566,130 574,144 574,160 L572,186 L502,186 A46,46 0 0,0 410,186 L198,186 A46,46 0 0,0 106,186 Z"/>
      <path class="fb-glass" d="M206,104 L242,79 C262,69 300,65 330,66 C354,68 374,77 392,93 L402,104 Z"/>
      <path class="fb-line" d="M304,64 L304,105 M198,106 L406,106 M304,106 L306,182 M408,108 Q415,146 404,182 M202,108 C195,140 197,166 204,182"/>
      <circle class="fb-tyre" cx="152" cy="190" r="40"/><circle class="fb-rim" cx="152" cy="190" r="26"/>
      <circle class="fb-tyre" cx="456" cy="190" r="40"/><circle class="fb-rim" cx="456" cy="190" r="26"/>
    </g></svg>`;

    // ------------------------------------------------------------ helper
    const level = v => { for (let i = 0; i < C.levels.length; i++) if (v >= C.levels[i]) return i + 1; return C.levels.length + 1; };
    const color = l => `var(--c${l})`;
    const bike = () => S.kind === 'bike';
    const tyreList = () => C.tyres[bike() ? 'bike' : 'car'];
    const label = k => (bike() && C.parts[k].bikeLabel) || C.parts[k].label;
    const pct = k => Math.round(S.parts[k] ?? 100);
    const needs = k => pct(k) < C.needs;
    const locked = k => C.parts[k].heavy && !S.heavyOk;
    const lockText = () => S.heavyNeed === 'bawa ke bengkel' ? 'Perlu Bengkel' : 'Perlu Lift';
    const tyreLvl = t => (S.tyres[t] && S.tyres[t].burst) ? 4 : level(S.tyres[t] ? S.tyres[t].wear : 100);
    const tyreNeeds = t => S.tyres[t] && (S.tyres[t].burst || S.tyres[t].wear < C.needs);
    const tyresWorst = () => Math.max(...tyreList().map(t => tyreLvl(t.key)));
    const have = item => S.stock[item] || 0;
    const itemLabel = item => C.itemLabels[item] || item;
    const icon = item => C.itemIcons[item] || '•';

    function toast(text) {
        let t = document.querySelector('.toast');
        if (!t) { t = document.createElement('div'); t.className = 'toast'; document.body.appendChild(t); }
        t.textContent = text; t.classList.add('show');
        clearTimeout(t._t); t._t = setTimeout(() => t.classList.remove('show'), 2400);
    }

    // ------------------------------------------------------------ gambar & penunjuk
    function buildImage() {
        const key = `${S.net}:${S.spawn}`;
        if (key === lastImgKey) return;
        lastImgKey = key;
        const box = $('carbox');
        box.innerHTML = '';
        const spawn = String(S.spawn || '').toLowerCase().replace(/[^a-z0-9_]/g, '');
        if (!spawn) { box.innerHTML = FALLBACK; return requestAnimationFrame(layout); }
        const sources = [`nui://f_vehimages/images/${spawn}.webp`, `https://docs.fivem.net/vehicles/${spawn}.webp`];
        let i = 0;
        const img = new Image();
        img.onload = () => requestAnimationFrame(layout);
        img.onerror = () => {
            i += 1;
            if (i < sources.length) img.src = sources[i];
            else { box.innerHTML = FALLBACK; requestAnimationFrame(layout); }
        };
        img.src = sources[0];
        box.appendChild(img);
    }

    function buildCallouts() {
        const stage = $('stage');
        if (stage.querySelector('.callout')) return;
        ['left', 'right'].forEach(side => CALLOUTS[side].forEach(k => {
            const c = document.createElement('div');
            c.className = 'callout'; c.dataset.k = k; c.dataset.side = side;
            c.onclick = () => focusRow(k);
            stage.appendChild(c);
        }));
    }

    function layout() {
        if (!S) return;
        const stage = $('stage'), sr = stage.getBoundingClientRect();
        const el = $('carbox').firstElementChild;
        if (!el || !el.getBoundingClientRect().width) return;
        const br = el.getBoundingClientRect();
        const A = ANCHOR[bike() ? 'bike' : 'car'];
        let h = '';
        ['left', 'right'].forEach(side => {
            const keys = CALLOUTS[side], gap = (sr.height - 30) / keys.length;
            keys.forEach((k, i) => {
                const c = stage.querySelector(`.callout[data-k="${k}"]`);
                const top = 14 + gap * i + (gap - 46) / 2;
                c.style.top = top + 'px';
                c.style[side] = '16px';
                const ax = br.left - sr.left + A[k][0] * br.width, ay = br.top - sr.top + A[k][1] * br.height;
                const cx = side === 'left' ? 16 + 112 : sr.width - 16 - 112, cy = top + 23;
                const l = k === 'TYRES' ? tyresWorst() : level(pct(k));
                const mid = side === 'left' ? cx + 22 : cx - 22;
                h += `<path d="M${cx},${cy} L${mid},${cy} L${ax},${ay}" stroke="${color(l)}"/><circle cx="${ax}" cy="${ay}" r="4.5" fill="${color(l)}"/>`;
            });
        });
        $('links').innerHTML = h;
    }

    // ------------------------------------------------------------ render
    function render() {
        if (!S) return;
        $('vehname').textContent = `${S.name} · ${S.plate}`;
        const st = $('state');
        st.className = 'state-pill ' + (S.bag === false ? 'road' : S.heavyOk ? 'lift' : 'road');
        st.textContent = S.bag === false ? '🧰 Bawa Tas Perkakas dulu (Gudang Bengkel)'
            : S.onLift ? '⬆ Di Lift · semua bisa diperbaiki'
            : S.heavyOk ? 'Semua bagian bisa diperbaiki'
            : `Perbaikan ringan · bagian berat ${S.heavyNeed || 'perlu lift'}`;

        $('fluids').innerHTML = C.fluids.map(k => {
            const v = pct(k), l = level(v);
            return `<div class="fluid" data-k="${k}"><div class="tube"><div style="height:${v}%;background:${color(l)}"></div></div>
                <div><small>${esc(C.parts[k].label)}</small><b style="color:${l > 1 ? color(l) : 'var(--text)'}">${v}%</b></div></div>`;
        }).join('');
        $('fluids').querySelectorAll('.fluid').forEach(f => f.onclick = () => focusRow(f.dataset.k));

        buildCallouts();
        $('stage').querySelectorAll('.callout').forEach(c => {
            const k = c.dataset.k;
            let l, txt, lk = '', name;
            if (k === 'TYRES') {
                l = tyresWorst();
                const nb = tyreList().filter(t => S.tyres[t.key] && S.tyres[t.key].burst).length;
                const off = tyreList().filter(t => S.tyres[t.key] && S.tyres[t.key].off).length;
                txt = off ? `${off} lepas` : nb ? `${nb} bocor` : `${Math.round(Math.min(...tyreList().map(t => S.tyres[t.key] ? S.tyres[t.key].wear : 100)))}%`;
                name = 'Ban';
            } else {
                l = level(pct(k));
                txt = pct(k) + '%';
                name = label(k);
                if (locked(k) && needs(k)) lk = '<span class="lk">🔒</span>';
            }
            c.innerHTML = `<small>${esc(name)}</small>${lk}<b style="color:${color(l)}">${txt}</b>`;
            c.style.borderColor = l > 1 ? color(l) : 'var(--line2)';
            c.classList.toggle('l4', l === 4);
        });

        const keys = Object.keys(C.parts);
        const avg = Math.round(keys.reduce((a, k) => a + pct(k), 0) / keys.length);
        $('cards').innerHTML = [
            ['Plat', esc(S.plate), ''],
            ['Jarak Tempuh', S.odo.toLocaleString('id-ID') + ' km', ''],
            ['Kondisi Umum', avg + '%', color(level(avg))],
        ].map(([k, v, c]) => `<div class="card"><small>${k}</small><b style="${c ? 'color:' + c : ''}">${v}</b></div>`).join('');

        const badge = $('bill-badge');
        badge.textContent = S.pendingBill;
        badge.classList.toggle('hidden', !S.pendingBill);
        const cbadge = $('custom-badge');
        cbadge.textContent = S.customReady || '';
        cbadge.classList.toggle('hidden', !S.customReady);

        buildImage();
        renderList();
        renderFooter();
        requestAnimationFrame(layout);
    }

    function matHtml(item, qty) {
        return `<div class="mat ${have(item) < qty ? 'none' : ''}">${icon(item)} ${esc(itemLabel(item))} ×${qty} · stok ${have(item)}</div>`;
    }

    function partRow(k) {
        const P = C.parts[k], v = pct(k), l = level(v), ok = have(P.item) >= P.qty;
        const act = locked(k)
            ? `<button class="btn locked" disabled>🔒 ${lockText()}</button>`
            : `<button class="btn" ${ok ? '' : 'disabled'} data-act="part" data-key="${k}">🔧 ${P.fluid ? 'Isi Ulang' : 'Perbaiki'}</button>`;
        return `<div class="row" data-row="${k}">
            <div class="nm">${esc(label(k))}<span>${esc(P.fx[l - 1])}</span></div>
            <div class="act">${act}</div>
            <div class="bar"><div class="track"><div style="width:${v}%;background:${color(l)}"></div></div><div class="pc" style="color:${color(l)}">${v}%</div></div>
            ${matHtml(P.item, P.qty)}</div>`;
    }

    function tyreRow(t) {
        const s = S.tyres[t.key], l = tyreLvl(t.key);
        // roda lepas: dipasang ulang lewat perbaikan body, jadi bahan body ikut dipakai
        const body = C.parts.body;
        const ok = have(C.tyre.item) >= C.tyre.qty && (!s.off || have(body.item) >= body.qty);
        const note = s.off ? 'Roda lepas · perlu dipasang ulang (ikut perbaikan body)'
            : s.burst ? 'Bocor · oleng & lambat' : esc(C.tyre.fx[level(s.wear) - 1]);
        return `<div class="row" data-row="TYRES">
            <div class="nm">${esc(t.label)}<span>${note}</span></div>
            <div class="act"><button class="btn" ${ok ? '' : 'disabled'} data-act="tyre" data-key="${t.key}">⭕ ${s.off ? 'Pasang Roda' : 'Ganti Ban'}</button></div>
            <div class="bar"><div class="track"><div style="width:${s.off ? 0 : s.wear}%;background:${color(l)}"></div></div><div class="pc" style="color:${color(l)}">${s.off ? 'LEPAS' : s.burst ? 'BOCOR' : Math.round(s.wear) + '%'}</div></div>
            ${matHtml(C.tyre.item, C.tyre.qty)}${s.off ? matHtml(body.item, body.qty) : ''}</div>`;
    }

    function renderList() {
        // hanya bagian yang rusak; kondisi lengkap terlihat di persentase kiri
        const html = C.groups.map(([title, ks]) => {
            const rows = ks.map(k => k === 'TYRES'
                ? tyreList().filter(t => tyreNeeds(t.key)).map(tyreRow).join('')
                : (C.parts[k] && needs(k) ? partRow(k) : '')).join('');
            return rows ? `<h3>${esc(title)}</h3>${rows}` : '';
        }).join('');
        const list = $('list');
        list.innerHTML = html || '<div class="empty">✔ Tidak ada kerusakan. Kendaraan dalam kondisi baik.</div>';
        list.querySelectorAll('[data-act]').forEach(b => b.onclick = () => post('action', { action: b.dataset.act, key: b.dataset.key }));
    }

    function renderFooter() {
        const bt = $('btn-tyres'), ba = $('btn-all');
        const fixT = tyreList().filter(t => tyreNeeds(t.key)).length;
        bt.disabled = !fixT || have(C.tyre.item) < fixT;
        $('tyres-sub').textContent = !fixT ? 'Semua ban layak' : `${icon(C.tyre.item)} ${itemLabel(C.tyre.item)} ×${fixT} · stok ${have(C.tyre.item)}`;
        bt.onclick = () => post('action', { action: 'tyres' });

        const cost = {};
        let lockedN = 0;
        Object.keys(C.parts).forEach(k => {
            if (!needs(k)) return;
            if (locked(k)) { lockedN++; return; }
            cost[C.parts[k].item] = (cost[C.parts[k].item] || 0) + C.parts[k].qty;
        });
        if (fixT) cost[C.tyre.item] = (cost[C.tyre.item] || 0) + fixT;
        const keys = Object.keys(cost);
        const enough = keys.every(k => have(k) >= cost[k]);
        ba.disabled = !keys.length || !enough;
        const where = lockText().toLowerCase();
        let sub = !keys.length ? (lockedN ? `🔒 ${lockedN} bagian ${where}` : 'Tidak ada yang diperbaiki')
            : keys.map(k => `${icon(k)}${cost[k]}`).join(' ') + (enough ? '' : ' · bahan kurang');
        if (keys.length && lockedN) sub += ` · 🔒 ${lockedN} ${where}`;
        $('all-sub').textContent = sub;
        ba.onclick = () => post('action', { action: 'all' });
    }

    function focusRow(k) {
        if (tab !== 'cond') setTab('cond');
        const rows = document.querySelectorAll(`.row[data-row="${k}"]`);
        if (!rows.length) return toast(`✔ ${k === 'TYRES' ? 'Semua ban' : label(k)} dalam kondisi baik`);
        rows[0].scrollIntoView({ behavior: 'smooth', block: 'center' });
        rows.forEach(x => { x.classList.remove('flash'); void x.offsetWidth; x.classList.add('flash'); });
    }

    // ------------------------------------------------------------ tagihan
    async function loadBill() {
        $('bill').innerHTML = '<div class="note">Memuat…</div>';
        const res = await post('billingGet');
        applyBill(res);
    }

    function applyBill(res) {
        if (!res || res.error) billMsg = { ok: false, text: (res && res.error) || 'Gagal memuat tagihan' };
        else bill = res;
        renderBill();
    }

    function renderBill() {
        const el = $('bill');
        if (!bill) { el.innerHTML = billMsg ? `<div class="msg">${esc(billMsg.text)}</div>` : ''; return; }
        let h = billMsg ? `<div class="${billMsg.ok ? 'empty' : 'msg'}">${esc(billMsg.text)}</div>` : '';

        h += '<div class="field"><h3>Pelanggan</h3>';
        if (!bill.customers.length) h += '<div class="note">Tidak ada orang di dekatmu. Pelanggan harus berdiri dekat kamu saat ditagih.</div>';
        else h += `<select id="bill-target">${bill.customers.map(c => `<option value="${c.id}">${esc(c.name)}${c.owner ? ' (pemilik kendaraan)' : ''}</option>`).join('')}</select>`;
        h += '</div>';

        h += '<h3>Layanan belum ditagih</h3>';
        if (!bill.pending.length) h += '<div class="note">Belum ada layanan. Setiap perbaikan di panel tercatat otomatis di sini.</div>';
        bill.pending.forEach(p => {
            h += `<div class="bill-line" data-id="${p.id}">
                <input type="checkbox" checked>
                <span>${esc(p.label)}<span class="who">oleh ${esc(p.byName)}</span></span>
                <input type="number" min="0" max="${p.price}" value="${p.price}" title="Maks Rp ${p.price}">
                <button class="x" title="Hapus">✕</button></div>`;
        });

        h += `<div class="field"><h3>Tambah layanan</h3><div class="chips">${bill.manual.map(m =>
            `<button class="ghost" data-add="${m.code}">+ ${esc(m.label)} (Rp ${m.price})</button>`).join('')}</div></div>`;

        h += `<div class="bill-sum"><span>Total</span><strong id="bill-total">Rp 0</strong></div>
            <div class="pay2">
                <button class="kasir" id="bill-kasir"><span>🧾 Bayar di Kasir</span><small>${bill.inWorkshop ? 'Pelanggan bayar di meja kasir' : 'Hanya di area bengkel'}</small></button>
                <button id="bill-send"><span>📱 Bayar Langsung</span><small>Invoice ke HP pelanggan</small></button>
            </div>
            <div class="note">Harga boleh diturunkan (diskon), tidak bisa dinaikkan. Uang masuk ke rekening bengkel.</div>`;
        el.innerHTML = h;

        const total = () => {
            let t = 0;
            el.querySelectorAll('.bill-line').forEach(l => {
                if (l.querySelector('input[type=checkbox]').checked) t += Math.max(0, Math.floor(Number(l.querySelector('input[type=number]').value) || 0));
            });
            $('bill-total').textContent = 'Rp ' + t;
            $('bill-send').disabled = t <= 0 || !bill.customers.length;
            $('bill-kasir').disabled = t <= 0 || !bill.customers.length || !bill.inWorkshop;
        };
        el.querySelectorAll('input').forEach(i => i.oninput = total);
        el.querySelectorAll('.bill-line .x').forEach(b => b.onclick = async () => {
            billMsg = null;
            applyBill(await post('billingDiscard', { id: Number(b.closest('.bill-line').dataset.id) }));
        });
        el.querySelectorAll('[data-add]').forEach(b => b.onclick = async () => {
            billMsg = null;
            applyBill(await post('billingAdd', { code: b.dataset.add }));
        });
        const send = async channel => {
            const lines = [];
            el.querySelectorAll('.bill-line').forEach(l => {
                if (l.querySelector('input[type=checkbox]').checked) lines.push({ id: Number(l.dataset.id), price: Math.floor(Number(l.querySelector('input[type=number]').value) || 0) });
            });
            $('bill-send').disabled = true;
            $('bill-kasir').disabled = true;
            const res = await post('billingSend', { target: Number($('bill-target').value), lines, channel });
            if (res && !res.error) {
                bill = res;
                billMsg = { ok: true, text: res.channel === 'kasir'
                    ? `Tagihan Rp ${res.sent} masuk kasir atas nama ${res.to}. Arahkan pelanggan ke meja kasir.`
                    : `Tagihan Rp ${res.sent} dikirim ke HP ${res.to}.` };
                if (S) S.pendingBill = res.pending.length;
            } else billMsg = { ok: false, text: (res && res.error) || 'Gagal mengirim tagihan' };
            renderBill();
            if (S) render();
        };
        $('bill-send').onclick = () => send('phone');
        $('bill-kasir').onclick = () => send('kasir');
        total();
    }

    // ------------------------------------------------------------ kustom (order lunas dari kasir)
    async function loadCustom(quiet) {
        if (!quiet) $('custom').innerHTML = '<div class="note">Memuat…</div>';
        applyCustom(await post('customGet'));
    }

    function applyCustom(res) {
        if (!res || res.error) customMsg = { ok: false, text: (res && res.error) || 'Gagal memuat order kustom' };
        else { custom = res; if (res.msg) customMsg = { ok: true, text: res.msg }; }
        renderCustom();
    }

    function renderCustom() {
        const el = $('custom'), foot = $('custom-foot');
        let h = customMsg ? `<div class="${customMsg.ok ? 'empty' : 'msg'}">${esc(customMsg.text)}</div>` : '';
        if (!custom || !custom.order) {
            el.innerHTML = h + `<div class="note" style="text-align:center;padding:30px 10px">🧰<br>Tidak ada order kustom yang sudah lunas untuk kendaraan ini.<br>
                <small>Order muncul di sini setelah pelanggan membayar di kasir.</small></div>`;
            foot.classList.add('hidden');
            return;
        }
        const o = custom.order;
        const d = o.paidAt ? new Date(o.paidAt * 1000) : null;
        const paid = d ? `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}` : '—';
        h += `<div class="order">
            <div class="top"><span class="code">#${o.id}</span><span class="who">${esc(o.name)}</span>
                <span class="chip ok">Lunas · ${o.method === 'transfer' ? 'Transfer' : 'Cash'}</span></div>
            <div class="meta">
                <div><small>Plat</small><b>${esc(o.plate)}</b></div><div><small>Total</small><b>Rp ${o.total}</b></div>
                <div><small>Dibayar</small><b>${paid}</b></div><div><small>Item</small><b>${o.items.length} modifikasi</b></div>
            </div></div>
            <h3>Daftar modifikasi</h3>
            ${o.items.map(it => `<div class="mod"><span class="tx"><b>${esc(it.label)}</b></span><span class="arrow">→ <b>${esc(it.desc || '-')}</b></span></div>`).join('')}
            <h3>Syarat</h3>
            <div class="req">
                <div class="${custom.inWorkshop ? 'ok' : 'no'}">${custom.inWorkshop ? '✔' : '✘'} Kendaraan di area bengkel</div>
                <div class="${custom.empty ? 'ok' : 'no'}">${custom.empty ? '✔' : '✘'} Kendaraan kosong (tidak ada pengemudi)</div>
            </div>`;
        el.innerHTML = h;
        foot.classList.remove('hidden');
        const btn = $('btn-custom');
        btn.disabled = !(custom.inWorkshop && custom.empty);
        $('custom-sub').textContent = `${Math.round(custom.duration / 1000)} detik · ${o.items.length} item`;
        btn.onclick = () => { btn.disabled = true; customMsg = null; post('customInstall', { id: o.id }); };
    }

    function setTab(t) {
        tab = t;
        document.querySelectorAll('.tab').forEach(b => b.classList.toggle('on', b.dataset.tab === t));
        $('tab-cond').classList.toggle('hidden', t !== 'cond');
        $('tab-custom').classList.toggle('hidden', t !== 'custom');
        $('tab-bill').classList.toggle('hidden', t !== 'bill');
        if (t === 'bill') { billMsg = null; loadBill(); }
        if (t === 'custom') { customMsg = null; loadCustom(); }
    }
    document.querySelectorAll('.tab').forEach(b => b.onclick = () => setTab(b.dataset.tab));

    // ------------------------------------------------------------ decit rem
    // Rekaman asli sounds/brake_squeal.mp3 (Freesound #456764, WavJunction.com, CC0). Bagian decit di
    // dalam rekaman dideteksi otomatis saat pertama dimuat; tiap kali bunyi dipilih satu acak.
    // Kalau file gagal dimuat, dipakai suara sintetis di bawah.
    let actx = null;
    let squeal = null; // { buf, segs: [[start, end]] } | false (gagal)
    let squealLoading = null;

    function loadSqueal() {
        if (squeal !== null || squealLoading) return squealLoading;
        squealLoading = fetch('sounds/brake_squeal.mp3')
            .then(r => r.arrayBuffer())
            .then(data => actx.decodeAudioData(data))
            .then(buf => {
                const d = buf.getChannelData(0), win = Math.floor(buf.sampleRate * 0.05);
                const rms = [];
                let max = 0;
                for (let i = 0; i + win < d.length; i += win) {
                    let s = 0;
                    for (let j = 0; j < win; j++) s += d[i + j] * d[i + j];
                    const r = Math.sqrt(s / win);
                    rms.push(r); max = Math.max(max, r);
                }
                const segs = [];
                let start = -1;
                rms.forEach((r, i) => {
                    const loud = r > max * 0.15;
                    if (loud && start < 0) start = i;
                    if (!loud && start >= 0) { if (i - start >= 6) segs.push([start * 0.05, i * 0.05]); start = -1; }
                });
                if (start >= 0 && rms.length - start >= 6) segs.push([start * 0.05, rms.length * 0.05]);
                squeal = segs.length ? { buf, segs } : false;
            })
            .catch(() => { squeal = false; });
        return squealLoading;
    }

    function playRecorded(volume, severe) {
        const seg = squeal.segs[Math.floor(Math.random() * squeal.segs.length)];
        const t = actx.currentTime;
        const len = Math.min(seg[1] - seg[0], (severe ? 0.8 : 0.55) + Math.random() * 0.2);
        const src = actx.createBufferSource();
        src.buffer = squeal.buf;
        // sedikit variasi nada; Parah lebih tinggi & lebih keras
        src.playbackRate.value = (severe ? 1.06 : 0.96) + Math.random() * 0.08;
        const g = actx.createGain();
        const vol = Math.max(0.0001, Math.min(1, volume * (severe ? 1.2 : 1.0)));
        g.gain.setValueAtTime(0.0001, t);
        g.gain.exponentialRampToValueAtTime(vol, t + 0.04);
        g.gain.setValueAtTime(vol, t + Math.max(0.05, len - 0.15));
        g.gain.exponentialRampToValueAtTime(0.0001, t + len);
        src.connect(g); g.connect(actx.destination);
        src.start(t, seg[0], len + 0.05);
    }

    function playSqueal(volume, severe) {
        try {
            actx = actx || new (window.AudioContext || window.webkitAudioContext)();
            if (actx.state === 'suspended') actx.resume();
            if (squeal === null) {
                loadSqueal().then(() => { if (squeal) playRecorded(volume, severe); else playSynth(volume, severe); });
                return;
            }
            if (squeal) return playRecorded(volume, severe);
            playSynth(volume, severe);
        } catch (e) { /* audio tidak tersedia */ }
    }

    function playSynth(volume, severe) {
        try {
            const t = actx.currentTime;
            const dur = (severe ? 1.5 : 1.0) + Math.random() * 0.3;
            const base = (severe ? 3300 : 2800) + Math.random() * 350;
            const vol = Math.max(0.0001, Math.min(1, volume));

            const out = actx.createGain();
            out.gain.setValueAtTime(0.0001, t);
            out.gain.exponentialRampToValueAtTime(vol, t + 0.06);
            out.gain.setValueAtTime(vol, t + dur - 0.3);
            out.gain.exponentialRampToValueAtTime(0.0001, t + dur);
            const filter = actx.createBiquadFilter();
            filter.type = 'bandpass'; filter.frequency.value = base; filter.Q.value = 6;
            filter.connect(out); out.connect(actx.destination);

            // nada tinggi bergetar (gesekan kampas) + harmonik + sedikit desis
            const lfo = actx.createOscillator(), lfoGain = actx.createGain();
            lfo.frequency.value = 6 + Math.random() * 4; lfoGain.gain.value = base * 0.018;
            lfo.connect(lfoGain);
            [[1, 1, 'sine'], [2.01, 0.25, 'sine'], [0.5, 0.12, 'triangle']].forEach(([mul, gain, type]) => {
                const osc = actx.createOscillator(), g = actx.createGain();
                osc.type = type; osc.frequency.value = base * mul; g.gain.value = gain;
                lfoGain.connect(osc.frequency);
                osc.connect(g); g.connect(mul === 2.01 ? out : filter);
                osc.start(t); osc.stop(t + dur);
            });
            const len = Math.floor(actx.sampleRate * dur), buf = actx.createBuffer(1, len, actx.sampleRate), data = buf.getChannelData(0);
            for (let i = 0; i < len; i++) data[i] = (Math.random() * 2 - 1) * 0.08;
            const noise = actx.createBufferSource(); noise.buffer = buf; noise.connect(filter);
            noise.start(t); lfo.start(t); lfo.stop(t + dur);
        } catch (e) { /* audio tidak tersedia */ }
    }

    // ------------------------------------------------------------ pesan dari Lua
    $('diag-close').onclick = () => post('close');
    document.addEventListener('keyup', e => {
        if (e.key === 'Escape' && !$('diag').classList.contains('hidden')) post('close');
    });
    window.addEventListener('resize', () => requestAnimationFrame(layout));

    window.addEventListener('message', e => {
        const d = e.data || {};
        if (d.action === 'squeal') return playSqueal(Number(d.volume) || 0.2, d.severe === true);
        if (d.action === 'open') {
            if (d.config) C = d.config;
            if (d.status) {
                if (!S || S.net !== d.status.net) { tab = 'cond'; bill = null; custom = null; }
                S = d.status;
            }
            if (!S) return;
            $('diag').classList.remove('hidden');
            render();
            if (tab === 'bill') loadBill();
            else if (tab === 'custom') renderCustom();
            else setTab('cond');
        } else if (d.action === 'custom') {
            applyCustom(d.data);
        } else if (d.action === 'update') {
            if (d.status) {
                S = d.status;
                if (!$('diag').classList.contains('hidden')) {
                    render();
                    if (tab === 'custom') loadCustom(true); // syarat (area / pengemudi) bisa berubah
                }
            }
        } else if (d.action === 'hide') {
            $('diag').classList.add('hidden');
        } else if (d.action === 'close') {
            $('diag').classList.add('hidden');
            S = null; lastImgKey = null;
        }
    });
})();
