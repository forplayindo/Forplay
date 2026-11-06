// Toko bengkel: warga memesan (maks. batas per pembelian), mekanik menyerahkan / menolak.
(() => {
    const RES = typeof GetParentResourceName === 'function' ? GetParentResourceName() : 'f_mechanicjob';
    const post = (name, data) => fetch(`https://${RES}/${name}`, { method: 'POST', body: JSON.stringify(data || {}) })
        .then(r => r.json()).catch(() => null);
    const $ = id => document.getElementById(id);
    const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

    let mode = null, menu = null, staff = null, cart = {}, method = 'cash', msg = null;

    const msgHtml = () => msg ? `<div class="${msg.ok ? 'empty' : 'msg'}">${esc(msg.text)}</div>` : '';
    const clock = ts => { const d = new Date(ts * 1000); return `${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`; };
    const count = () => Object.values(cart).reduce((a, b) => a + b, 0);
    const total = () => menu.items.reduce((s, m) => s + (cart[m.item] || 0) * m.price, 0);

    function renderCustomer() {
        $('sh-title').textContent = menu.label;
        $('sh-sub').textContent = menu.staff > 0 ? `${menu.staff} mekanik bertugas` : 'Tidak ada mekanik bertugas';
        const body = $('sh-body'), foot = $('sh-foot');
        let h = msgHtml();

        if (menu.active) {
            const a = menu.active;
            h += `<div class="sh-status"><h2>Pesanan #${a.code} · Rp ${a.total}</h2>
                ${a.status === 'unpaid'
                    ? `<span class="chip info" style="align-self:flex-start">Menunggu pembayaran</span>
                       <div class="note">Bayar invoice di HP: Bank > Invoices. Pesanan batal otomatis kalau tidak dibayar.</div>
                       <button class="ghost" id="sh-cancel">Batalkan pesanan</button>`
                    : `<span class="chip ok" style="align-self:flex-start">Lunas</span>
                       <div class="note">Tunggu mekanik di meja bengkel. Berdirilah dekat mekanik saat barang diserahkan.</div>`}
                </div>`;
            body.innerHTML = h;
            foot.classList.add('hidden');
            const c = $('sh-cancel');
            if (c) c.onclick = async () => {
                const res = await post('shCancel');
                msg = res && res.ok ? { ok: true, text: 'Pesanan dibatalkan.' } : { ok: false, text: (res && res.error) || 'Gagal' };
                await reloadMenu();
            };
            return;
        }

        if (menu.cooldown > 0) {
            h += `<div class="sh-status"><h2>Kamu baru saja membeli</h2>
                <div class="note">Bisa membeli lagi dalam ${Math.ceil(menu.cooldown / 60)} menit.</div></div>`;
            body.innerHTML = h;
            foot.classList.add('hidden');
            return;
        }

        if (menu.staff <= 0) h += '<div class="msg">Tidak ada mekanik yang bertugas, pesanan belum bisa dilayani.</div>';
        h += `<div class="note">Maksimal <b>${menu.limit} item</b> per pembelian. Setelah bayar, barang diserahkan mekanik di meja ini.</div>`;
        h += '<div class="sh-grid">' + menu.items.map(m => {
            const q = cart[m.item] || 0;
            return `<div class="sh-item">
                <div class="img">${itemImg(m.item, m.emoji || '🧰')}</div>
                <h3>${esc(m.label)}</h3><p>${esc(m.desc || '')}</p>
                <div class="price">Rp ${m.price}</div>
                <div class="qty"><button data-dec="${m.item}" ${q <= 0 ? 'disabled' : ''}>−</button><b>${q}</b>
                    <button data-inc="${m.item}" ${count() >= menu.limit ? 'disabled' : ''}>+</button></div></div>`;
        }).join('') + '</div>';
        body.innerHTML = h;

        foot.classList.remove('hidden');
        foot.innerHTML = `<div class="sum"><small>${count()} / ${menu.limit} item</small><strong>Rp ${total()}</strong></div>
            <div class="pay">
                <button data-pay="cash" class="${method === 'cash' ? 'on' : ''}">💵 Cash</button>
                ${menu.transfer ? `<button data-pay="transfer" class="${method === 'transfer' ? 'on' : ''}">📱 Transfer</button>` : ''}
            </div>
            <button class="primary" id="sh-order" ${count() === 0 || menu.staff <= 0 ? 'disabled' : ''}>Pesan & Bayar</button>`;

        body.querySelectorAll('[data-inc]').forEach(b => b.onclick = () => {
            if (count() >= menu.limit) return;
            cart[b.dataset.inc] = (cart[b.dataset.inc] || 0) + 1; msg = null; renderCustomer();
        });
        body.querySelectorAll('[data-dec]').forEach(b => b.onclick = () => {
            cart[b.dataset.dec] = Math.max(0, (cart[b.dataset.dec] || 0) - 1); msg = null; renderCustomer();
        });
        foot.querySelectorAll('[data-pay]').forEach(b => b.onclick = () => { method = b.dataset.pay; renderCustomer(); });
        $('sh-order').onclick = async () => {
            $('sh-order').disabled = true;
            const res = await post('shOrder', { cart, method });
            if (res && res.ok) {
                cart = {};
                msg = { ok: true, text: res.paid ? `Pesanan #${res.code} lunas. Tunggu mekanik.` : `Invoice #${res.code} dikirim ke HP, bayar dalam ${res.timeout} menit.` };
                await reloadMenu();
            } else {
                msg = { ok: false, text: (res && res.error) || 'Gagal memesan' };
                renderCustomer();
            }
        };
    }

    async function reloadMenu() {
        const res = await post('shMenu');
        if (res && !res.error) menu = res;
        renderCustomer();
    }

    function renderStaff() {
        $('sh-title').textContent = 'Toko Bengkel · Mekanik';
        $('sh-sub').textContent = `${staff.orders.length} pesanan menunggu diserahkan`;
        $('sh-foot').classList.add('hidden');
        let h = msgHtml();

        h += `<div class="sh-settings"><div class="name"><b>Batas per pembelian</b>
                <span>Total item maksimal yang bisa dibeli warga sekali pesan (1 - ${staff.maxLimit})</span></div>
            ${staff.canSettings
                ? `<input type="number" min="1" max="${staff.maxLimit}" value="${staff.limit}" id="sh-limit"><button class="primary" id="sh-save">Simpan</button>`
                : `<b>${staff.limit} item</b>`}</div>`;

        h += '<h3>Pesanan lunas</h3>';
        if (!staff.orders.length) h += '<div class="note">Belum ada pesanan. Pesanan yang sudah dibayar warga muncul di sini.</div>';
        staff.orders.forEach(o => {
            h += `<div class="sh-order">
                <div class="top"><span class="code">#${o.code}</span><span class="who">${esc(o.name)}</span>
                    <span class="chip info">${o.method === 'cash' ? 'Cash' : 'Transfer'} · ${clock(o.time)}</span>
                    <span class="chip ${o.near ? 'ok' : 'no'}">${!o.online ? 'Offline' : o.near ? 'Di dekatmu' : 'Jauh'}</span></div>
                <ul>${o.lines.map(l => `<li><span>${l.qty}× ${esc(l.label)}</span><span>Rp ${l.qty * l.price}</span></li>`).join('')}
                    <li><b>Total</b><b>Rp ${o.total}</b></li></ul>
                <div class="acts">
                    <button class="primary" data-serve="${o.code}" ${o.near ? '' : 'disabled'}>${o.near ? 'Serahkan Barang' : 'Pembeli harus dekat kamu'}</button>
                    <button class="ghost" data-reject="${o.code}">Tolak & Refund</button></div></div>`;
        });

        const body = $('sh-body');
        body.innerHTML = h;
        const save = $('sh-save');
        if (save) save.onclick = async () => applyStaff(await post('shSetLimit', { value: Number($('sh-limit').value) }));
        body.querySelectorAll('[data-serve]').forEach(b => b.onclick = async () => {
            b.disabled = true;
            applyStaff(await post('shServe', { code: b.dataset.serve }));
        });
        body.querySelectorAll('[data-reject]').forEach(b => b.onclick = async () => {
            if (b.dataset.sure !== '1') { b.dataset.sure = '1'; b.textContent = 'Yakin? Klik lagi'; return; }
            applyStaff(await post('shReject', { code: b.dataset.reject }));
        });
    }

    function applyStaff(res) {
        if (!res || res.error) msg = { ok: false, text: (res && res.error) || 'Gagal' };
        else { staff = res; msg = res.msg ? { ok: true, text: res.msg } : null; }
        renderStaff();
    }

    $('sh-close').onclick = () => post('shClose');
    document.addEventListener('keyup', e => {
        if (e.key === 'Escape' && !$('shop').classList.contains('hidden')) post('shClose');
    });

    window.addEventListener('message', e => {
        const d = e.data || {};
        if (d.action === 'shopOpen') {
            mode = d.mode; msg = null; cart = {};
            if (mode === 'staff') { staff = d.data; renderStaff(); } else { menu = d.data; method = 'cash'; renderCustomer(); }
            $('shop').classList.remove('hidden');
        } else if (d.action === 'shopUpdate') {
            if (mode === 'staff' && document.activeElement?.id !== 'sh-limit') { staff = d.data; renderStaff(); }
        } else if (d.action === 'shopClose') {
            $('shop').classList.add('hidden');
            mode = null;
        }
    });
})();
