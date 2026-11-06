// Kasir EMS. Mode 'patient': bayar tagihan kasir (cash / transfer), ambil obat saat tidak ada EMS.
// Mode 'staff': Approval, Belum Dibayar, Stok Gudang, Supplier (Boss), Daftar Harga (Boss), Pengaturan.
(() => {
    const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'f_ambulancejob';
    const post = (name, data) => fetch(`https://${RES}/${name}`, { method: 'POST', body: JSON.stringify(data || {}) })
        .then(r => r.json()).catch(() => null);
    const $ = id => document.getElementById(id);
    const esc = s => String(s ?? '').replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
    const money = n => 'Rp ' + Number(n || 0).toLocaleString('id-ID');
    const clock = ts => { const d = new Date(ts * 1000); return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`; };
    const KIND_CLASS = { apotek: 'apotek', operasi: 'operasi', tindakan: 'tindakan' };

    let mode = null;       // 'patient' | 'staff'
    let D = null;          // data dari server
    let tab = 'approval';
    let cart = {};         // supplier: key -> jumlah
    let priceEdit = {};    // daftar harga: code -> harga baru
    let payMethod = {};    // pasien: id tagihan -> 'cash' | 'transfer'
    let msg = null;        // { ok, text }

    const msgHtml = () => msg ? `<div class="${msg.ok ? 'empty' : 'msg'}">${esc(msg.text)}</div>` : '';
    const tag = b => `<span class="tag ${KIND_CLASS[b.kind] || ''}">${esc(b.kindLabel)}</span>`;
    const lines = b => (b.items || []).map(l => l.qty
        ? `<li><span>${l.qty}× ${esc(l.label)}</span><span>${money(l.qty * l.price)}</span></li>`
        : `<li><span>${esc(l.label)}</span><span>${money(l.price)}</span></li>`).join('');

    function apply(res, okText) {
        if (!res) { msg = { ok: false, text: 'Gagal' }; return render(); }
        if (res.bills || res.approvals || res.stock) D = Object.assign(D, res);
        msg = res.error ? { ok: false, text: res.error } : (res.msg || okText) ? { ok: true, text: res.msg || okText } : null;
        render();
    }

    // ================================================================ PASIEN
    function renderPatient() {
        $('ks-title').textContent = 'Kasir Rumah Sakit';
        $('ks-sub').textContent = `Tagihan atas nama ${D.name}`;
        $('ks-tabs').innerHTML = '';
        let h = msgHtml();
        if (!D.bills.length) h += '<div class="empty">✔ Tidak ada tagihan yang perlu dibayar.</div>';
        D.bills.forEach(b => {
            const unpaid = b.status === 'unpaid';
            const m = payMethod[b.id] || 'cash';
            h += `<div class="bill"><div class="top"><span class="code">#${b.id}</span>${tag(b)}
                <div class="who">${esc(b.by || '')}<span>${clock(b.at)}${unpaid ? '' : ' · lunas'}</span></div></div>
                <ul>${lines(b)}<li class="tot"><span>Total</span><span>${money(b.total)}</span></li></ul>`;
            if (unpaid) {
                h += b.invoice
                    ? '<div class="note">📱 Invoice sudah dikirim ke HP. Bayar lewat Bank &gt; Invoices, atau pilih Cash di sini.</div>'
                    : '';
                h += `<div class="choose" data-bill="${b.id}">
                        <button data-m="cash" class="${m === 'cash' ? 'on' : ''}"><b>💵 Cash</b><span>Uang tunai di tas · kamu punya ${money(D.cash)}</span></button>
                        ${D.transfer ? `<button data-m="transfer" class="${m === 'transfer' ? 'on' : ''}"><b>📱 Transfer</b><span>Invoice dikirim ke HP, bayar dari Bank</span></button>` : ''}
                    </div>
                    <div class="acts"><button class="primary" data-pay="${b.id}">${m === 'cash' ? `Bayar ${money(b.total)}` : (b.invoice ? 'Invoice sudah dikirim' : 'Kirim Invoice ke HP')}</button></div>`;
            } else if (D.ems > 0) {
                h += '<div class="note">✅ Lunas. Temui petugas EMS di kasir untuk menerima obatmu.</div>';
            } else {
                h += `<div class="note">✅ Lunas. Tidak ada EMS bertugas, ambil obatmu sendiri.</div>
                    <div class="acts"><button class="primary" data-claim="${b.id}">🎒 Ambil Obat</button></div>`;
            }
            h += '</div>';
        });
        const body = $('ks-body');
        body.innerHTML = h;
        body.querySelectorAll('.choose[data-bill]').forEach(g => g.querySelectorAll('[data-m]').forEach(b => b.onclick = () => {
            payMethod[g.dataset.bill] = b.dataset.m; msg = null; render();
        }));
        body.querySelectorAll('[data-pay]').forEach(b => b.onclick = async () => {
            b.disabled = true;
            apply(await post('ksPay', { id: Number(b.dataset.pay), method: payMethod[b.dataset.pay] || 'cash' }));
        });
        body.querySelectorAll('[data-claim]').forEach(b => b.onclick = async () => {
            b.disabled = true;
            apply(await post('ksClaim', { id: Number(b.dataset.claim) }));
        });
    }

    // ================================================================ PETUGAS
    const TABS = () => [
        ['approval', '✅ Approval', D.approvals.length],
        ['unpaid', '⏳ Belum Dibayar', D.unpaid.length],
        ['gudang', '📦 Stok Gudang'],
        ['supplier', `${D.boss ? '' : '🔒 '}🚚 Supplier`, 0, !D.boss],
        ['harga', `${D.boss ? '' : '🔒 '}🏷️ Daftar Harga`, 0, !D.boss],
        ['setting', '⚙️ Pengaturan'],
    ];

    function renderTabs() {
        $('ks-tabs').innerHTML = TABS().map(([id, label, badge, lock]) =>
            `<button data-t="${id}" class="${id === tab ? 'on' : ''} ${lock ? 'lock' : ''}">${label}${badge ? `<span class="badge">${badge}</span>` : ''}</button>`).join('');
        $('ks-tabs').querySelectorAll('[data-t]').forEach(b => b.onclick = () => { tab = b.dataset.t; msg = null; render(); $('ks-body').scrollTop = 0; });
    }

    function renderApproval() {
        let h = msgHtml() + '<div class="lock-note">Tagihan yang <b>sudah dibayar</b> di kasir. Pasien harus berdiri dekat kamu. Kalau tas pasien penuh, tekan Approve lagi setelah tasnya dikosongkan.</div>';
        if (!D.approvals.length) h += '<div class="empty">✔ Tidak ada yang menunggu approval.</div>';
        D.approvals.forEach(b => {
            const chip = !b.online ? '<span class="chip no">Offline</span>' : b.near ? '<span class="chip ok">Di dekatmu</span>' : '<span class="chip no">Jauh</span>';
            h += `<div class="bill"><div class="top"><span class="code">#${b.id}</span>${tag(b)}
                <div class="who">${esc(b.name)}<span>lunas ${clock(b.paidAt || b.at)} · ${esc(b.method || '')}</span></div>${chip}</div>
                <ul>${lines(b)}</ul>
                <div class="acts"><button class="primary" data-approve="${b.id}" ${b.near ? '' : 'disabled'}>
                    ${!b.near ? 'Pasien harus dekat kamu' : b.deliver === 'pending' ? '✅ Approve &amp; Serahkan Obat' : '✅ Approve'}</button></div></div>`;
        });
        return h;
    }

    function renderUnpaid() {
        let h = msgHtml();
        h += `<div class="cards"><div class="card-sum"><small>Belum dibayar</small><b>${D.unpaid.length}</b></div>
            <div class="card-sum"><small>Total belum masuk</small><b style="color:var(--accent)">${money(D.unpaidSum)}</b></div></div>`;
        if (!D.unpaid.length) return h + '<div class="empty">✔ Semua tagihan sudah dibayar.</div>';
        h += '<table class="list"><thead><tr><th>#</th><th>Jenis</th><th>Pasien</th><th>Waktu</th><th>Status</th><th class="n">Total</th><th></th></tr></thead><tbody>';
        D.unpaid.forEach(b => {
            const status = b.invoice ? '<span class="chip info">Menunggu transfer</span>' : '<span class="chip no">Belum bayar</span>';
            const when = b.kind === 'apotek' ? `batal otomatis ${clock(b.at + D.timeout * 60)}` : esc(b.by || '');
            h += `<tr><td><b>#${b.id}</b></td><td>${tag(b)}<br><small>${b.channel === 'kasir' ? 'kasir' : 'langsung'}</small></td><td>${esc(b.name)}</td>
                <td>${clock(b.at)}<br><small>${when}</small></td><td>${status}</td><td class="n"><b>${money(b.total)}</b></td>
                <td><div class="row-acts"><button class="ghost" data-cancel="${b.id}">Batal</button>
                    ${b.kind === 'apotek' ? '' : `<button class="btn-warn" data-collect="${b.id}">Tagih Paksa</button>`}</div></td></tr>`;
        });
        h += '</tbody></table>';
        h += '<div class="lock-note"><b>Tagih Paksa</b> memotong saldo bank pasien (online maupun offline, boleh sampai minus) lalu mengirim email. <b>Batal</b> pada pesanan apotek mengembalikan stok ke gudang.</div>';
        return h;
    }

    function bindUnpaid(body) {
        const confirm2 = (b, text, fn) => async () => {
            if (b.dataset.sure !== '1') { b.dataset.sure = '1'; b.textContent = text; return; }
            b.disabled = true; apply(await fn());
        };
        body.querySelectorAll('[data-cancel]').forEach(b => b.onclick = confirm2(b, 'Yakin batal?', () => post('ksCancel', { id: Number(b.dataset.cancel) })));
        body.querySelectorAll('[data-collect]').forEach(b => b.onclick = confirm2(b, 'Yakin tagih?', () => post('ksCollect', { id: Number(b.dataset.collect) })));
    }

    function renderGudang() {
        let h = msgHtml() + '<div class="lock-note">Stok hanya bisa <b>dilihat</b>. Dipotong otomatis oleh pesanan apotek, tindakan Cek Pasien, operasi, dan transfusi. Tidak ada masa berlaku di gudang.</div>';
        h += '<table class="list"><thead><tr><th>Item</th><th>Dipakai untuk</th><th class="n">Stok</th></tr></thead><tbody>';
        D.stock.forEach(s => {
            h += `<tr><td>${s.emoji || ''} ${esc(s.label)}</td><td>${esc(s.use)}</td>
                <td class="n ${s.qty > 0 ? 'stock-ok' : 'stock-low'}">${s.qty.toLocaleString('id-ID')}${s.unitLabel ? ' ' + esc(s.unitLabel) : ''}</td></tr>`;
        });
        return h + '</tbody></table>';
    }

    const buyable = () => D.stock.filter(s => s.hpp != null);
    const cartCost = () => buyable().reduce((sum, s) => sum + (cart[s.key] || 0) * s.hpp, 0);
    const cartCount = () => Object.values(cart).reduce((a, b) => a + b, 0);

    function renderSupplier() {
        let h = msgHtml();
        if (!D.boss) return h + '<div class="lock-note">🔒 Hanya <b>Boss</b> yang bisa membeli obat ke supplier. Stok yang dibeli langsung masuk Stok Gudang.</div>';
        h += `<div class="lock-note">Dibayar dari <b>rekening organisasi EMS</b> · saldo saat ini <b>${money(D.balance)}</b>. Barang langsung masuk Stok Gudang.</div>`;
        h += '<table class="list"><thead><tr><th>Item</th><th class="n">Harga</th><th class="n">Stok</th><th class="n">Beli</th></tr></thead><tbody>';
        buyable().forEach(s => {
            const n = cart[s.key] || 0;
            const per = s.units > 1 ? ` <small>(+${s.units} ${esc(s.unitLabel || 'pcs')})</small>` : '';
            h += `<tr><td>${s.emoji || ''} ${esc(s.label)}${per}</td><td class="n">${money(s.hpp)}</td><td class="n">${s.qty.toLocaleString('id-ID')}</td>
                <td class="n"><span class="buyqty">
                    <button data-dec="${s.key}" ${n <= 0 ? 'disabled' : ''}>−</button>
                    <input data-qty="${s.key}" type="number" min="0" max="${D.maxPerBuy}" value="${n}">
                    <button data-inc="${s.key}" ${n >= D.maxPerBuy ? 'disabled' : ''}>+</button></span></td></tr>`;
        });
        return h + `</tbody></table><div class="cart-bar" id="ks-cartbar">${supplierBar()}</div>`;
    }

    function supplierBar() {
        const cost = cartCost();
        return `<div class="sum"><small>${cartCount()} pcs dipilih</small><br><strong>${money(cost)}</strong></div>
            <button class="primary" id="ks-buy" style="padding:11px 18px" ${cost <= 0 || cost > D.balance ? 'disabled' : ''}>
                ${cost > D.balance ? 'Saldo tidak cukup' : 'Beli ke Supplier'}</button>`;
    }

    function bindSupplier(body) {
        // ubah jumlah di tempat (tanpa gambar ulang tabel) supaya posisi scroll & fokus tidak hilang
        const set = (key, v) => {
            const n = cart[key] = Math.max(0, Math.min(D.maxPerBuy, Math.floor(Number(v) || 0)));
            const k = CSS.escape(key);
            body.querySelector(`[data-qty="${k}"]`).value = n;
            body.querySelector(`[data-dec="${k}"]`).disabled = n <= 0;
            body.querySelector(`[data-inc="${k}"]`).disabled = n >= D.maxPerBuy;
            $('ks-cartbar').innerHTML = supplierBar();
            bindBuy();
        };
        body.querySelectorAll('[data-inc]').forEach(b => b.onclick = () => set(b.dataset.inc, (cart[b.dataset.inc] || 0) + 1));
        body.querySelectorAll('[data-dec]').forEach(b => b.onclick = () => set(b.dataset.dec, (cart[b.dataset.dec] || 0) - 1));
        body.querySelectorAll('[data-qty]').forEach(i => i.onchange = () => set(i.dataset.qty, i.value));
        bindBuy();
    }

    function bindBuy() {
        const buy = $('ks-buy');
        if (buy) buy.onclick = async () => {
            if (buy.dataset.sure !== '1') { buy.dataset.sure = '1'; buy.textContent = `Yakin beli ${money(cartCost())}? Klik lagi`; return; }
            buy.disabled = true;
            const res = await post('ksBuy', { cart });
            if (res && res.msg) cart = {};
            apply(res);
        };
    }

    function renderHarga() {
        let h = msgHtml() + `<div class="lock-note">${D.boss ? 'Ubah harga lalu tekan Simpan.' : '🔒 Hanya <b>Boss</b> yang bisa mengubah harga.'} Harga tindakan adalah harga normal; petugas tetap bisa memberi diskon di tab Tagihan Cek Pasien.</div>`;
        [['apotek', 'Apotek'], ['tindakan', 'Tindakan & operasi']].forEach(([group, title]) => {
            h += `<table class="list"><thead><tr><th>${title}</th><th class="n">Default</th><th class="n">Harga</th></tr></thead><tbody>`;
            D.prices.filter(p => p.group === group).forEach(p => {
                const v = priceEdit[p.code] ?? p.price;
                h += `<tr><td>${esc(p.label)}</td><td class="n">${money(p.default)}</td>
                    <td class="n"><input data-price="${p.code}" type="number" min="0" value="${v}" ${D.boss ? '' : 'disabled'}></td></tr>`;
            });
            h += '</tbody></table>';
        });
        if (D.boss) h += `<div class="cart-bar" id="ks-pricebar">${hargaBar()}</div>`;
        return h;
    }

    function hargaBar() {
        const n = Object.keys(priceEdit).length;
        return `<div class="sum"><small>${n ? `${n} harga diubah, belum disimpan` : 'Belum ada perubahan'}</small></div>
            <button class="primary" id="ks-save-price" style="padding:11px 18px" ${n ? '' : 'disabled'}>Simpan Harga</button>`;
    }

    function bindHarga(body) {
        body.querySelectorAll('[data-price]').forEach(i => i.onchange = () => {
            const p = D.prices.find(x => x.code === i.dataset.price);
            const v = Math.max(0, Math.floor(Number(i.value) || 0));
            i.value = v;
            if (p && v !== p.price) priceEdit[p.code] = v; else delete priceEdit[i.dataset.price];
            $('ks-pricebar').innerHTML = hargaBar();
            bindSavePrice();
        });
        bindSavePrice();
    }

    function bindSavePrice() {
        const save = $('ks-save-price');
        if (save) save.onclick = async () => {
            save.disabled = true;
            const res = await post('ksPrices', { changes: priceEdit });
            if (res && res.msg) priceEdit = {};
            apply(res);
        };
    }

    function renderSetting() {
        const L = D.limits;
        const dis = D.canSettings ? '' : 'disabled';
        return msgHtml() + `
            <div class="set-row"><div class="name"><b>Maksimal obat per pesanan · ada EMS bertugas</b><span>Obat diserahkan petugas lewat Approval (1 - ${L.max})</span></div>
                <input id="lim-ems" type="number" min="1" max="${L.max}" value="${L.withEms}" ${dis}></div>
            <div class="set-row"><div class="name"><b>Maksimal obat per pesanan · tanpa EMS bertugas</b><span>Setelah membeli, pemain menunggu 1 jam atau sampai ada EMS bertugas (1 - ${L.max})</span></div>
                <input id="lim-noems" type="number" min="1" max="${L.max}" value="${L.withoutEms}" ${dis}></div>
            ${D.canSettings ? '<button class="primary" id="ks-save-lim">Simpan Pengaturan</button>' : '<div class="lock-note">Grade kamu belum bisa mengubah pengaturan.</div>'}`;
    }

    function bindSetting() {
        const save = $('ks-save-lim');
        if (save) save.onclick = async () => {
            save.disabled = true;
            apply(await post('ksLimits', { withEms: Number($('lim-ems').value), withoutEms: Number($('lim-noems').value) }));
        };
    }

    function renderStaff() {
        $('ks-title').textContent = 'Kasir EMS';
        $('ks-sub').textContent = `${D.name} · ${D.grade}${D.boss ? ' · Boss' : ''}`;
        renderTabs();
        const body = $('ks-body');
        const views = {
            approval: [renderApproval, b => b.querySelectorAll('[data-approve]').forEach(x => x.onclick = async () => {
                x.disabled = true; apply(await post('ksApprove', { id: Number(x.dataset.approve) }));
            })],
            unpaid: [renderUnpaid, bindUnpaid],
            gudang: [renderGudang, () => {}],
            supplier: [renderSupplier, bindSupplier],
            harga: [renderHarga, bindHarga],
            setting: [renderSetting, bindSetting],
        };
        const [draw, bind] = views[tab] || views.approval;
        body.innerHTML = draw();
        bind(body);
    }

    // gambar ulang tanpa melompat ke atas (posisi scroll dikembalikan)
    function render() {
        const body = $('ks-body'), top = body.scrollTop;
        if (mode === 'staff') renderStaff(); else renderPatient();
        body.scrollTop = top;
    }

    // jangan menimpa layar saat petugas sedang mengetik
    const typing = () => ['INPUT', 'TEXTAREA'].includes(document.activeElement?.tagName);

    $('ks-close').onclick = () => post('ksClose');
    document.addEventListener('keyup', e => {
        if (e.key === 'Escape' && !$('kasir').classList.contains('hidden')) post('ksClose');
    });

    window.addEventListener('message', e => {
        const d = e.data || {};
        if (d.action === 'kasirOpen') {
            mode = d.mode; D = d.data; tab = 'approval'; cart = {}; priceEdit = {}; payMethod = {}; msg = null;
            render();
            $('ks-body').scrollTop = 0;
            $('kasir').classList.remove('hidden');
        } else if (d.action === 'kasirUpdate') {
            if (!D || typing() || (mode === 'staff' && (tab === 'supplier' || tab === 'harga'))) return;
            D = Object.assign(D, d.data);
            render();
        } else if (d.action === 'kasirClose') {
            $('kasir').classList.add('hidden');
            mode = null;
        }
    });
})();
