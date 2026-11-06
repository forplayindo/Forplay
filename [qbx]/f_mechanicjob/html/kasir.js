// Kasir bengkel: warga membayar tagihan (cash / transfer), mekanik melihat daftar belum bayar & Master Harga.
// Mode lain di panel yang sama: Gudang (setor bahan) & Supplier (stok + beli bahan baku, Manager).
(() => {
    const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'f_mechanicjob';
    const post = (name, data) => fetch(`https://${RES}/${name}`, { method: 'POST', body: JSON.stringify(data || {}) })
        .then(r => r.json()).catch(() => null);
    const $ = id => document.getElementById(id);
    const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
    const money = n => 'Rp ' + Number(n || 0).toLocaleString('id-ID');
    const clock = ts => {
        if (!ts) return '—';
        const d = new Date(ts * 1000), now = new Date();
        const hm = `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
        return d.toDateString() === now.toDateString() ? hm : `${d.getDate()}/${d.getMonth() + 1} ${hm}`;
    };
    const kindLabel = k => k === 'custom' ? 'Kustom' : 'Perbaikan';

    let mode = null, D = null, msg = null, sel = null, method = 'cash';
    let stab = 'unpaid', query = '', P = null, pcat = 0, edits = {};
    let S = null, cart = {};

    const msgHtml = () => msg ? `<div class="${msg.ok ? 'empty' : 'msg'}">${esc(msg.text)}</div>` : '';

    function modal(html, onOk) {
        const wrap = document.createElement('div');
        wrap.className = 'ks-modal';
        wrap.innerHTML = `<div>${html}<div class="row2"><button class="ghost" data-x>Batal</button><button class="primary" data-ok>Ya</button></div></div>`;
        document.body.appendChild(wrap);
        wrap.querySelector('[data-x]').onclick = () => wrap.remove();
        wrap.querySelector('[data-ok]').onclick = () => { wrap.remove(); onOk(); };
    }

    // gambar ulang tanpa melompat ke atas: simpan & kembalikan posisi scroll tiap daftar
    function keepScroll(fn) {
        const pos = [...document.querySelectorAll('#kasir .ks-scroll')].map(el => el.scrollTop);
        fn();
        document.querySelectorAll('#kasir .ks-scroll').forEach((el, i) => { if (pos[i]) el.scrollTop = pos[i]; });
    }

    function apply(res) {
        if (!res || res.error) msg = { ok: false, text: (res && res.error) || 'Gagal' };
        else { D = res; msg = res.msg ? { ok: true, text: res.msg } : null; }
        render();
    }

    // ------------------------------------------------------------ warga
    function renderCustomer() {
        $('ks-kicker').textContent = 'Kasir Bengkel';
        $('ks-title').textContent = 'Tagihan Kamu';
        $('ks-pills').innerHTML = `<span class="pill cash">💵 Cash ${money(D.cash)}</span><span class="pill bank">🏦 Bank ${money(D.bank)}</span>`;
        const body = $('ks-body');
        if (!D.bills.length) {
            body.className = 'ks-body';
            body.innerHTML = `<div class="ks-scroll" style="padding:14px 16px">${msgHtml()}<div class="big-empty"><span>🧾</span>Tidak ada tagihan yang perlu dibayar.</div></div>`;
            return;
        }
        if (!D.bills.find(b => b.id === sel)) sel = D.bills[0].id;
        const b = D.bills.find(x => x.id === sel);
        if (!D.transfer && method === 'transfer') method = 'cash';
        const noCash = D.cash < b.total;

        body.className = 'ks-body cust';
        body.innerHTML = `
        <div class="ks-bills ks-scroll">
            ${msgHtml()}
            <h3>Pilih tagihan (${D.bills.length})</h3>
            ${D.bills.map(x => `
            <div class="ks-bill ${x.id === sel ? 'on' : ''}">
                <div class="ks-bill-h" data-b="${x.id}"><span class="radio"></span>
                    <div class="tx"><b>#${x.id} · ${esc(x.plate)}</b> <span class="tag ${x.kind}">${kindLabel(x.kind)}</span>
                        ${x.status === 'wait' ? '<span class="tag wait">menunggu transfer</span>' : ''}
                        <small>${esc(x.by)} · ${clock(x.at)}</small></div>
                    <span class="amt">${money(x.total)}</span></div>
                ${x.id === sel ? `<div class="ks-lines">
                    ${x.items.map(l => `<div class="ks-ln"><span class="tx">${esc(l.label)}${l.desc ? `<small>${esc(l.desc)}</small>` : ''}</span>
                        <span>${l.normal && l.normal > l.price ? `<s>${money(l.normal)}</s>` : ''}<b>${money(l.price)}</b></span>
                        ${x.kind === 'custom' && x.status === 'unpaid' ? `<button class="x" data-l="${esc(l.id)}" data-n="${esc(l.label)}" title="Hapus item">✕</button>` : '<span class="lock" title="Tidak bisa dihapus">🔒</span>'}</div>`).join('')}
                    <div class="note">${x.kind === 'custom'
                        ? (x.status === 'unpaid' ? 'Uang kurang? Hapus item yang tidak jadi dipasang.' : 'Batalkan transfer dulu untuk mengubah tagihan.')
                        : '🔒 Perbaikan sudah dikerjakan, item tidak bisa dihapus.'}</div>
                </div>` : ''}
            </div>`).join('')}
        </div>
        <div class="ks-pay ks-scroll">
            <h3>Pembayaran #${b.id}</h3>
            <div class="sumbox"><div><span>${b.items.length} item</span><span>${money(b.total)}</span></div>
                <div class="tot"><span>Total</span><b>${money(b.total)}</b></div></div>
            ${b.status === 'wait' ? `
                <div class="info">📱 Invoice sudah dikirim ke HP kamu. Buka <b>Bank &gt; Invoices</b> lalu bayar. Tagihan lunas otomatis setelah dibayar.</div>
                <button class="ghost" id="ks-refresh">Cek Status</button>
                <button class="ghost" id="ks-canceltf">Batalkan Transfer</button>`
            : `
                <h3>Metode</h3>
                <div class="methods">
                    <button class="method ${method === 'cash' ? 'on' : ''}" data-m="cash" ${noCash ? 'disabled' : ''}><span>💵</span><b>Cash</b><small>${noCash ? 'Uang tunai kurang' : 'Potong uang di tas'}</small></button>
                    <button class="method ${method === 'transfer' ? 'on' : ''}" data-m="transfer" ${D.transfer ? '' : 'disabled'}><span>📱</span><b>Transfer</b><small>${D.transfer ? 'Invoice ke HP' : 'Tidak tersedia'}</small></button>
                </div>
                <div class="info">${method === 'cash'
                    ? `Uang tunai <b>${money(b.total)}</b> langsung dipotong dari tas.`
                    : `Invoice <b>${money(b.total)}</b> dikirim ke HP. Tagihan lunas setelah kamu bayar dari HP.`}</div>
                <button class="primary" id="ks-pay" ${method === 'cash' && noCash ? 'disabled' : ''}>${method === 'cash' ? 'Bayar Cash ' + money(b.total) : 'Kirim Invoice ke HP'}</button>
                ${b.kind === 'custom' ? '<small style="text-align:center">Setelah lunas, mekanik memasang modifikasi di kendaraanmu.</small>' : ''}`}
        </div>`;

        if (method === 'cash' && noCash && D.transfer) { method = 'transfer'; return renderCustomer(); }

        body.querySelectorAll('.ks-bill-h').forEach(h => h.onclick = () => { sel = Number(h.dataset.b); msg = null; render(); });
        body.querySelectorAll('.ks-ln .x').forEach(x => x.onclick = () => {
            const last = b.items.length === 1;
            modal(`<h2>Hapus item?</h2><p class="note"><b>${esc(x.dataset.n)}</b> tidak akan dipasang.${last ? '<br>Ini item terakhir, order kustom akan dibatalkan.' : ''}</p>`,
                async () => apply(await post('ksRemoveLine', { bill: b.id, line: x.dataset.l })));
        });
        body.querySelectorAll('.method').forEach(m => m.onclick = () => { if (!m.disabled) { method = m.dataset.m; render(); } });
        const pay = $('ks-pay');
        if (pay) pay.onclick = async () => { pay.disabled = true; apply(await post('ksPay', { bill: b.id, method })); };
        const ct = $('ks-canceltf');
        if (ct) ct.onclick = async () => { ct.disabled = true; method = 'cash'; apply(await post('ksCancelTransfer', { bill: b.id })); };
        const rf = $('ks-refresh');
        if (rf) rf.onclick = async () => { rf.disabled = true; apply(await post('ksMine')); };
    }

    // ------------------------------------------------------------ mekanik
    function renderStaff() {
        $('ks-kicker').textContent = 'Kasir Bengkel · Mekanik';
        $('ks-title').textContent = 'Menu Kasir';
        $('ks-pills').innerHTML = D.balance != null ? `<span class="pill bank">🏦 Rekening Bengkel ${money(D.balance)}</span>` : '';
        const body = $('ks-body');
        body.className = 'ks-body staff';
        body.innerHTML = `
            <div class="ks-tabs">
                <button class="tab ${stab === 'unpaid' ? 'on' : ''}" data-t="unpaid">Belum Dibayar <span class="badge ${D.bills.length ? '' : 'hidden'}">${D.bills.length}</span></button>
                <button class="tab ${stab === 'price' ? 'on' : ''}" data-t="price">${D.canPrice ? '' : '🔒 '}Master Harga</button>
            </div>
            <div style="padding:0 18px">${msgHtml()}</div>
            <div class="ks-pane" id="ks-pane"></div>`;
        body.querySelectorAll('[data-t]').forEach(t => t.onclick = async () => {
            stab = t.dataset.t; msg = null;
            if (stab === 'price' && D.canPrice && !P) {
                const res = await post('ksPrices');
                if (res && !res.error) P = res; else msg = { ok: false, text: (res && res.error) || 'Gagal' };
            }
            render();
        });
        if (stab === 'unpaid') renderUnpaid();
        else renderPrices();
    }

    // ------------------------------------------------------------ supplier: semua mekanik melihat stok, hanya Manager membeli
    function renderSupplierPage() {
        $('ks-kicker').textContent = 'Supplier Bahan Baku · Mekanik';
        $('ks-title').textContent = 'Stok Gudang Bengkel';
        $('ks-pills').innerHTML = `<span class="pill bank">🏦 Rekening Bengkel ${money(S.balance)}</span>`
            + (S.canBuy ? '' : '<span class="pill">🔒 Hanya lihat</span>');
        const body = $('ks-body');
        body.className = 'ks-body staff';
        body.innerHTML = `<div style="padding:12px 18px 0">${msgHtml()}</div><div class="ks-pane" id="ks-pane"></div>`;
        renderSupplier();
    }

    const supTotal = () => S.items.reduce((t, it) => t + (cart[it.item] || 0) * it.price, 0);

    // bar bawah (total + tombol) diperbarui sendiri, supaya mengisi jumlah tidak menggambar ulang tabel
    function fillSupBar() {
        const bar = $('ks-supbar');
        if (!bar) return;
        const total = supTotal(), n = Object.keys(cart).length, short = total > S.balance;
        bar.innerHTML = `<small>${n ? `${n} bahan · total <b style="color:${short ? 'var(--c4)' : 'var(--accent)'}">${money(total)}</b>${short ? ' · saldo tidak cukup' : ''}` : 'Isi jumlah bahan yang mau dibeli'}</small>
            <button class="ghost" id="ks-sclear" ${n ? '' : 'disabled'}>Kosongkan</button>
            <button class="primary" id="ks-sbuy" ${n && !short ? '' : 'disabled'}>Beli ${n ? money(total) : ''}</button>`;
        $('ks-sclear').onclick = () => keepScroll(() => { cart = {}; renderSupplier(); });
        $('ks-sbuy').onclick = () => {
            const lines = S.items.filter(it => cart[it.item]).map(it => `<div><span>${cart[it.item]}× ${esc(it.label)}</span><span>${money(cart[it.item] * it.price)}</span></div>`).join('');
            modal(`<h2>Beli suku cadang?</h2><div class="sumbox">${lines}<div class="tot"><span>Total</span><b>${money(total)}</b></div></div>
                <p class="note">Dipotong dari rekening bengkel.</p>`, async () => {
                const res = await post('ksSupplierBuy', { cart });
                if (res && !res.error) { S = D = res; cart = {}; msg = { ok: true, text: res.msg }; }
                else {
                    if (res && res.items) S = D = res;
                    msg = { ok: false, text: (res && res.error) || 'Gagal membeli' };
                }
                keepScroll(render);
            });
        };
    }

    function renderSupplier() {
        const pane = $('ks-pane');
        const buy = S.canBuy;
        pane.innerHTML = `
            <div class="ks-tools"><small>${buy
                ? 'Beli ke supplier: dibayar dari <b>rekening bengkel</b>, langsung menambah stok.'
                : 'Stok dipotong otomatis saat memperbaiki. Pembelian ke supplier hanya oleh <b>Manager</b>.'}</small>
                <span style="flex:1"></span><button class="ghost" id="ks-sreload">Muat Ulang</button></div>
            <div class="ks-table ks-scroll ks-sup" style="flex:1"><table>
                <thead><tr><th>Bahan</th><th>Dipakai untuk</th><th style="text-align:right">Stok</th>
                    ${buy ? '<th style="text-align:right">Harga</th><th style="text-align:right">Beli</th><th style="text-align:right">Subtotal</th>' : ''}</tr></thead>
                <tbody>${S.items.map(it => `<tr>
                    <td><span class="ks-it">${itemImg(it.item, '', 'iimg lg')}<b>${esc(it.label)}</b></span></td><td><small>${esc(it.use || '')}</small></td>
                    <td style="text-align:right"><b style="color:${it.qty ? 'var(--text)' : 'var(--c4)'}">${it.qty}</b></td>
                    ${buy ? `<td style="text-align:right">${money(it.price)}</td>
                    <td style="text-align:right"><input type="number" min="0" max="${S.max}" step="1" data-i="${esc(it.item)}"
                        value="${cart[it.item] || 0}" class="${cart[it.item] ? 'changed' : ''}"></td>
                    <td style="text-align:right" data-sub="${esc(it.item)}">${cart[it.item] ? `<b>${money(cart[it.item] * it.price)}</b>` : '<small>—</small>'}</td>` : ''}
                </tr>`).join('')}</tbody>
            </table></div>
            ${buy ? '<div class="ks-savebar" id="ks-supbar"></div>' : ''}`;
        $('ks-sreload').onclick = async () => {
            const res = await post('ksSupplier');
            if (res && !res.error) { S = D = res; msg = null; } else msg = { ok: false, text: (res && res.error) || 'Gagal' };
            keepScroll(render);
        };
        if (!buy) return;
        pane.querySelectorAll('input[data-i]').forEach(i => i.onchange = () => {
            const it = S.items.find(x => x.item === i.dataset.i);
            const v = Math.max(0, Math.min(S.max, Math.floor(Number(i.value) || 0)));
            if (v) cart[it.item] = v; else delete cart[it.item];
            i.value = v;
            i.classList.toggle('changed', v > 0);
            pane.querySelector(`[data-sub="${CSS.escape(it.item)}"]`).innerHTML = v ? `<b>${money(v * it.price)}</b>` : '<small>—</small>';
            fillSupBar();
        });
        fillSupBar();
    }

    // ------------------------------------------------------------ gudang (mekanik): setor bahan, satu arah
    function renderGudang() {
        $('ks-kicker').textContent = 'Gudang Bengkel · Mekanik';
        $('ks-title').textContent = 'Setor Bahan ke Stok';
        $('ks-pills').innerHTML = D.bag
            ? '<span class="pill cash">🧰 Tas Perkakas aktif</span>'
            : '<span class="pill" style="color:#fdba74;border-color:rgba(249,115,22,.35)">🧰 Belum bawa Tas Perkakas</span>';
        const body = $('ks-body');
        body.className = 'ks-body staff';
        const rows = D.items.filter(it => it.have > 0);
        body.innerHTML = `
            <div style="padding:12px 18px 0">${msgHtml()}</div>
            <div class="ks-pane">
                <div class="ks-tools"><small>Bahan dari tasmu masuk <b>Stok Gudang</b> dan <b>tidak bisa diambil kembali</b>. Dipakai otomatis saat memperbaiki.</small>
                    <span style="flex:1"></span>${D.bag ? '' : '<button class="primary" id="ks-bag">Ambil Tas Perkakas</button>'}</div>
                <div class="ks-table ks-scroll ks-sup" style="flex:1"><table>
                    <thead><tr><th>Bahan</th><th>Dipakai untuk</th><th style="text-align:right">Di tasmu</th><th style="text-align:right">Stok gudang</th><th style="text-align:right">Setor</th></tr></thead>
                    <tbody>${rows.map(it => `<tr>
                        <td><span class="ks-it">${itemImg(it.item, '', 'iimg lg')}<b>${esc(it.label)}</b></span></td><td><small>${esc(it.use || '')}</small></td>
                        <td style="text-align:right">${it.have}</td><td style="text-align:right">${it.qty}</td>
                        <td style="text-align:right"><input type="number" min="0" max="${Math.min(it.have, D.max)}" step="1" data-i="${esc(it.item)}"
                            value="${cart[it.item] || 0}" class="${cart[it.item] ? 'changed' : ''}">
                            <button class="btn sm" data-all="${esc(it.item)}">Semua</button></td>
                    </tr>`).join('') || '<tr><td colspan="5" class="note" style="text-align:center;padding:30px">Tidak ada bahan bengkel di tasmu.</td></tr>'}</tbody>
                </table></div>
                <div class="ks-savebar"><small id="ks-depinfo"></small>
                    <button class="ghost" id="ks-dclear">Kosongkan</button>
                    <button class="primary" id="ks-dep">Setor ke Stok</button></div>
            </div>`;
        // isi jumlah diperbarui di tempat (tanpa gambar ulang tabel) supaya posisi scroll tidak lompat
        const fillDepBar = () => {
            const n = Object.keys(cart).length, count = Object.values(cart).reduce((a, b) => a + b, 0);
            $('ks-depinfo').textContent = n ? `${count} bahan akan disetor` : 'Isi jumlah bahan yang mau disetor';
            $('ks-dclear').disabled = $('ks-dep').disabled = !n;
        };
        const limit = item => { const it = D.items.find(x => x.item === item); return it ? Math.min(it.have, D.max) : 0; };
        const setQty = (input, v) => {
            if (v) cart[input.dataset.i] = v; else delete cart[input.dataset.i];
            input.value = v;
            input.classList.toggle('changed', v > 0);
            fillDepBar();
        };
        body.querySelectorAll('input[data-i]').forEach(i => i.onchange = () =>
            setQty(i, Math.max(0, Math.min(limit(i.dataset.i), Math.floor(Number(i.value) || 0)))));
        body.querySelectorAll('[data-all]').forEach(b => b.onclick = () =>
            setQty(body.querySelector(`input[data-i="${CSS.escape(b.dataset.all)}"]`), limit(b.dataset.all)));
        fillDepBar();
        $('ks-dclear').onclick = () => keepScroll(() => { cart = {}; renderGudang(); });
        $('ks-dep').onclick = () => {
            const lines = D.items.filter(it => cart[it.item]).map(it => `<div><span>${esc(it.label)}</span><span>${cart[it.item]}×</span></div>`).join('');
            modal(`<h2>Setor ke Stok Gudang?</h2><div class="sumbox">${lines}</div>
                <p class="note">Bahan tidak bisa diambil kembali dari stok.</p>`, async () => {
                const res = await post('ksDeposit', { cart });
                if (res && !res.error) { D = res; cart = {}; msg = { ok: true, text: res.msg }; }
                else {
                    if (res && res.items) D = res;
                    msg = { ok: false, text: (res && res.error) || 'Gagal menyetor' };
                }
                keepScroll(render);
            });
        };
        const bag = $('ks-bag');
        if (bag) bag.onclick = async () => {
            bag.disabled = true;
            const res = await post('ksBag');
            if (res && !res.error) { D = res; msg = { ok: true, text: 'Tas Perkakas diambil. Berlaku 2 hari.' }; }
            else msg = { ok: false, text: (res && res.error) || 'Gagal' };
            render();
        };
    }

    function renderUnpaid() {
        const pane = $('ks-pane');
        const q = query.toLowerCase();
        const rows = D.bills.filter(b => !q || `${b.id} ${b.name} ${b.plate}`.toLowerCase().includes(q));
        pane.innerHTML = `
            <div class="ks-tools"><input id="ks-q" placeholder="Cari nama / plat / no. tagihan" value="${esc(query)}">
                <span style="flex:1"></span><button class="ghost" id="ks-reload">Muat Ulang</button></div>
            <div class="ks-cards">
                <div class="card"><small>Belum dibayar</small><b>${D.unpaid}</b></div>
                <div class="card"><small>Menunggu transfer</small><b>${D.wait}</b></div>
                <div class="card"><small>Total belum masuk</small><b style="color:var(--accent)">${money(D.sum)}</b></div>
            </div>
            <div class="ks-table ks-scroll"><table>
                <thead><tr><th>No.</th><th>Jenis</th><th>Pelanggan</th><th>Plat</th><th>Dibuat</th><th>Status</th><th style="text-align:right">Total</th><th></th></tr></thead>
                <tbody>${rows.map(b => `<tr>
                    <td><b>#${b.id}</b></td><td><span class="tag ${b.kind}">${kindLabel(b.kind)}</span></td><td>${esc(b.name)}</td><td>${esc(b.plate)}</td>
                    <td>${clock(b.at)}<br><small>${esc(b.by)}</small></td>
                    <td><span class="tag ${b.status === 'wait' ? 'wait' : 'unpaid'}">${b.status === 'wait' ? 'Menunggu transfer' : 'Belum bayar'}</span></td>
                    <td style="text-align:right"><b>${money(b.total)}</b></td>
                    <td><div class="ks-acts"><button class="btn sm" data-d="${b.id}">Detail</button><button class="btn sm danger" data-x="${b.id}">Hapus</button></div></td>
                </tr>`).join('') || '<tr><td colspan="8" class="note" style="text-align:center;padding:30px">Tidak ada tagihan.</td></tr>'}</tbody>
            </table></div>`;
        const qi = $('ks-q');
        qi.oninput = () => { query = qi.value; renderUnpaid(); const n = $('ks-q'); n.focus(); n.setSelectionRange(n.value.length, n.value.length); };
        $('ks-reload').onclick = async () => apply(await post('ksStaff'));
        pane.querySelectorAll('[data-d]').forEach(btn => btn.onclick = () => {
            const b = D.bills.find(x => x.id === Number(btn.dataset.d));
            const wrap = document.createElement('div');
            wrap.className = 'ks-modal';
            wrap.innerHTML = `<div><h2>Tagihan #${b.id}</h2><p class="note">${esc(b.name)} · ${esc(b.plate)} · ${kindLabel(b.kind)}</p>
                <div class="sumbox">${b.items.map(l => `<div><span>${esc(l.label)}${l.desc ? ' · ' + esc(l.desc) : ''}</span><span>${money(l.price)}</span></div>`).join('')}
                <div class="tot"><span>Total</span><b>${money(b.total)}</b></div></div>
                <div class="row2"><button class="ghost" data-x>Tutup</button></div></div>`;
            document.body.appendChild(wrap);
            wrap.querySelector('[data-x]').onclick = () => wrap.remove();
        });
        pane.querySelectorAll('[data-x]').forEach(btn => btn.onclick = () => {
            const b = D.bills.find(x => x.id === Number(btn.dataset.x));
            modal(`<h2>Hapus tagihan #${b.id}?</h2><p class="note">${esc(b.name)} · ${money(b.total)}
                ${b.status === 'wait' ? '<br>Invoice di HP pelanggan juga ditarik.' : ''}
                ${b.kind === 'custom' ? '<br>Order kustom batal, pelanggan bisa membuat order baru.' : ''}</p>`,
                async () => apply(await post('ksDelete', { bill: b.id })));
        });
    }

    function renderPrices() {
        const pane = $('ks-pane');
        if (!D.canPrice) {
            pane.innerHTML = '<div class="big-empty"><span>🔒</span>Master Harga hanya untuk grade tertentu.</div>';
            return;
        }
        if (!P) { pane.innerHTML = '<div class="note" style="padding:18px">Memuat…</div>'; return; }
        const n = Object.keys(edits).length;
        const cat = P.list[pcat] || P.list[0];
        pane.innerHTML = `
            <div class="ks-tools"><small>Harga berlaku untuk tagihan <b>baru</b>. Tagihan yang sudah dibuat tidak berubah.</small></div>
            <div class="ks-prices" style="flex:1">
                <div class="ks-pcats ks-scroll">${P.list.map((c, i) => {
                    const changed = c.items.filter(it => it.code in edits).length;
                    return `<button class="ks-pcat ${i === pcat ? 'on' : ''}" data-c="${i}"><span>${esc(c.cat)}</span><small>${changed ? `<span style="color:var(--c2)">●${changed}</span>` : c.items.length}</small></button>`;
                }).join('')}</div>
                <div class="ks-pitems ks-scroll"><div class="ks-table" style="padding:0"><table>
                    <thead><tr><th>Item</th><th style="text-align:right">Harga Awal</th><th style="text-align:right">Harga</th></tr></thead>
                    <tbody>${cat.items.map(it => `<tr><td>${esc(it.label)}</td><td style="text-align:right"><small>${money(it.default)}</small></td>
                        <td style="text-align:right">Rp <input type="number" min="0" max="${P.max}" data-k="${esc(it.code)}" data-o="${it.price}"
                            value="${it.code in edits ? edits[it.code] : it.price}" class="${it.code in edits ? 'changed' : ''}"></td></tr>`).join('')}</tbody>
                </table></div></div>
            </div>
            <div class="ks-savebar"><small>${n ? `<span style="color:var(--c2)">${n} harga diubah</span> · belum disimpan` : 'Tidak ada perubahan'}</small>
                <button class="ghost" id="ks-undo" ${n ? '' : 'disabled'}>Batalkan</button><button class="primary" id="ks-save" ${n ? '' : 'disabled'}>Simpan Harga</button></div>`;
        pane.querySelectorAll('[data-c]').forEach(b => b.onclick = () => { pcat = Number(b.dataset.c); renderPrices(); });
        pane.querySelectorAll('input[data-k]').forEach(i => i.onchange = () => {
            const v = Math.max(0, Math.min(P.max, Math.floor(Number(i.value) || 0)));
            if (v === Number(i.dataset.o)) delete edits[i.dataset.k]; else edits[i.dataset.k] = v;
            keepScroll(renderPrices);
        });
        $('ks-undo').onclick = () => keepScroll(() => { edits = {}; renderPrices(); });
        $('ks-save').onclick = async () => {
            $('ks-save').disabled = true;
            const res = await post('ksPricesSave', { changes: edits });
            if (res && !res.error) { P = res; edits = {}; msg = { ok: true, text: res.msg }; }
            else msg = { ok: false, text: (res && res.error) || 'Gagal menyimpan' };
            render();
        };
    }

    function render() {
        if (!D) return;
        if (mode === 'staff') renderStaff();
        else if (mode === 'gudang') renderGudang();
        else if (mode === 'supplier') renderSupplierPage();
        else renderCustomer();
    }

    $('ks-close').onclick = () => post('ksClose');
    document.addEventListener('keyup', e => {
        if (e.key === 'Escape' && !$('kasir').classList.contains('hidden')) post('ksClose');
    });

    window.addEventListener('message', e => {
        const d = e.data || {};
        if (d.action === 'kasirOpen') {
            mode = d.mode; D = d.data; msg = null; sel = null; method = 'cash';
            stab = 'unpaid'; query = ''; P = null; pcat = 0; edits = {}; cart = {};
            S = mode === 'supplier' ? D : null;
            $('kasir').classList.remove('hidden');
            render();
        } else if (d.action === 'kasirClose') {
            $('kasir').classList.add('hidden');
            document.querySelectorAll('.ks-modal').forEach(m => m.remove());
            D = null;
        }
    });
})();
